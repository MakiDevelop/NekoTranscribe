# NekoTranscribe

一個 macOS 應用程式，用於語音辨識功能。目前實作了前兩個階段的功能。

## 功能特色

### 🎯 階段 1：檔案拖曳功能
- 支援拖曳以下音訊/影片檔案格式：
  - `.mp4`, `.mov`, `.mkv`, `.wav`, `.mp3`, `.m4a`, `.hevc`, `.h265`
- 支援從多種來源拖曳檔案：
  - Finder
  - 瀏覽器（Chrome、Safari、Firefox 等）
  - 其他應用程式（如 QuickTime、VLC 等）
- 注意：照片應用程式的影片需要先匯出到 Finder，然後從 Finder 拖曳
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


## Whisper 模型下載與安裝

由於 GitHub 的限制，本專案未包含 Whisper 模型檔案。請依以下步驟手動下載所需模型：

### 📦 模型來源

模型由 Hugging Face 提供：  
👉 [`argmaxinc/whisperkit-coreml`](https://huggingface.co/argmaxinc/whisperkit-coreml)

若要使用 `openai_whisper-large-v3` 模型，請前往以下位置下載相關檔案：  
🔗 [https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-large-v3](https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-large-v3)

### 📁 請下載以下五個檔案：
AudioEncoder.mlmodelc/
MelSpectrogram.mlmodelc/
TextDecoder.mlmodelc/
config.json
generation_config.json

### 📂 放置路徑

請將上述五個檔案放入以下路徑：
NekoTranscribe/NekoTranscribe/Resources/Models/openai_whisper-large-v3/
⚠️ **請確保路徑與檔名完全正確，否則模型將無法載入。**

如果你需要支援其他模型（如 base、medium），可以在這段後面加上支援列表與未來規劃。

2025-08-07筆記：

  ✅ 隱藏了所有切換控制項

  1. 斷句模式控制區域：整個 splittingModeControls 被註釋掉
  2. 模式指示器：轉錄結果中的當前模式顯示被隱藏
  3. 測試按鈕：所有調試用的按鈕都已移除

  🧹 清理了調試代碼

  1. 移除了所有 🔥 DEBUG: 輸出
  2. 保留了核心功能代碼：
    - 暫存機制仍然存在
    - didSet 監聽器仍然工作
    - refreshTranscriptFromCache 方法完整保留
    - 時間戳和模式切換邏輯完整

  🔮 將來如果要恢復功能

  只需要取消註釋這一行：
  // splittingModeControls // 暫時隱藏

  所有的底層邏輯都還在，包括：
  - 三種斷句模式的處理邏輯
  - 時間戳開關功能
  - 實時切換機制
  - 暫存和刷新系統

  現在 UI 應該回到了原本簡潔的狀態，只有語言選擇和基本的轉錄功能。

