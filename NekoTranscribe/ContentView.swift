//
//  ContentView.swift
//  NekoTranscribe
//
//  Created by 千葉牧人 on 2025/8/5.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit // 需加這行才能用 NSWorkspace

struct ContentView: View {
    @StateObject private var audioProcessor = AudioProcessor()
    @State private var draggedFileURL: URL?
    @State private var convertedFileURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                    
                    Text("支援格式：MP4, MOV, MKV, WAV, MP3, M4A")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("轉換完成！")
                        .font(.headline)
                        .foregroundColor(.green)
                    
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
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                if let error = error {
                    showError(message: "載入檔案時發生錯誤：\(error.localizedDescription)")
                    return
                }
                
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    showError(message: "無法解析檔案 URL")
                    return
                }
                
                // 檢查檔案格式
                if !audioProcessor.isSupportedFile(url) {
                    showError(message: "不支援的檔案格式。請選擇 MP4, MOV, MKV, WAV, MP3, 或 M4A 檔案。")
                    return
                }
                
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
