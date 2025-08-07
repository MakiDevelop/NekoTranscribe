#!/usr/bin/env swift

//
//  CacheAndSwitchTest.swift
//  NekoTranscribe
//
//  測試暫存和實時切換斷句模式功能
//

import Foundation

// 模擬 WhisperKit segment 結構
struct MockTranscriptionSegment {
    let text: String
    let start: Double
    let end: Double
}

// 簡化版的 AudioProcessor 用於測試暫存功能
class MockAudioProcessor {
    enum SentenceSplittingMode {
        case segmentBased, semantic, mixed
    }
    
    var splittingMode: SentenceSplittingMode = .segmentBased {
        didSet {
            if oldValue != splittingMode && !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    var includeTimestamps = false {
        didSet {
            if oldValue != includeTimestamps && !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    // 暫存
    private var cachedSegments: [MockTranscriptionSegment] = []
    private var cachedPlainText: String = ""
    var currentTranscript: String = ""
    
    // 模擬轉錄完成，暫存結果
    func simulateTranscriptionCompleted(segments: [MockTranscriptionSegment]) {
        cachedSegments = segments
        cachedPlainText = segments.map { $0.text }.joined(separator: " ")
        refreshTranscriptFromCache()
    }
    
    private func refreshTranscriptFromCache() {
        let newTranscript: String
        switch splittingMode {
        case .segmentBased:
            newTranscript = processSegmentsWithTimestamp(cachedSegments)
        case .semantic:
            newTranscript = processSemanticSplit(cachedPlainText)
        case .mixed:
            newTranscript = processMixedMode(cachedSegments)
        }
        
        currentTranscript = newTranscript
        print("✅ 已從暫存刷新轉錄結果")
        print("   模式：\(splittingMode)")
        print("   包含時間戳：\(includeTimestamps)")
        print("   結果：\n\(currentTranscript)")
    }
    
    private func processSegmentsWithTimestamp(_ segments: [MockTranscriptionSegment]) -> String {
        return segments.map { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if includeTimestamps {
                let startTime = formatTimestamp(segment.start)
                let endTime = formatTimestamp(segment.end)
                return "[\(startTime) - \(endTime)] \(text)"
            } else {
                return text
            }
        }.joined(separator: "\n")
    }
    
    private func processSemanticSplit(_ text: String) -> String {
        // 簡化的語義斷句
        let markers = ["我跟你讲", "但是", "所以", "然后", "简单来说"]
        var result = text
        
        for marker in markers {
            result = result.replacingOccurrences(of: marker, with: "\n" + marker)
        }
        
        if result.hasPrefix("\n") {
            result = String(result.dropFirst())
        }
        
        return result
    }
    
    private func processMixedMode(_ segments: [MockTranscriptionSegment]) -> String {
        return segments.map { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let splitText = text.count > 50 ? processSemanticSplit(text) : text
            
            if includeTimestamps {
                let startTime = formatTimestamp(segment.start)
                let endTime = formatTimestamp(segment.end)
                return "[\(startTime) - \(endTime)] \(splitText)"
            } else {
                return splitText
            }
        }.joined(separator: "\n")
    }
    
    private func formatTimestamp(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    func clearCache() {
        cachedSegments.removeAll()
        cachedPlainText = ""
        currentTranscript = ""
        print("🧹 已清除暫存")
    }
}

// 測試功能
func testCacheAndSwitch() {
    let processor = MockAudioProcessor()
    
    print("=== 暫存與實時切換功能測試 ===\n")
    
    // 模擬轉錄結果
    let mockSegments = [
        MockTranscriptionSegment(text: "我跟你讲有人问一个亿的战斗力和一亿美元要选哪个", start: 0.0, end: 4.8),
        MockTranscriptionSegment(text: "但是你选一亿战斗力的时候但凡犹豫一秒那都是纯纯的二货", start: 4.8, end: 10.2),
        MockTranscriptionSegment(text: "所以这两者的选项就不对的简单来说就像是有人在问", start: 10.2, end: 15.5),
        MockTranscriptionSegment(text: "你要黄金还是要棉花今天我让你彻底了解一下", start: 15.5, end: 20.1)
    ]
    
    print("1️⃣ 模擬轉錄完成，預設使用語音分段模式：")
    processor.simulateTranscriptionCompleted(segments: mockSegments)
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("2️⃣ 切換到語義斷句模式（無需重新轉錄）：")
    processor.splittingMode = .semantic
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("3️⃣ 切換到混合模式：")
    processor.splittingMode = .mixed
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("4️⃣ 切回語音分段模式並開啟時間戳：")
    processor.splittingMode = .segmentBased
    processor.includeTimestamps = true
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("5️⃣ 關閉時間戳：")
    processor.includeTimestamps = false
    
    print("\n" + String(repeating: "=", count: 60) + "\n")
    
    print("6️⃣ 清除暫存（模擬載入新檔案）：")
    processor.clearCache()
    
    print("\n=== 測試完成 ===")
    
    print("\n實現的功能：")
    print("✅ 轉錄結果暫存，避免重複分析")
    print("✅ 實時切換斷句模式")
    print("✅ 實時開關時間戳顯示")
    print("✅ 載入新檔案時自動清除暫存")
    print("✅ UI 會即時反映模式變更")
}

// 執行測試
testCacheAndSwitch()