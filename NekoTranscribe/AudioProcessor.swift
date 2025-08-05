//
//  AudioProcessor.swift
//  NekoTranscribe
//
//  Created by 千葉牧人 on 2025/8/5.
//

import Foundation
import AVFoundation

class AudioProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingStatus = ""
    
    private let supportedExtensions = ["mp4", "mov", "mkv", "wav", "mp3", "m4a"]
    
    func isSupportedFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(fileExtension)
    }
    
    private func ffmpegPath() -> String? {
        // 取得 app bundle 內的 ffmpeg 路徑
        Bundle.main.path(forResource: "ffmpeg", ofType: nil)
    }
    
    func convertToWhisperFormat(inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingStatus = "開始處理音訊檔案..."
        }
        
        // 建立輸出檔案路徑（直接寫入 Documents 根目錄）
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputFileName = "whisper_audio_\(Date().timeIntervalSince1970).wav"
        let outputURL = documentsPath.appendingPathComponent(outputFileName)
        
        print("輸出檔案路徑：\(outputURL.path)")
        
        // 取得 ffmpeg 路徑
        guard let ffmpeg = ffmpegPath() else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingStatus = "找不到 ffmpeg 執行檔，請確認已放入 Resources 目錄"
                completion(.failure(AudioProcessorError.ffmpegNotFound))
            }
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        
        let arguments = [
            "-i", inputURL.path,
            "-ac", "1",           // 單聲道
            "-ar", "16000",       // 16kHz 取樣率
            "-f", "wav",          // WAV 格式
            outputURL.path
        ]
        
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    
                    if process.terminationStatus == 0 {
                        self.processingStatus = "音訊轉換完成！"
                        completion(.success(outputURL))
                    } else {
                        self.processingStatus = "轉換失敗"
                        completion(.failure(AudioProcessorError.conversionFailed))
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
    
    /// 刪除所有由本 App 輸出的 .wav 檔案
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
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "音訊轉換失敗"
        case .ffmpegNotFound:
            return "找不到 ffmpeg 執行檔"
        }
    }
} 