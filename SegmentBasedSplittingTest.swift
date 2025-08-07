#!/usr/bin/env swift

//
//  SegmentBasedSplittingTest.swift
//  NekoTranscribe
//
//  測試基於 WhisperKit segment 的斷句功能
//

import Foundation

// 模擬 WhisperKit segment 結構
struct MockSegment {
    let text: String
    let start: Double
    let end: Double
}

// 簡化版的 segment 處理器用於測試
class SegmentBasedProcessor {
    var includeTimestamps = false
    
    func processSegments(_ segments: [MockSegment]) -> String {
        var processedSegments: [String] = []
        
        for segment in segments {
            let trimmedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedText.isEmpty || trimmedText.count < 2 {
                continue
            }
            
            var finalSegmentText = trimmedText
            
            if includeTimestamps {
                let timestampPrefix = "[\(formatTimestamp(segment.start)) - \(formatTimestamp(segment.end))]"
                finalSegmentText = "\(timestampPrefix) \(trimmedText)"
            }
            
            processedSegments.append(finalSegmentText)
        }
        
        return processedSegments.joined(separator: "\n")
    }
    
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
}

// 測試基於 segment 的斷句
func testSegmentBasedSplitting() {
    let processor = SegmentBasedProcessor()
    
    print("=== 基於 Segment 的斷句功能測試 ===\n")
    
    // 模擬 WhisperKit 返回的 segments
    let mockSegments = [
        MockSegment(text: "大家好我是馬奇", start: 0.0, end: 2.5),
        MockSegment(text: "今天來介紹一款 App 叫 NekoTranscribe", start: 2.5, end: 6.2),
        MockSegment(text: "可以轉錄影片成文字", start: 6.2, end: 9.1),
        MockSegment(text: "還能複製逐字稿", start: 9.1, end: 11.8),
        MockSegment(text: "是不是很方便呢", start: 11.8, end: 14.0),
        MockSegment(text: "我們來看看效果如何", start: 14.0, end: 16.5)
    ]
    
    // 測試 1: 不包含時間戳
    print("1. 基於語音分段（不含時間戳）:")
    processor.includeTimestamps = false
    print(processor.processSegments(mockSegments))
    
    print("\n" + String(repeating: "=", count: 50) + "\n")
    
    // 測試 2: 包含時間戳
    print("2. 基於語音分段（含時間戳）:")
    processor.includeTimestamps = true
    print(processor.processSegments(mockSegments))
    
    print("\n" + String(repeating: "=", count: 50) + "\n")
    
    // 測試 3: 模擬較長的內容
    let longSegments = [
        MockSegment(text: "我跟你講有人問一個億的戰鬥力和一億美元要選哪個", start: 0.0, end: 4.8),
        MockSegment(text: "但是你選一億戰鬥力的時候但凡猶豫一秒", start: 4.8, end: 8.5),
        MockSegment(text: "那都是純純的二貨", start: 8.5, end: 10.2),
        MockSegment(text: "是不是壓根就沒理解過強者的世界", start: 10.2, end: 13.7),
        MockSegment(text: "所以這兩者的選項就不對的", start: 13.7, end: 16.8),
        MockSegment(text: "簡單來說就像是有人在問", start: 16.8, end: 19.2),
        MockSegment(text: "同樣是一公斤的東西可以送你", start: 19.2, end: 22.1),
        MockSegment(text: "你要黃金還是要棉花", start: 22.1, end: 24.8),
        MockSegment(text: "今天我讓你徹底了解一下一個億到底是什麼概念", start: 24.8, end: 29.5)
    ]
    
    print("3. 較長內容的語音分段:")
    processor.includeTimestamps = false
    print(processor.processSegments(longSegments))
    
    print("\n" + String(repeating: "=", count: 50) + "\n")
    
    print("4. 較長內容（含時間戳）:")
    processor.includeTimestamps = true  
    print(processor.processSegments(longSegments))
    
    print("\n=== 測試完成 ===")
    
    print("\n優勢分析：")
    print("✓ 基於真實語音停頓，斷句更自然")
    print("✓ 保留原始語義完整性")
    print("✓ 可選擇性包含精確時間戳")
    print("✓ 減少語義斷句可能帶來的錯誤")
    print("✓ 更適合語音轉文字的使用場景")
}

// 執行測試
testSegmentBasedSplitting()