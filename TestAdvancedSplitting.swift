#!/usr/bin/env swift

//
//  TestAdvancedSplitting.swift
//  NekoTranscribe
//
//  Simple test for advanced sentence splitting without dependencies
//

import Foundation

// 簡化的斷句測試類別
class SimpleSentenceSplitter {
    
    func advancedSemanticSplit(_ text: String) -> String {
        var result = text
        
        // 第一層：強語義標記詞
        result = applySemanticMarkers(result, markers: getStrongSemanticMarkers())
        
        // 第二層：中等語義標記詞  
        result = applySemanticMarkers(result, markers: getMediumSemanticMarkers())
        
        // 第三層：基於句子長度的斷句
        result = applyLengthBasedSplit(result)
        
        return cleanLines(result)
    }
    
    private func getStrongSemanticMarkers() -> [String] {
        return [
            // 話題轉換
            "我跟你讲", "我跟你講", "跟你说", "跟你說", "告訴你", "告诉你",
            "重点是", "重點是", "关键是", "關鍵是",
            
            // 邏輯轉折
            "但是", "不过", "不過", "然而", "可是", "只是", "不料",
            
            // 因果關係
            "所以", "因此", "因为", "因為", "由于", "由於", "既然",
            
            // 時間轉換
            "接下来", "接下來", "然后", "然後", "后来", "後來", "最后", "最後", "现在", "現在", "今天", "刚才", "剛才"
        ]
    }
    
    private func getMediumSemanticMarkers() -> [String] {
        return [
            // 解釋說明
            "也就是说", "也就是說", "换句话说", "換句話說", "简单来说", "簡單來說",
            "比如说", "比如說", "举个例子", "舉個例子",
            
            // 情感表達
            "你知道吗", "你知道嗎", "你想想看", "真的是", "竟然", "居然",
            
            // 程度副詞
            "特别是", "特別是", "尤其是", "就是说", "就是說", "主要是",
            
            // 語氣詞組
            "这样", "這樣", "那样", "那樣", "这么", "這麼", "那么", "那麼"
        ]
    }
    
    private func applySemanticMarkers(_ text: String, markers: [String]) -> String {
        var result = text
        let sortedMarkers = markers.sorted { $0.count > $1.count }
        
        for marker in sortedMarkers {
            // 避免重複斷句
            if !result.contains("\n" + marker) {
                result = result.replacingOccurrences(of: marker, with: "\n" + marker)
            }
        }
        
        return result
    }
    
    private func applyLengthBasedSplit(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 100 {
                // 對於過長的句子，嘗試找到自然的分割點
                let splitPoints = findNaturalBreakPoints(trimmed)
                if !splitPoints.isEmpty {
                    result.append(contentsOf: splitPoints)
                } else {
                    result.append(trimmed)
                }
            } else {
                result.append(trimmed)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    private func findNaturalBreakPoints(_ sentence: String) -> [String] {
        // 尋找重複的詞或短語模式
        let commonPatterns = ["这个", "這個", "那个", "那個", "一个", "一個", "什么", "什麼", "怎么", "怎麼", "为什么", "為什麼"]
        
        var bestSplitPoint = -1
        var minLengthDiff = Int.max
        
        let targetLength = sentence.count / 2
        
        for pattern in commonPatterns {
            if let range = sentence.range(of: pattern) {
                let position = sentence.distance(from: sentence.startIndex, to: range.lowerBound)
                let lengthDiff = abs(position - targetLength)
                if lengthDiff < minLengthDiff && position > 20 && position < sentence.count - 20 {
                    minLengthDiff = lengthDiff
                    bestSplitPoint = position
                }
            }
        }
        
        if bestSplitPoint > 0 {
            let splitIndex = sentence.index(sentence.startIndex, offsetBy: bestSplitPoint)
            let firstPart = String(sentence[..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let secondPart = String(sentence[splitIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return [firstPart, secondPart].filter { !$0.isEmpty }
        }
        
        return []
    }
    
    private func cleanLines(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let cleanedLines = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return cleanedLines.joined(separator: "\n")
    }
}

// 測試功能
func runAdvancedSentenceSplittingTest() {
    let splitter = SimpleSentenceSplitter()
    
    print("=== 進階斷句功能測試 ===")
    
    // 測試案例1: 語義標記詞豐富的文本
    let textWithSemanticMarkers = "我跟你讲有人问一个亿的战斗力和一亿美元要选哪个但是你选一亿战斗力的时候但凡犹豫一秒那都是纯纯的二货然后是不是压根就没理解过强者的世界所以这两者的选项就不对的简单来说就像是有人在问同样是一公斤的东西可以送你你要黄金还是要棉花今天我让你彻底了解一下一个亿到底是什么概念"
    
    print("\n1. 語義標記詞測試:")
    print("輸入: \(textWithSemanticMarkers)")
    print("輸出:")
    print(splitter.advancedSemanticSplit(textWithSemanticMarkers))
    
    // 測試案例2: 極長句子（測試自動長度控制）
    let veryLongText = "现在我们来讨论一个非常复杂的问题就是关于人工智能的发展趋势和未来的应用场景其实这个话题已经被很多专家学者讨论过了但是我觉得还是有很多值得深入探讨的地方比如说机器学习算法的优化深度学习模型的改进以及自然语言处理技术的突破等等这些技术的发展不仅仅会影响我们的日常生活工作方式也会发生根本性的变化甚至可能会重塑整个社会的结构和运行模式"
    
    print("\n2. 超長句子自動分割測試:")
    print("輸入: \(veryLongText)")  
    print("輸出:")
    print(splitter.advancedSemanticSplit(veryLongText))
    
    // 測試案例3: 重複詞彙和模式
    let repetitiveText = "这个问题这个问题真的很复杂你知道吗你知道吗但是我们必须要解决这个问题那个方案那个方案可能不太适合我们需要找一个更好的方案一个更好的方案"
    
    print("\n3. 重複模式識別測試:")
    print("輸入: \(repetitiveText)")
    print("輸出:")
    print(splitter.advancedSemanticSplit(repetitiveText))
    
    print("\n=== 測試完成 ===")
    print("\n主要改進功能:")
    print("✓ 多層級語義標記識別（強、中兩級）")
    print("✓ 智能句子長度控制")
    print("✓ 自然分割點檢測（基於常用詞彙）")
    print("✓ 重複模式的優化處理")
}

// 執行測試
runAdvancedSentenceSplittingTest()