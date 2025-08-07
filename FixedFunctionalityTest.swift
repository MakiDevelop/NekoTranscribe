#!/usr/bin/env swift

//
//  FixedFunctionalityTest.swift
//  測試修復後的實時切換功能
//

import Foundation

// 模擬修復後的處理邏輯
class FixedProcessor {
    enum Mode {
        case segmentBased, semantic, mixed
    }
    
    var splittingMode: Mode = .segmentBased {
        didSet {
            print("🎛️ 模式改變: \(oldValue) → \(splittingMode)")
            if !cachedSegments.isEmpty {
                refreshFromCache()
            }
        }
    }
    
    var includeTimestamps = false {
        didSet {
            print("🕐 時間戳設置改變: \(oldValue) → \(includeTimestamps)")
            if !cachedSegments.isEmpty {
                refreshFromCache()
            }
        }
    }
    
    // 模擬 segment 結構
    struct MockSegment {
        let text: String
        let start: Double
        let end: Double
    }
    
    private var cachedSegments: [MockSegment] = []
    private var cachedPlainText: String = ""
    var currentTranscript: String = ""
    
    func simulateTranscription(_ segments: [MockSegment]) {
        // 暫存原始結果（修復：用換行符分隔而不是空格）
        cachedSegments = segments
        cachedPlainText = segments.map { $0.text }.joined(separator: "\n")  // ✅ 修復點1
        
        print("🗂️ 暫存轉錄結果:")
        print("   - Segments 數量: \(segments.count)")
        print("   - 純文字長度: \(cachedPlainText.count)")
        
        // 初始處理
        refreshFromCache()
    }
    
    private func refreshFromCache() {
        print("🔄 從暫存刷新轉錄結果...")
        print("   - 模式: \(splittingMode)")
        print("   - 時間戳: \(includeTimestamps)")
        
        let newTranscript: String
        switch splittingMode {
        case .segmentBased:
            print("   🎵 使用語音分段模式")
            newTranscript = processSegmentsWithTimestamp(cachedSegments)
        case .semantic:
            print("   🧠 使用語義斷句模式")
            newTranscript = processSemanticSplit(cachedPlainText)
        case .mixed:
            print("   🔄 使用混合模式")
            newTranscript = processMixedMode(cachedSegments)
        }
        
        currentTranscript = newTranscript
        print("   ✅ 更新完成，結果長度: \(newTranscript.count)")
        print("   📋 結果預覽:")
        let lines = newTranscript.components(separatedBy: "\n")
        for (i, line) in lines.prefix(3).enumerated() {
            print("      \(i+1). \(line)")
        }
        if lines.count > 3 {
            print("      ... (共 \(lines.count) 行)")
        }
    }
    
    private func processSegmentsWithTimestamp(_ segments: [MockSegment]) -> String {
        var result: [String] = []
        
        for segment in segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if includeTimestamps {
                let timestamp = "[\(formatTimestamp(segment.start)) - \(formatTimestamp(segment.end))]"
                result.append("\(timestamp) \(text)")
                print("   ✅ 添加時間戳: \(timestamp)")
            } else {
                result.append(text)
                print("   📄 純文字: \(String(text.prefix(30)))...")
            }
        }
        
        return result.joined(separator: "\n")  // ✅ 修復點2：確保分行
    }
    
    private func processSemanticSplit(_ text: String) -> String {
        let markers = ["我跟你讲", "但是", "所以", "然后", "简单来说", "今天"]
        var result = text
        
        for marker in markers.sorted(by: { $0.count > $1.count }) {
            result = result.replacingOccurrences(of: marker, with: "\n" + marker)
        }
        
        if result.hasPrefix("\n") {
            result = String(result.dropFirst())
        }
        
        return result
    }
    
    private func processMixedMode(_ segments: [MockSegment]) -> String {
        var result: [String] = []
        
        for segment in segments {
            let text = segment.text
            // 對長 segment 使用語義斷句
            let processedText = text.count > 60 ? processSemanticSplit(text) : text
            
            if includeTimestamps {
                let timestamp = "[\(formatTimestamp(segment.start)) - \(formatTimestamp(segment.end))]"
                result.append("\(timestamp) \(processedText)")
            } else {
                result.append(processedText)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    private func formatTimestamp(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    func forceRefresh() {
        print("🔄 強制刷新 (用戶點擊刷新按鈕)")
        refreshFromCache()
    }
}

// 執行測試
func testFixedFunctionality() {
    print("=== 修復後的實時切換功能測試 ===\n")
    
    let processor = FixedProcessor()
    
    // 模擬轉錄結果
    let segments = [
        FixedProcessor.MockSegment(text: "我跟你讲有人问一个亿的战斗力和一亿美元要选哪个", start: 0.0, end: 4.8),
        FixedProcessor.MockSegment(text: "但是你选一亿战斗力的时候但凡犹豫一秒", start: 4.8, end: 8.5),
        FixedProcessor.MockSegment(text: "所以这两者的选项就不对的", start: 8.5, end: 12.0),
        FixedProcessor.MockSegment(text: "今天我让你彻底了解一下", start: 12.0, end: 15.2)
    ]
    
    print("1️⃣ 模擬轉錄完成")
    processor.simulateTranscription(segments)
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("2️⃣ 開啟時間戳（這是問題點）")
    processor.includeTimestamps = true
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("3️⃣ 切換到語義斷句模式")
    processor.splittingMode = .semantic
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("4️⃣ 手動刷新測試")
    processor.forceRefresh()
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("5️⃣ 切回語音分段模式（含時間戳）")
    processor.splittingMode = .segmentBased
    
    print("\n=== 測試完成 ===")
    print("\n修復的問題:")
    print("✅ 暫存時用換行符而不是空格分隔")
    print("✅ 刷新按鈕調用正確的方法")
    print("✅ 時間戳模式下保持分行格式")
    print("✅ 增強調試輸出")
}

// 運行測試
testFixedFunctionality()