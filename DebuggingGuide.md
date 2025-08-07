# 實時斷句切換功能調試指南

## 🔥 現在應該出現的調試輸出

當您啟動應用時，Console 中應該看到：

### 1. 應用啟動時
```
🔥 DEBUG: AudioProcessor init() 被呼叫
🔥 DEBUG: ContentView onAppear
🔥 DEBUG: 初始模式: segmentBased
🔥 DEBUG: 初始時間戳: false
```

### 2. 點擊 "🧪 測試" 按鈕時
```
🔥 DEBUG: 測試按鈕被點擊
🔥 DEBUG: 當前模式: segmentBased
🔥 DEBUG: 時間戳: false
🔥 DEBUG: transcript 長度: [數字]
```

### 3. 切換斷句模式時
```
🔥 DEBUG: ContentView onChange splittingMode → semantic
🔥 DEBUG: splittingMode didSet 被觸發! segmentBased → semantic
🔥 DEBUG: cachedSegments.count = [數字]
🔥 DEBUG: 條件滿足，呼叫 refreshTranscriptFromCache (或 條件不滿足，不刷新)
```

### 4. 切換時間戳時
```
🔥 DEBUG: ContentView onChange includeTimestamps → true
🔥 DEBUG: includeTimestamps didSet 被觸發! false → true
🔥 DEBUG: cachedSegments.count = [數字]
🔥 DEBUG: 條件滿足，呼叫 refreshTranscriptFromCache (或 條件不滿足，不刷新)
```

### 5. 點擊刷新按鈕時
```
🔥 DEBUG: 用戶點擊刷新按鈕
🔥 DEBUG: forceRefreshFromCache() 被呼叫
🔥 DEBUG: cachedSegments.count = [數字]
🔥 DEBUG: currentTranscript.count = [數字]
```

## 🚨 如果沒有看到這些輸出

**可能原因：**

1. **代碼沒有被編譯**
   - 解決方案：重新 Build 整個專案

2. **Console 沒有顯示**
   - 解決方案：確保 Xcode 的 Console 窗口是開啟的

3. **代碼在錯誤的地方**
   - 解決方案：確認您編輯的是正確的文件

## 🔧 測試步驟

1. **啟動應用** → 應該看到啟動調試輸出
2. **點擊 🧪 測試按鈕** → 應該看到當前狀態
3. **切換斷句模式** → 應該看到 onChange 和 didSet 輸出
4. **切換時間戳** → 應該看到相應的調試輸出
5. **點擊刷新按鈕** → 應該看到刷新相關輸出

## 📊 預期結果分析

### 如果看到調試輸出但功能不工作
- **cachedSegments.count = 0** → 暫存沒有內容，需要先上傳音訊
- **條件不滿足，不刷新** → 沒有暫存數據或模式沒有真正改變

### 如果完全沒有調試輸出
- 代碼可能沒有被正確編譯或使用舊版本
- 需要確認 Build 和 Run

## 🎯 下一步行動

1. **先確認能看到基本調試輸出**
2. **上傳一個音訊文件完成轉錄**
3. **然後測試模式切換**
4. **根據調試輸出確認具體問題**

---

**重要提醒**：所有帶 `🔥 DEBUG:` 的輸出都是我新加的調試信息，如果看不到這些，說明修改沒有生效。