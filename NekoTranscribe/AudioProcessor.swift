//
//  AudioProcessor.swift
//  NekoTranscribe
//
//  Created by 千葉牧人 on 2025/8/5.
//

import Foundation
import AVFoundation
import WhisperKit

// 將 AudioProcessor 標記為 @MainActor，確保其所有屬性和方法都在主線程上訪問
@MainActor
class AudioProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingStatus = ""
    @Published var isModelLoaded = false
    
    // 時間戳顯示開關
    @Published var includeTimestamps = false {
        didSet {
            // 當開關切換時，如果已有暫存結果，則刷新逐字稿
            if oldValue != includeTimestamps, !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    // 暫存原始的 segments 結果
    private var cachedSegments: [TranscriptionSegment] = []
    @Published var currentTranscript: String = ""
    
    private var whisperKit: WhisperKit?
    private let supportedExtensions = ["mp4", "mov", "mkv", "wav", "mp3", "m4a", "hevc", "h265"]
    
    init() {
        // 在背景線程中初始化 WhisperKit，避免卡住 UI
        Task(priority: .background) {
            await initializeWhisper()
        }
    }
    
    /// 初始化 WhisperKit 模型
    private func initializeWhisper() async {
        await MainActor.run {
            self.processingStatus = "正在載入 AI 模型..."
            self.isProcessing = true
        }
        
        do {
            whisperKit = try await WhisperKit(verbose: true, logLevel: .debug)
            
            await MainActor.run {
                self.isModelLoaded = true
                self.isProcessing = false
                self.processingStatus = "AI 模型已載入，準備就緒！"
                print("WhisperKit initialized successfully.")
            }
            
        } catch {
            print("Error initializing WhisperKit: \(error.localizedDescription)")
            await MainActor.run {
                self.isProcessing = false
                self.processingStatus = "AI 模型載入失敗：\(error.localizedDescription)"
            }
        }
    }
    
    func isSupportedFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(fileExtension)
    }
    
    private func ffmpegPath() -> String? {
        Bundle.main.path(forResource: "ffmpeg", ofType: nil)
    }
    
    /// 清理 Whisper 輸出的文字，移除控制符號和多餘空白
    private func cleanupText(_ text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "<\\|.*?\\|>", options: .caseInsensitive)
        let range = NSRange(location: 0, length: text.utf16.count)
        let cleanedText = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 從暫存的結果刷新轉錄文字（用於實時切換時間戳顯示）
    private func refreshTranscriptFromCache() {
        guard !cachedSegments.isEmpty else { return }
        
        // 直接使用基於 segment 的處理方法
        let newTranscript = processSegments(cachedSegments)
        
        Task { @MainActor in
            self.currentTranscript = newTranscript
        }
    }
    
    /// 清除暫存的轉錄結果
    private func clearCache() {
        cachedSegments.removeAll()
        currentTranscript = ""
    }
    
    /// 強制從暫存刷新（供 UI 調用）
    func forceRefreshFromCache() {
        refreshTranscriptFromCache()
    }
    
    /// 使用 WhisperKit segments 進行基於語音停頓的斷句
    private func processSegments(_ segments: [TranscriptionSegment]) -> String {
        let processedLines = segments.map { segment -> String in
            let cleanedText = cleanupText(segment.text)
            
            // 如果用戶選擇包含時間戳，添加時間戳信息
            if includeTimestamps {
                let startTime = formatTimestamp(Double(segment.start))
                let endTime = formatTimestamp(Double(segment.end))
                return "[\(startTime) - \(endTime)] \(cleanedText)"
            } else {
                return cleanedText
            }
        }
        
        // 過濾掉清理後可能產生的空行
        let nonEmptyLines = processedLines.filter { !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }
        
        return nonEmptyLines.joined(separator: "\n")
    }
    
    /// 格式化時間戳為易讀格式 (mm:ss 或 h:mm:ss)
    private func formatTimestamp(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    func convertToWhisperFormat(inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        clearCache()
        
        self.isProcessing = true
        self.processingStatus = "正在準備音訊檔案..."
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputFileName = "whisper_audio_\(Date().timeIntervalSince1970).wav"
        let outputURL = documentsPath.appendingPathComponent(outputFileName)
        
        guard let ffmpeg = ffmpegPath() else {
            let error = AudioProcessorError.ffmpegNotFound
            self.isProcessing = false
            self.processingStatus = error.localizedDescription
            completion(.failure(error))
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-i", inputURL.path,
            "-ac", "1",
            "-ar", "16000",
            "-f", "wav",
            "-y", // 覆蓋已存在檔案
            outputURL.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print("FFmpeg output:\n\(output)")
                }
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        self.processingStatus = "音訊轉換完成！"
                        completion(.success(outputURL))
                    } else {
                        let error = AudioProcessorError.conversionFailed
                        self.processingStatus = error.localizedDescription
                        self.isProcessing = false
                        completion(.failure(error))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processingStatus = "處理錯誤: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 使用 WhisperKit 進行轉錄
    func transcribeAudio(url: URL, language: String, onProgress: @escaping (String) -> Void, onCompletion: @escaping (Result<String, Error>) -> Void) {
        guard let whisperKit = whisperKit else {
            let error = AudioProcessorError.whisperNotInitialized
            self.processingStatus = error.localizedDescription
            onCompletion(.failure(error))
            return
        }
        
        guard isModelLoaded else {
            let error = AudioProcessorError.modelNotLoaded
            self.processingStatus = error.localizedDescription
            onCompletion(.failure(error))
            return
        }
        
        self.isProcessing = true
        self.processingStatus = "正在分析音訊，請稍候..."
        print("準備開始分析音訊檔案：\(url.path)")
        print("選擇的語言: \(language)")
        
        Task {
            do {
                let options = DecodingOptions(language: language)
                
                // 使用帶有 callback 的 transcribe 方法來顯示進度
                let transcriptionResult = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options) { progress in
                    // 進度回呼中，只傳遞當前的純文字用於即時打字效果
                    onProgress(progress.text)
                    return true // 返回 true 以繼續轉錄
                }
                
                print("WhisperKit 分析完成。")
                
                // 暫存原始轉錄結果
                self.cachedSegments = transcriptionResult.flatMap { $0.segments }
                
                // 直接使用基於 segment 的方法處理斷句
                let finalText = self.processSegments(self.cachedSegments)
                
                self.currentTranscript = finalText
                print("最終組合後的逐字稿：'\(finalText)'")
                
                await MainActor.run {
                    self.isProcessing = false
                    self.processingStatus = "分析完成！"
                    onCompletion(.success(self.currentTranscript))
                }
            } catch {
                print("WhisperKit 分析時發生錯誤: \(error)")
                await MainActor.run {
                    self.isProcessing = false
                    self.processingStatus = "分析失敗：\(error.localizedDescription)"
                    onCompletion(.failure(error))
                }
            }
        }
    }
    
    func deleteAllExportedAudio(completion: @escaping (Result<Int, Error>) -> Void) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let exported = files.filter { $0.lastPathComponent.hasPrefix("whisper_audio_") && $0.pathExtension.lowercased() == "wav" }
            for url in exported {
                try FileManager.default.removeItem(at: url)
            }
            completion(.success(exported.count))
        } catch {
            completion(.failure(error))
        }
    }
}

enum AudioProcessorError: Error, LocalizedError {
    case conversionFailed
    case ffmpegNotFound
    case whisperNotInitialized
    case modelNotLoaded
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "音訊轉換失敗"
        case .ffmpegNotFound:
            return "找不到 ffmpeg 執行檔"
        case .whisperNotInitialized:
            return "Whisper AI尚未初始化"
        case .modelNotLoaded:
            return "AI 模型尚未載入完成"
        }
    }
}
