//
//  ContentView.swift
//  NekoTranscribe
//
//  Created by 千葉牧人 on 2025/8/5.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit // 需加這行才能用 NSWorkspace
import AVFoundation

struct ContentView: View {
    @StateObject private var audioProcessor = AudioProcessor()
    @State private var draggedFileURL: URL?
    @State private var convertedFileURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            // 標題
            Text("NekoTranscribe")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // 拖曳區域
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .stroke(Color(NSColor.separatorColor), lineWidth: 2)
                    .frame(height: 200)
                
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("拖曳音訊或影片檔案到此處")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("支援格式：MP4, MOV, MKV, WAV, MP3, M4A, HEVC")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    
                    Text("可從 Finder、瀏覽器或其他應用程式拖曳")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    
                    Text("注意：照片應用程式的影片需先匯出到 Finder")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }
            .onDrop(of: [.fileURL, .movie, .audio, .data, .image], isTargeted: nil) { providers in
                print("拖曳事件被觸發！")
                handleDrop(providers: providers)
                return true
            }
            
            // 檔案資訊顯示
            if let fileURL = draggedFileURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已選擇檔案：")
                        .font(.headline)
                    
                    Text("檔案名稱：\(fileURL.lastPathComponent)")
                        .font(.body)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    
                    Text("檔案路徑：\(fileURL.path)")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .lineLimit(2)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // 操作按鈕
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
            
            // 處理狀態
            if audioProcessor.isProcessing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text(audioProcessor.processingStatus)
                        .font(.body)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }
                .padding()
            }
            
            // 轉換結果
            if let convertedURL = convertedFileURL {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("轉換完成！")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Button {
                            if isPlaying {
                                stopAudio()
                            } else {
                                playAudio(url: convertedURL)
                            }
                        } label: {
                            Label(isPlaying ? "停止" : "播放", systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .font(.body)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Text("輸出檔案：\(convertedURL.lastPathComponent)")
                        .font(.body)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    
                    Text("檔案路徑：\(convertedURL.path)")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .lineLimit(2)
                }
                .padding()
                .background(Color(.systemGreen).opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .alert("錯誤", isPresented: $showError) {
            Button("確定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        print("開始處理拖曳，providers 數量：\(providers.count)")
        guard let provider = providers.first else { 
            print("沒有找到 provider")
            return 
        }
        
        // 嘗試不同的檔案類型識別符
        let typeIdentifiers = [
            UTType.fileURL.identifier,
            UTType.movie.identifier,
            UTType.audio.identifier,
            UTType.data.identifier,
            UTType.image.identifier,
            "public.movie",           // 照片應用程式可能使用這個
            "public.video",           // 影片類型
            "public.audiovisual-content", // 視聽內容
            "com.apple.quicktime-movie", // QuickTime 影片
            "public.mpeg-4",         // MP4 格式
            "public.3gpp",           // 3GPP 格式
            "public.3gpp2"           // 3GPP2 格式
        ]
        
        print("檢查的類型識別符：\(typeIdentifiers)")
        
        // 尋找第一個可用的類型識別符
        var foundValidType = false
        for typeIdentifier in typeIdentifiers {
            print("檢查類型：\(typeIdentifier)")
            if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                print("找到支援的類型：\(typeIdentifier)")
                foundValidType = true
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            showError(message: "載入檔案時發生錯誤：\(error.localizedDescription)")
                            return
                        }
                        
                        var fileURL: URL?
                        
                        print("處理拖曳項目，類型：\(type(of: item))")
                        
                        // 處理不同類型的資料
                        if let data = item as? Data {
                            print("項目是 Data 類型，大小：\(data.count)")
                            // 嘗試從 Data 建立 URL
                            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                                fileURL = url
                                print("從 Data 建立 URL 成功：\(url.path)")
                            } else if let string = String(data: data, encoding: .utf8),
                                      let url = URL(string: string) {
                                fileURL = url
                                print("從 Data 轉換為 String 再建立 URL 成功：\(url.path)")
                            } else {
                                print("無法從 Data 建立 URL")
                                // 嘗試其他編碼方式
                                if let string = String(data: data, encoding: .utf16),
                                      let url = URL(string: string) {
                                    fileURL = url
                                    print("從 Data 使用 UTF-16 編碼建立 URL 成功：\(url.path)")
                                }
                            }
                        } else if let url = item as? URL {
                            fileURL = url
                            print("項目是 URL 類型：\(url.path)")
                        } else if let string = item as? String,
                                  let url = URL(string: string) {
                            fileURL = url
                            print("項目是 String 類型，轉換為 URL：\(url.path)")
                        } else {
                            print("無法識別的項目類型：\(type(of: item))")
                            // 嘗試將項目轉換為字串
                            let itemString = String(describing: item)
                            if let url = URL(string: itemString) {
                                fileURL = url
                                print("從項目描述建立 URL 成功：\(url.path)")
                            }
                        }
                        
                        guard let url = fileURL else {
                            print("無法解析檔案 URL")
                            showError(message: "無法解析檔案 URL")
                            return
                        }
                        
                        print("檔案路徑：\(url.path)")
                        print("檔案副檔名：\(url.pathExtension)")
                        
                        // 檢查是否為照片應用程式的縮圖
                        if url.path.contains("Photos Library.photoslibrary/resources/derivatives") {
                            print("檢測到照片應用程式的縮圖檔案")
                            showError(message: "無法從照片應用程式直接拖曳影片。請先將影片匯出到 Finder，然後從 Finder 拖曳到應用程式中。")
                            return
                        }
                        
                        // 檢查檔案格式
                        if !audioProcessor.isSupportedFile(url) {
                            print("不支援的檔案格式：\(url.pathExtension)")
                            showError(message: "不支援的檔案格式。請選擇 MP4, MOV, MKV, WAV, MP3, M4A, 或 HEVC 檔案。")
                            return
                        }
                        
                        print("檔案格式支援，開始處理")
                        
                        // 顯示檔案資訊
                        draggedFileURL = url
                        convertedFileURL = nil
                        
                        // 開始轉換
                        audioProcessor.convertToWhisperFormat(inputURL: url) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let outputURL):
                                    convertedFileURL = outputURL
                                    print("轉換成功：\(outputURL.path)")
                                case .failure(let error):
                                    showError(message: "轉換失敗：\(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                break
            }
        }
        
        if !foundValidType {
            showError(message: "不支援的拖曳類型")
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    // 打開 Finder 並選擇 Documents 目錄
    private func openDocumentsFolder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        NSWorkspace.shared.open(documentsPath)
    }
    // 播放音訊檔案
    private func playAudio(url: URL) {
        print("播放音訊檔案：\(url.path)")
        
        // 檢查檔案是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            showError(message: "音訊檔案不存在")
            return
        }
        
        do {
            // 停止當前播放
            if isPlaying {
                stopAudio()
            }
            
            // 建立新的播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            
            isPlaying = true
            print("開始播放音訊")
            
            // 設定 Timer 來檢查播放狀態
            playTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if let player = audioPlayer, !player.isPlaying {
                    DispatchQueue.main.async {
                        self.isPlaying = false
                        self.playTimer?.invalidate()
                        self.playTimer = nil
                        print("音訊播放完成")
                    }
                }
            }
            
        } catch {
            print("播放音訊失敗：\(error.localizedDescription)")
            showError(message: "播放音訊失敗：\(error.localizedDescription)")
        }
    }
    
    // 停止播放音訊
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
        print("停止播放音訊")
    }
    

    
    // 刪除所有已輸出的音訊
    private func clearExportedAudio() {
        audioProcessor.deleteAllExportedAudio { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    showError(message: "已刪除 \(count) 個音訊檔案")
                case .failure(let error):
                    showError(message: "刪除失敗：\(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
