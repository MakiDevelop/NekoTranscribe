//
//  TranscriptSplittingExample.swift
//  NekoTranscribe
//
//  Basic sentence splitting example
//

import Foundation

@MainActor
func testSentenceSplitting() {
    let audioProcessor = AudioProcessor()
    
    print("=== 斷句功能測試 ===")
    
    // 測試案例1: 有標點符號
    let textWithPunctuation = "大家好我是馬奇今天來介紹一款App叫NekoTranscribe可以轉錄影片成文字還能複製逐字稿。是不是很方便呢？我們來看看效果如何！"
    
    print("\n1. 有標點符號的測試:")
    print("輸入: \(textWithPunctuation)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(textWithPunctuation))
    
    // 測試案例2: 沒有標點符號（你之前測試的案例）
    let textWithoutPunctuation = "有人问一个亿的战斗力和一亿美元要选哪个我跟你讲你选一亿战斗力的时候但凡犹豫一秒那都是纯纯的二货是不是压根就没理解过强者的世界这两者的选项就不对的就像是有人在问同样是一公斤的东西可以送你你要黄金还是要棉花今天我让你彻底了解一下一个亿到底是什么概念"
    
    print("\n2. 無標點符號的測試:")
    print("輸入: \(textWithoutPunctuation)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(textWithoutPunctuation))
    
    print("\n=== 測試完成 ===")
}

// 使用方法：在需要的地方調用 testSentenceSplitting()