#!/usr/bin/env swift

//
//  SimpleTest.swift
//  簡單測試實時切換功能
//

import Foundation

print("=== 簡單實時切換測試 ===")

class SimpleProcessor {
    enum Mode {
        case segment, semantic, mixed
    }
    
    var mode: Mode = .segment {
        didSet {
            print("🎛️ 模式改變: \(oldValue) → \(mode)")
            if !cachedText.isEmpty {
                refresh()
            }
        }
    }
    
    var includeTime = false {
        didSet {
            print("🕐 時間戳改變: \(oldValue) → \(includeTime)")
            if !cachedText.isEmpty {
                refresh()
            }
        }
    }
    
    private var cachedText = ""
    var result = "" {
        didSet {
            print("📝 結果更新: 長度 \(result.count)")
        }
    }
    
    func setCache(_ text: String) {
        cachedText = text
        refresh()
    }
    
    private func refresh() {
        switch mode {
        case .segment:
            result = includeTime ? "[00:00] \(cachedText)" : cachedText
        case .semantic:
            result = cachedText.replacingOccurrences(of: "但是", with: "\n但是")
        case .mixed:
            let split = cachedText.replacingOccurrences(of: "但是", with: "\n但是")
            result = includeTime ? "[00:00] " + split.replacingOccurrences(of: "\n", with: "\n[00:05] ") : split
        }
    }
}

let processor = SimpleProcessor()

print("\n1️⃣ 初始設置")
processor.setCache("我跟你說但是這個功能很好用")

print("\n2️⃣ 切換到語義模式")
processor.mode = .semantic

print("\n3️⃣ 開啟時間戳")
processor.includeTime = true

print("\n4️⃣ 切換到混合模式")
processor.mode = .mixed

print("\n5️⃣ 切回語音分段模式")
processor.mode = .segment

print("\n=== 測試完成 ===")
print("最終結果: \(processor.result)")