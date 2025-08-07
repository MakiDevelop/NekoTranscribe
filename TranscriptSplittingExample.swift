//
//  TranscriptSplittingExample.swift
//  NekoTranscribe
//
//  Advanced sentence splitting tests and examples
//

import Foundation

@MainActor
func testAdvancedSentenceSplitting() {
    let audioProcessor = AudioProcessor()
    
    print("=== 進階斷句功能測試 ===")
    
    // 測試案例1: 有標點符號（包含次要標點符號）
    let textWithPunctuation = "大家好我是馬奇，今天來介紹一款App叫NekoTranscribe，可以轉錄影片成文字；還能複製逐字稿，非常方便：操作簡單、功能強大。是不是很方便呢？我們來看看效果如何！"
    
    print("\n1. 複雜標點符號測試:")
    print("輸入: \(textWithPunctuation)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(textWithPunctuation))
    
    // 測試案例2: 沒有標點符號 - 語義標記詞豐富
    let textWithSemanticMarkers = "我跟你讲有人问一个亿的战斗力和一亿美元要选哪个但是你选一亿战斗力的时候但凡犹豫一秒那都是纯纯的二货然后是不是压根就没理解过强者的世界所以这两者的选项就不对的简单来说就像是有人在问同样是一公斤的东西可以送你你要黄金还是要棉花今天我让你彻底了解一下一个亿到底是什么概念"
    
    print("\n2. 語義標記詞測試:")
    print("輸入: \(textWithSemanticMarkers)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(textWithSemanticMarkers))
    
    // 測試案例3: 極長句子（測試自動長度控制）
    let veryLongText = "现在我们来讨论一个非常复杂的问题就是关于人工智能的发展趋势和未来的应用场景其实这个话题已经被很多专家学者讨论过了但是我觉得还是有很多值得深入探讨的地方比如说机器学习算法的优化深度学习模型的改进以及自然语言处理技术的突破等等这些技术的发展不仅仅会影响我们的日常生活工作方式也会发生根本性的变化甚至可能会重塑整个社会的结构和运行模式"
    
    print("\n3. 超長句子自動分割測試:")
    print("輸入: \(veryLongText)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(veryLongText))
    
    // 測試案例4: 混合中英文和數字
    let mixedLanguageText = "這個App用了最新的AI技術OpenAI的GPT模型還有Whisper語音識別引擎準確率高達95%以上特別是對繁體中文的支援非常好不過英文識別也很準確French和German等歐洲語言也支援"
    
    print("\n4. 多語言混合測試:")
    print("輸入: \(mixedLanguageText)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(mixedLanguageText))
    
    // 測試案例5: 重複詞彙和模式
    let repetitiveText = "这个问题这个问题真的很复杂你知道吗你知道吗但是我们必须要解决这个问题那个方案那个方案可能不太适合我们需要找一个更好的方案一个更好的方案"
    
    print("\n5. 重複模式識別測試:")
    print("輸入: \(repetitiveText)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(repetitiveText))
    
    // 測試案例6: 短句合併測試
    let shortSentences = "好的。明白了。沒問題。OK。這樣。就這樣。然後呢？真的嗎？當然。沒錯。是的。對。正確。"
    
    print("\n6. 短句智能合併測試:")
    print("輸入: \(shortSentences)")
    print("輸出:")
    print(audioProcessor.splitTranscriptByPunctuation(shortSentences))
    
    print("\n=== 進階測試完成 ===")
    print("\n主要改進功能:")
    print("• 多層級語義標記識別（強、中、弱三級）")
    print("• 智能句子長度控制（20-150字符）")
    print("• 次要標點符號的上下文感知處理")
    print("• 自然分割點檢測（基於常用詞彙）")
    print("• 短句智能合併，避免過度分割")
    print("• 語義相關性分析和分組")
    print("• 多語言和重複模式的優化處理")
}

// 保持向後兼容性
@MainActor
func testSentenceSplitting() {
    testAdvancedSentenceSplitting()
}

// 使用方法：在需要的地方調用 testAdvancedSentenceSplitting()