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
    
    // 使用 AppStorage 來持久化儲存語言選擇
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "zh-Hant"
    
    @State private var draggedFileURL: URL?
    @State private var convertedFileURL: URL?
    @State private var transcript = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    // 更新語言列表以區分繁體和簡體
    private let availableLanguages = [
        "繁體中文": "zh-Hant",
        "简体中文": "zh-Hans",
        "English": "en",
        "Japanese": "ja",
        "Korean": "ko",
        "French": "fr",
        "German": "de",
        "Spanish": "es"
    ]
    
    var body: some View {
        VStack(spacing: 15) {
            Text("NekoTranscribe")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            languagePicker
            
            dropArea
            
            if let fileURL = draggedFileURL {
                fileInfo(for: fileURL)
            }
            
            statusAndControls
            
            if !transcript.isEmpty {
                transcriptView
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 550, minHeight: 500) // 稍微增加高度以容納 Picker
        .alert("提示", isPresented: $showError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear(perform: stopAudio)
    }
    
    // MARK: - Subviews
    
    private var languagePicker: some View {
        Picker("音訊語言：", selection: $selectedLanguage) {
            ForEach(availableLanguages.keys.sorted { $0 < $1 }, id: \.self) { key in
                Text(key).tag(availableLanguages[key]!)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 5)
    }
    
    private var dropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .stroke(Color(NSColor.separatorColor), lineWidth: 2)
                .frame(height: 180)
            
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("拖曳音訊或影片檔案到此處")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("支援格式：MP4, MOV, MKV, WAV, MP3, M4A, HEVC")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard audioProcessor.isModelLoaded else { return false }
            handleDrop(providers: providers)
            return true
        }
        .overlay(loadingOverlay)
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if !audioProcessor.isModelLoaded {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                
                VStack {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在載入 AI 模型，請稍候...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                }
            }
        }
    }
    
    private func fileInfo(for url: URL) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("已選擇檔案：").font(.headline)
            Text(url.lastPathComponent)
                .font(.body)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var statusAndControls: some View {
        VStack {
            if audioProcessor.isProcessing {
                ProgressView {
                    Text(audioProcessor.processingStatus)
                        .font(.body)
                }
                .progressViewStyle(LinearProgressViewStyle())
                
            } else if let convertedURL = convertedFileURL {
                playbackControls(for: convertedURL)
            } else {
                HStack(spacing: 20) {
                    Button {
                        openDocumentsFolder()
                    } label: {
                        Label("打開輸出資料夾", systemImage: "folder")
                    }
                    Button(role: .destructive) {
                        clearExportedAudio()
                    } label: {
                        Label("清除已輸出音訊", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .opacity(audioProcessor.isModelLoaded ? 1 : 0)
    }
    
    private func playbackControls(for url: URL) -> some View {
        HStack {
            Text("音訊準備完成！")
                .font(.headline)
                .foregroundColor(.green)
            
            Spacer()
            
            Button {
                if isPlaying {
                    stopAudio()
                } else {
                    playAudio(url: url)
                }
            } label: {
                Label(isPlaying ? "停止" : "播放", systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var transcriptView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("逐字稿結果：")
                    .font(.headline)
                Spacer()
                Button {
                    copyToClipboard(transcript)
                } label: {
                    Label("複製", systemImage: "doc.on.doc")
                }
            }
            
            ScrollView {
                Text(transcript)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(minHeight: 100)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
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
                    showError(message: "不支援的檔案格式。請選擇 MP4, MOV, MKV, WAV, MP3, M4A, 或 HEVC 檔案。")
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
                    showError(message: "已刪除 \(count) 個已轉換的音訊檔案")
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
        showError(message: "已複製到剪貼簿！")
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