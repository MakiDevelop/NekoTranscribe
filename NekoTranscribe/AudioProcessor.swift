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
    
    // 斷句模式選項
    enum SentenceSplittingMode {
        case segmentBased    // 基於 WhisperKit segments（推薦）
        case semantic       // 基於語義標記詞
        case mixed         // 混合模式：segment + 語義優化
    }
    
    @Published var splittingMode: SentenceSplittingMode = .segmentBased {
        didSet {
            // 保留功能但暫時移除調試輸出
            if oldValue != splittingMode, !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    @Published var includeTimestamps = false {
        didSet {
            // 保留功能但暫時移除調試輸出
            if oldValue != includeTimestamps, !cachedSegments.isEmpty {
                refreshTranscriptFromCache()
            }
        }
    }
    
    // 暫存原始轉錄結果
    private var cachedSegments: [Any] = []
    private var cachedPlainText: String = ""
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
    
    /// 從暫存的結果刷新轉錄文字（用於實時切換模式）
    private func refreshTranscriptFromCache() {
        guard !cachedSegments.isEmpty || !cachedPlainText.isEmpty else { 
            return 
        }
        
        let newTranscript: String
        switch splittingMode {
        case .segmentBased:
            newTranscript = processSegmentsWithTimestamp(cachedSegments)
        case .semantic:
            newTranscript = splitTranscriptByPunctuation(cachedPlainText)
        case .mixed:
            newTranscript = processMixedMode(cachedSegments)
        }
        
        // 確保在主線程更新 UI
        Task { @MainActor in
            self.currentTranscript = newTranscript
        }
    }
    
    /// 清除暫存的轉錄結果
    private func clearCache() {
        cachedSegments.removeAll()
        cachedPlainText = ""
        currentTranscript = ""
    }
    
    /// 強制從暫存刷新（供 UI 調用）
    func forceRefreshFromCache() {
        refreshTranscriptFromCache()
    }
    
    /// 進階自動斷句處理（多層級斷句策略）
    func splitTranscriptByPunctuation(_ transcript: String) -> String {
        guard !transcript.isEmpty else { return transcript }
        
        let cleanedText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 檢查是否包含標點符號
        let hasPunctuation = cleanedText.rangeOfCharacter(from: CharacterSet(charactersIn: "。？！.?!")) != nil
        
        if hasPunctuation {
            return advancedPunctuationSplit(cleanedText)
        } else {
            // 沒有標點符號時，使用多層級語義斷句
            return advancedSemanticSplit(cleanedText)
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
    
    /// 進階標點符號斷句（加入語境感知）
    private func advancedPunctuationSplit(_ text: String) -> String {
        do {
            // 主要斷句符號
            let mainPattern = "[。？！]"
            // 次要斷句符號（需要考慮上下文）
            let secondaryPattern = "[.?!,，、；;：:]"
            
            let mainRegex = try NSRegularExpression(pattern: mainPattern, options: [])
            let secondaryRegex = try NSRegularExpression(pattern: secondaryPattern, options: [])
            
            var result = text
            var offset = 0
            
            // 先處理主要斷句符號
            let mainMatches = mainRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in mainMatches {
                let insertPosition = match.range.location + match.range.length + offset
                if insertPosition < result.count {
                    let insertIndex = result.index(result.startIndex, offsetBy: insertPosition)
                    if insertIndex < result.endIndex && result[insertIndex] != "\n" {
                        result.insert("\n", at: insertIndex)
                        offset += 1
                    }
                }
            }
            
            // 處理次要斷句符號（但需要檢查上下文）
            result = processSecondaryPunctuation(result)
            
            return optimizeSentenceLength(cleanLines(result))
        } catch {
            return text
        }
    }
    
    /// 處理次要標點符號的斷句邏輯
    private func processSecondaryPunctuation(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        
        for line in lines {
            if line.count > 120 { // 如果行過長，嘗試用次要標點切分
                let subSentences = splitLongSentence(line)
                result.append(contentsOf: subSentences)
            } else {
                result.append(line)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    /// 切分過長的句子
    private func splitLongSentence(_ sentence: String) -> [String] {
        let secondaryMarkers = [",", "，", "、", ";", "；", ":", "："]
        var parts: [String] = [sentence]
        
        for marker in secondaryMarkers {
            var newParts: [String] = []
            for part in parts {
                if part.count > 80 {
                    let splitParts = part.components(separatedBy: marker)
                    if splitParts.count > 1 {
                        for (index, splitPart) in splitParts.enumerated() {
                            let trimmed = splitPart.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                if index < splitParts.count - 1 && !trimmed.hasSuffix(marker) {
                                    newParts.append(trimmed + marker)
                                } else {
                                    newParts.append(trimmed)
                                }
                            }
                        }
                    } else {
                        newParts.append(part)
                    }
                } else {
                    newParts.append(part)
                }
            }
            parts = newParts
        }
        
        return parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    /// 多層級語義斷句（無標點符號時使用）
    private func advancedSemanticSplit(_ text: String) -> String {
        var result = text
        
        // 第一層：強語義標記詞
        result = applySemanticMarkers(result, markers: getStrongSemanticMarkers(), strength: .strong)
        
        // 第二層：中等語義標記詞
        result = applySemanticMarkers(result, markers: getMediumSemanticMarkers(), strength: .medium)
        
        // 第三層：基於句子長度和語音節奏的斷句
        result = applyRhythmBasedSplit(result)
        
        // 第四層：語義相關性分析
        result = applySemanticGrouping(result)
        
        return optimizeSentenceLength(cleanLines(result))
    }
    
    /// 語義標記強度
    private enum SemanticStrength {
        case strong, medium, weak
    }
    
    /// 獲取強語義標記詞
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
    
    /// 獲取中等語義標記詞
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
    
    /// 應用語義標記
    private func applySemanticMarkers(_ text: String, markers: [String], strength: SemanticStrength) -> String {
        var result = text
        let sortedMarkers = markers.sorted { $0.count > $1.count }
        
        for marker in sortedMarkers {
            // 避免重複斷句
            let pattern = "(?<!\\n)" + NSRegularExpression.escapedPattern(for: marker)
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "\n" + marker)
            } catch {
                // 如果正則表達式失敗，使用簡單替換
                result = result.replacingOccurrences(of: marker, with: "\n" + marker)
            }
        }
        
        return result
    }
    
    /// 基於語音節奏的斷句
    private func applyRhythmBasedSplit(_ text: String) -> String {
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
    
    /// 找到自然的分割點
    private func findNaturalBreakPoints(_ sentence: String) -> [String] {
        // 尋找重複的詞或短語模式
        let commonPatterns = ["这个", "這個", "那个", "那個", "一个", "一個", "什么", "什麼", "怎么", "怎麼", "为什么", "為什麼"]
        
        var bestSplitPoint = -1
        var minLengthDiff = Int.max
        
        let targetLength = sentence.count / 2
        
        for pattern in commonPatterns {
            let ranges = findAllRanges(of: pattern, in: sentence)
            for range in ranges {
                let position = range.lowerBound.utf16Offset(in: sentence)
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
    
    /// 找到字符串中所有匹配的範圍
    private func findAllRanges(of substring: String, in string: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = string.startIndex
        
        while searchStartIndex < string.endIndex {
            if let range = string.range(of: substring, range: searchStartIndex..<string.endIndex) {
                ranges.append(range)
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }
        
        return ranges
    }
    
    /// 語義分組（將相關的句子組合在一起）
    private func applySemanticGrouping(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var result: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 30 && !result.isEmpty {
                // 短句嘗試與前一句合併
                let lastIndex = result.count - 1
                let combined = result[lastIndex] + " " + trimmed
                if combined.count <= 120 {
                    result[lastIndex] = combined
                } else {
                    result.append(trimmed)
                }
            } else {
                result.append(trimmed)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    /// 優化句子長度
    private func optimizeSentenceLength(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.count > 150 {
                // 過長的句子需要進一步切分
                let splitSentences = splitLongSentence(trimmed)
                result.append(contentsOf: splitSentences)
            } else {
                result.append(trimmed)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    /// 基於語義關鍵詞斷句（處理無標點文本）- 保留向後兼容性
    private func splitBySemanticCues(_ text: String) -> String {
        return advancedSemanticSplit(text)
    }
    
    /// 使用 WhisperKit segments 進行基於語音停頓的斷句
    private func processSegmentsWithTimestamp(_ segments: [Any]) -> String {
        var processedSegments: [String] = []
        
        for segment in segments {
            let segmentText = cleanupText(getText(from: segment))
            let trimmedText = segmentText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedText.isEmpty || trimmedText.count < 2 {
                continue
            }
            
            // 構建最終的 segment 文字
            var finalSegmentText = trimmedText
            
            // 如果用戶選擇包含時間戳，添加時間戳信息
            if includeTimestamps {
                if let startTime = getValue(from: segment, key: "start") as? Double,
                   let endTime = getValue(from: segment, key: "end") as? Double {
                    let timestampPrefix = "[\(formatTimestamp(startTime)) - \(formatTimestamp(endTime))]"
                    finalSegmentText = "\(timestampPrefix) \(trimmedText)"
                } else {
                    // 如果無法獲取時間戳，使用預設格式
                    finalSegmentText = "[--:--] \(trimmedText)"
                }
            }
            
            processedSegments.append(finalSegmentText)
        }
        
        // 智能合併過短的 segments（但不合併有時間戳的）
        let optimizedSegments = includeTimestamps ? processedSegments : optimizeSegmentLength(processedSegments)
        
        return optimizedSegments.joined(separator: "\n")
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
    
    /// 使用反射安全獲取對象屬性值
    private func getValue(from object: Any, key: String) -> Any? {
        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            if child.label == key {
                return child.value
            }
        }
        return nil
    }
    
    /// 安全獲取 segment 的文字內容
    private func getText(from segment: Any) -> String {
        if let textValue = getValue(from: segment, key: "text") as? String {
            return textValue
        }
        return ""
    }
    
    /// 混合模式：使用 segment 邊界，但對長 segment 應用語義斷句
    private func processMixedMode(_ segments: [Any]) -> String {
        var processedSegments: [String] = []
        
        for segment in segments {
            let segmentText = cleanupText(getText(from: segment))
            let trimmedText = segmentText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedText.isEmpty || trimmedText.count < 2 {
                continue
            }
            
            // 時間戳調試信息
            if let startTime = getValue(from: segment, key: "start") as? Double,
               let endTime = getValue(from: segment, key: "end") as? Double {
                print("Mixed mode segment [\(String(format: "%.2f", startTime))s - \(String(format: "%.2f", endTime))s]: \(trimmedText)")
            }
            
            // 如果 segment 過長，使用語義斷句進一步分割
            if trimmedText.count > 100 {
                let splitText = splitTranscriptByPunctuation(trimmedText)
                let subSegments = splitText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                processedSegments.append(contentsOf: subSegments)
            } else {
                processedSegments.append(trimmedText)
            }
        }
        
        // 合併過短的 segments
        let optimizedSegments = optimizeSegmentLength(processedSegments)
        return optimizedSegments.joined(separator: "\n")
    }
    
    /// 優化 segment 長度（合併過短、分割過長）
    private func optimizeSegmentLength(_ segments: [String]) -> [String] {
        var result: [String] = []
        
        for segment in segments {
            if segment.count < 20 && !result.isEmpty {
                // 短 segment 嘗試與前一個合併
                let lastIndex = result.count - 1
                let combined = result[lastIndex] + " " + segment
                if combined.count <= 120 {
                    result[lastIndex] = combined
                } else {
                    result.append(segment)
                }
            } else if segment.count > 150 {
                // 長 segment 需要進一步分割（使用既有的語義斷句）
                let splitSegments = splitTranscriptByPunctuation(segment).components(separatedBy: "\n")
                result.append(contentsOf: splitSegments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            } else {
                result.append(segment)
            }
        }
        
        return result
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
        // 清除之前的暫存結果
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
                
                // 暫存原始轉錄結果用於模式切換
                self.cachedSegments = transcriptionResult
                self.cachedPlainText = transcriptionResult.map { self.cleanupText(self.getText(from: $0)) }.joined(separator: "\n")
                
                // 根據選擇的模式處理斷句
                let finalText: String
                switch self.splittingMode {
                case .segmentBased:
                    finalText = self.processSegmentsWithTimestamp(transcriptionResult)
                case .semantic:
                    finalText = self.splitTranscriptByPunctuation(self.cachedPlainText)
                case .mixed:
                    finalText = self.processMixedMode(transcriptionResult)
                }
                
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
