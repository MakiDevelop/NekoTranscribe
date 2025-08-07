//
//  AudioProcessor.swift
//  NekoTranscribe
//
//  Created by 千葉牧人 on 2025/8/5.
//

import Foundation
import AVFoundation
import WhisperKit

// 將 AudioProcessor 標記為 @MainActor，確保其所有屬性和方法都在主線程上訪問，解決 Sendable 警告
@MainActor
class AudioProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingStatus = ""
    @Published var isModelLoaded = false
    
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
        // 切換回主線程更新 UI
        await MainActor.run {
            self.processingStatus = "正在載入 AI 模型..."
            self.isProcessing = true
        }
        
        do {
            // WhisperKit 現在不需要指定模型路徑，它會自動在 Bundle 中尋找 .mlmodelc 檔案
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
        // 使用正則表達式移除 <|...|> 格式的控制符號
        let regex = try! NSRegularExpression(pattern: "<\\|.*?\\|>", options: .caseInsensitive)
        let range = NSRange(location: 0, length: text.utf16.count)
        let cleanedText = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 自動斷句處理（支援標點符號和語義關鍵詞）
    func splitTranscriptByPunctuation(_ transcript: String) -> String {
        guard !transcript.isEmpty else { return transcript }
        
        let cleanedText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 檢查是否包含標點符號
        let hasPunctuation = cleanedText.rangeOfCharacter(from: CharacterSet(charactersIn: "。？！.?!")) != nil
        
        if hasPunctuation {
            return splitByPunctuation(cleanedText)
        } else {
            // 沒有標點符號時，使用語義關鍵詞斷句
            return splitBySemanticCues(cleanedText)
        }
    }
    
    /// 基於標點符號斷句
    private func splitByPunctuation(_ text: String) -> String {
        do {
            let pattern = "[。？！.?!]"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            var result = text
            var offset = 0
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                let insertPosition = match.range.location + match.range.length + offset
                if insertPosition < result.count {
                    let insertIndex = result.index(result.startIndex, offsetBy: insertPosition)
                    if insertIndex < result.endIndex && result[insertIndex] != "\n" {
                        result.insert("\n", at: insertIndex)
                        offset += 1
                    }
                }
            }
            
            return cleanLines(result)
        } catch {
            return text
        }
    }
    
    /// 基於語義關鍵詞斷句（處理無標點文本）
    private func splitBySemanticCues(_ text: String) -> String {
        let semanticCues = [
            "我跟你讲", "我跟你講", "但是", "然后", "然後", "所以", "因为", "因為",
            "简单来说", "簡單來說", "今天", "现在", "現在", "这样", "這樣"
        ]
        
        var result = text
        
        // 按長度排序，避免短詞干擾長詞匹配
        let sortedCues = semanticCues.sorted { $0.count > $1.count }
        
        for cue in sortedCues {
            result = result.replacingOccurrences(of: cue, with: "\n" + cue)
        }
        
        // 移除開頭的換行
        if result.hasPrefix("\n") {
            result = String(result.dropFirst())
        }
        
        return cleanLines(result)
    }
    
    /// 清理多餘的空白行
    private func cleanLines(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let cleanedLines = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return cleanedLines.joined(separator: "\n")
    }
    
    func convertToWhisperFormat(inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
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
    
    /// 使用 WhisperKit 進行轉錄，並提供進度回呼
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
                
                // 使用帶有 callback 的 transcribe 方法
                let transcriptionResult = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options) { progress in
                    // 進度回呼中，只傳遞當前的純文字用於即時打字效果
                    onProgress(progress.text)
                    return true // 返回 true 以繼續轉錄
                }
                
                print("WhisperKit 分析完成。")
                // 對最終結果也進行清理和拼接
                let cleanedText = transcriptionResult.map { self.cleanupText($0.text) }.joined(separator: "\n")
                // 應用自動斷句處理
                let finalText = self.splitTranscriptByPunctuation(cleanedText)
                print("最終組合後的逐字稿：'\(finalText)'")
                
                await MainActor.run {
                    self.isProcessing = false
                    self.processingStatus = "分析完成！"
                    onCompletion(.success(finalText))
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
