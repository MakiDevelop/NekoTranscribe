# NekoTranscribe

一個 macOS 應用程式，用於語音辨識功能。目前實作了前兩個階段的功能。

## 功能特色

### 🎯 階段 1：檔案拖曳功能
- 支援拖曳以下音訊/影片檔案格式：
  - `.mp4`, `.mov`, `.mkv`, `.wav`, `.mp3`, `.m4a`
- 拖曳成功後顯示檔案名稱與完整路徑
- 不支援的檔案格式會顯示錯誤提示

### 🎯 階段 2：音訊轉換功能
- 使用 ffmpeg 將輸入檔案轉換為 Whisper 模型可接受的格式：
  - 單聲道（mono）
  - 16kHz 取樣率
  - Linear PCM WAV 格式
- 轉換後的檔案儲存在 Documents 目錄中

## 系統需求

- macOS 15.5 或更新版本
- 需要安裝 ffmpeg（建議使用 Homebrew 安裝）

### 安裝 ffmpeg

```bash
# 使用 Homebrew 安裝 ffmpeg
brew install ffmpeg
```

## 使用方法

1. 啟動 NekoTranscribe 應用程式
2. 將支援的音訊或影片檔案拖曳到應用程式視窗中
3. 應用程式會自動開始轉換檔案
4. 轉換完成後，會在 Documents 目錄中產生 `.wav` 檔案

## 開發狀態

- ✅ 階段 1：檔案拖曳 UI
- ✅ 階段 2：ffmpeg 音訊轉換
- 🔄 階段 3：Whisper 模型整合（開發中）
- 🔄 階段 4：轉錄結果顯示（開發中）

## 技術架構

- **UI 框架**：SwiftUI
- **音訊處理**：ffmpeg（透過 Process 執行）
- **檔案格式支援**：多種音訊/影片格式
- **輸出格式**：WAV（16kHz, mono, Linear PCM）

## 專案結構

```
NekoTranscribe/
├── NekoTranscribe/
│   ├── NekoTranscribeApp.swift      # App 入口點
│   ├── ContentView.swift            # 主要 UI 視圖
│   ├── AudioProcessor.swift         # 音訊處理邏輯
│   └── Assets.xcassets/            # 應用程式資源
└── README.md                        # 專案說明
```

## 注意事項

- 確保系統已安裝 ffmpeg
- 轉換過程可能需要一些時間，取決於檔案大小
- 支援的檔案格式有限，不支援的格式會顯示錯誤訊息 