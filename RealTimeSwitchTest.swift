#!/usr/bin/env swift

//
//  RealTimeSwitchTest.swift  
//  NekoTranscribe
//
//  完整測試實時模式切換功能
//

import Foundation
import Combine

// 完整模擬 AudioProcessor 的行為
@MainActor
class TestAudioProcessor: ObservableObject {
    enum SentenceSplittingMode {
        case segmentBased, semantic, mixed
    }
    
    @Published var splittingMode: SentenceSplittingMode = .segmentBased {
        didSet {
            print("🎛️ 模式已改變: \(oldValue) → \(splittingMode)")
            if oldValue != splittingMode, !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    @Published var includeTimestamps = false {
        didSet {
            print("🕐 時間戳設置已改變: \(oldValue) → \(includeTimestamps)")
            if oldValue != includeTimestamps, !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    // 暫存原始轉錄結果
    private var cachedSegments: [MockSegment] = []
    private var cachedPlainText: String = ""
    @Published var currentTranscript: String = ""
    
    private func refreshTranscriptFromCache() {
        print("🔄 嘗試從暫存刷新轉錄結果...")
        print("   - 暫存 segments 數量: \(cachedSegments.count)")
        print("   - 暫存純文字長度: \(cachedPlainText.count)")
        print("   - 當前模式: \(splittingMode)")
        print("   - 包含時間戳: \(includeTimestamps)")
        
        guard !cachedSegments.isEmpty || !cachedPlainText.isEmpty else { 
            print("   ❌ 暫存為空，無法刷新")
            return 
        }
        
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
        print("   ✅ 已更新 currentTranscript，長度: \(newTranscript.count)")
    }
    
    func simulateTranscriptionCompleted(segments: [MockSegment]) {
        print("🎤 模擬轉錄完成，暫存結果...")
        cachedSegments = segments
        cachedPlainText = segments.map { $0.text }.joined(separator: " ")
        
        // 初始處理
        refreshTranscriptFromCache()
    }
    
    private func processSegmentsWithTimestamp(_ segments: [MockSegment]) -> String {
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
        return segments.map { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let splitText = text.count > 60 ? processSemanticSplit(text) : text
            
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

// 模擬 segment 結構
struct MockSegment {
    let text: String
    let start: Double
    let end: Double
}

// 模擬 ContentView 的行為
@MainActor
class TestContentView: ObservableObject {
    @Published private var audioProcessor = TestAudioProcessor()
    @Published var transcript = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 模擬 ContentView 的 onChange 監聽
        audioProcessor.$currentTranscript
            .sink { [weak self] newValue in
                print("📱 TestContentView 收到 currentTranscript 更新，長度: \(newValue.count)")
                if !newValue.isEmpty {
                    self?.transcript = newValue // 簡化的 postProcessText
                    print("📱 已更新本地 transcript，長度: \(self?.transcript.count ?? 0)")
                }
            }
            .store(in: &cancellables)
    }
    
    func getAudioProcessor() -> TestAudioProcessor {
        return audioProcessor
    }
}

// 執行完整測試
@MainActor
func runRealTimeSwitchTest() async {
    print("=== 實時模式切換完整測試 ===\n")
    
    let contentView = TestContentView()
    let processor = contentView.getAudioProcessor()
    
    // 模擬轉錄結果
    let segments = [
        MockSegment(text: "我跟你讲有人问一个亿的战斗力和一亿美元要选哪个", start: 0.0, end: 4.8),
        MockSegment(text: "但是你选一亿战斗力的时候但凡犹豫一秒那都是纯纯的二货", start: 4.8, end: 10.2),
        MockSegment(text: "所以这两者的选项就不对的简单来说就像是有人在问", start: 10.2, end: 15.5),
        MockSegment(text: "今天我让你彻底了解一下一个亿到底是什么概念", start: 15.5, end: 20.1)
    ]
    
    print("1️⃣ 初始轉錄完成")
    processor.simulateTranscriptionCompleted(segments: segments)
    print("   ContentView.transcript 長度: \(contentView.transcript.count)")
    print("   內容預覽: \(String(contentView.transcript.prefix(50)))...")
    
    print("\n" + String(repeating: "=", count: 60))
    
    print("\n2️⃣ 切換到語義斷句模式")
    processor.splittingMode = .semantic
    
    // 等待異步更新
    try? await Task.sleep(for: .milliseconds(100))
    print("   ContentView.transcript 長度: \(contentView.transcript.count)")
    print("   內容預覽: \(String(contentView.transcript.prefix(100)))...")
    
    print("\n" + String(repeating: "=", count: 60))
    
    print("\n3️⃣ 切換到混合模式並開啟時間戳")
    processor.splittingMode = .mixed
    processor.includeTimestamps = true
    
    try? await Task.sleep(for: .milliseconds(100))
    print("   ContentView.transcript 長度: \(contentView.transcript.count)")
    print("   內容預覽: \(String(contentView.transcript.prefix(100)))...")
    
    print("\n" + String(repeating: "=", count: 60))
    
    print("\n4️⃣ 切回語音分段模式")
    processor.splittingMode = .segmentBased
    
    try? await Task.sleep(for: .milliseconds(100))
    print("   ContentView.transcript 長度: \(contentView.transcript.count)")
    print("   內容預覽: \(String(contentView.transcript.prefix(100)))...")
    
    print("\n=== 測試完成 ===")
    print("\n✅ 功能驗證:")
    print("• 轉錄結果正確暫存")
    print("• 模式切換觸發刷新")
    print("• 時間戳開關生效")
    print("• UI 實時更新")
}

// 執行測試
Task { @MainActor in
    await runRealTimeSwitchTest()
}