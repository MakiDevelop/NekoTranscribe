
//
//  ContentView.swift
//  NekoTranscribe
//
//  Created by 千葉牧人 on 2025/8/5.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AVFoundation

@MainActor
struct ContentView: View {
    @StateObject private var audioProcessor = AudioProcessor()
    
    // MARK: - State Properties
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "zh-Hant"
    
    @State private var draggedFileURL: URL?
    @State private var convertedFileURL: URL?
    @State private var transcript = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    // UI/UX State
    @State private var isDropTargeted = false
    @State private var didCopy = false

    // MARK: - Language Options
    private let availableLanguages = [
        "繁體中文": "zh-Hant",
        "简体中文": "zh-Hans",
        "English": "en",
        "Japanese": "ja",
        "Korean": "ko",
        "French": "fr",
        "German": "de",
        "廣東話(粵語)": "yue"
    ]

    // MARK: - Body
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                headerView
                languagePicker
                controlsView // 包含時間戳開關
                dropArea
                resultArea
            }
            .padding()
        }
        .onChange(of: audioProcessor.currentTranscript) { newValue in
            if !newValue.isEmpty {
                transcript = postProcessText(newValue)
            }
        }
        .frame(minWidth: 550, minHeight: 550)
        .alert("提示", isPresented: $showError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear(perform: stopAudio)
    }

    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("NekoTranscribe")
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
            Button(role: .destructive) {
                clearExportedAudio()
            } label: {
                Label("清除暫存", systemImage: "trash")
            }
            .help("清除所有已轉換的音訊檔")
        }
    }
    
    private var languagePicker: some View {
        Picker("音訊語言：", selection: $selectedLanguage) {
            ForEach(availableLanguages.keys.sorted { $0 < $1 }, id: \.self) { key in
                Text(key).tag(availableLanguages[key]!)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 5)
    }
    
    private var controlsView: some View {
        HStack {
            Toggle("包含時間戳", isOn: $audioProcessor.includeTimestamps)
                .help("在逐字稿中顯示每個語句的時間戳")
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private var dropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: isDropTargeted ? 4 : 2, dash: [isDropTargeted ? 12 : 6]))
                .padding(4)

            VStack(spacing: 12) {
                Image(systemName: audioProcessor.isModelLoaded ? "arrow.down.doc.fill" : "hourglass")
                    .font(.system(size: 48))
                    .symbolEffect(.bounce, value: isDropTargeted)
                    .foregroundColor(isDropTargeted ? .accentColor : .secondary)
                
                Text(audioProcessor.isModelLoaded ? "拖曳音訊或影片檔案到此處" : "正在載入 AI 模型...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 200)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard audioProcessor.isModelLoaded else { return false }
            handleDrop(providers: providers)
            return true
        }
        .animation(.easeInOut, value: isDropTargeted)
    }
    
    private var resultArea: some View {
        VStack {
            if audioProcessor.isProcessing {
                processingView
            } else if !transcript.isEmpty {
                transcriptView
            } else if let url = draggedFileURL {
                fileInfo(for: url)
            } else {
                idlePromptView
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .animation(.easeInOut, value: audioProcessor.isProcessing)
        .animation(.easeInOut, value: transcript)
    }
    
    private var idlePromptView: some View {
        VStack {
            Text("完成拖曳後，這裡會顯示分析結果")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func fileInfo(for url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已選擇檔案：")
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .help(url.path)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 15) {
            ProgressView() {
                Text(audioProcessor.processingStatus)
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            
            if !transcript.isEmpty {
                ScrollView {
                    Text(transcript)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("逐字稿結果：")
                    .font(.headline)
                
                if let url = convertedFileURL {
                    Button {
                        if isPlaying { stopAudio() } else { playAudio(url: url) }
                    } label: {
                        Label(isPlaying ? "停止" : "播放", systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    }
                    .help("播放轉換後的音訊")
                }
                
                Spacer()
                
                Button {
                    copyToClipboard(transcript)
                } label: {
                    Label(didCopy ? "已複製!" : "複製", systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .help("複製逐字稿")
                .disabled(didCopy)
            }
            
            ScrollView {
                Text(transcript)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    // MARK: - Functions
    
    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            Task {
                if let error = error {
                    showError(message: "載入檔案時發生錯誤：\(error.localizedDescription)")
                    return
                }
                
                guard let urlData = item as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                    showError(message: "無法解析檔案 URL")
                    return
                }
                
                if !audioProcessor.isSupportedFile(url) {
                    showError(message: "不支援的檔案格式。")
                    return
                }
                
                self.draggedFileURL = url
                self.convertedFileURL = nil
                self.transcript = ""
                self.stopAudio()
                
                audioProcessor.convertToWhisperFormat(inputURL: url) { result in
                    Task {
                        switch result {
                        case .success(let outputURL):
                            self.convertedFileURL = outputURL
                            transcribe(audioURL: outputURL)
                        case .failure(let error):
                            showError(message: "轉換失敗：\(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func transcribe(audioURL: URL) {
        let whisperLanguageCode = selectedLanguage.starts(with: "zh") ? "zh" : selectedLanguage
        
        let onProgress: (String) -> Void = { progressText in
            DispatchQueue.main.async {
                self.transcript = self.postProcessText(progressText)
            }
        }
        
        let onCompletion: (Result<String, Error>) -> Void = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let finalText):
                    self.transcript = self.postProcessText(finalText)
                case .failure(let error):
                    showError(message: "分析失敗：\(error.localizedDescription)")
                }
            }
        }
        
        audioProcessor.transcribeAudio(url: audioURL, language: whisperLanguageCode, onProgress: onProgress, onCompletion: onCompletion)
    }
    
    private func postProcessText(_ text: String) -> String {
        if self.selectedLanguage == "zh-Hant" {
            return text.applyingTransform(StringTransform(rawValue: "Any-Hant"), reverse: false) ?? text
        } else {
            return text
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func openDocumentsFolder() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        NSWorkspace.shared.open(documentsURL)
    }
    
    private func clearExportedAudio() {
        audioProcessor.deleteAllExportedAudio { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    showError(message: "已清除 \(count) 個已轉換的音訊檔案")
                    self.draggedFileURL = nil
                    self.convertedFileURL = nil
                    self.transcript = ""
                case .failure(let error):
                    showError(message: "刪除失敗：\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        didCopy = true
        // Reset the button state after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }
    
    // MARK: - Audio Player
    
    private func playAudio(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            showError(message: "音訊檔案不存在")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
        } catch {
            showError(message: "播放音訊失敗：\(error.localizedDescription)")
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
}

#Preview {
    ContentView()
}
