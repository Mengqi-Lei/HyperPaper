//
// APIConfig.swift
// HyperPaper
//
// API配置信息
//

import Foundation

struct APIConfig {
    // ⚠️ 请在此处配置你的 API Key
    // 获取 API Key: https://api.probex.top
    static let apiKey = "YOUR_API_KEY_HERE"
    static let baseURL = "https://api.probex.top/v1/chat/completions"
    
    // 模型选择（从UserDefaults读取，如果没有则使用默认值）
    static var model: String {
        get {
            UserDefaults.standard.string(forKey: "selectedModel") ?? "Qwen2.5-14B-Instruct"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedModel")
        }
    }
    
    // 可用模型列表
    static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "Qwen2.5-14B-Instruct",
            name: "Qwen2.5-14B-Instruct",
            description: "快速响应（推荐）",
            price: "输入 $0.30/M, 输出 $0.45/M"
        ),
        ModelInfo(
            id: "Qwen2.5-32B-Instruct",
            name: "Qwen2.5-32B-Instruct",
            description: "平衡性能",
            price: "输入 $0.50/M, 输出 $0.75/M"
        ),
        ModelInfo(
            id: "deepseek-chat",
            name: "DeepSeek Chat",
            description: "高质量回答",
            price: "输入 $1.00/M, 输出 $1.50/M"
        ),
        ModelInfo(
            id: "Qwen3-235B-A22B",
            name: "Qwen3-235B-A22B",
            description: "最强能力（较慢）",
            price: "价格较高"
        ),
        ModelInfo(
            id: "Qwen-VL-Max",
            name: "Qwen-VL-Max",
            description: "视觉模型（公式识别）",
            price: "支持图像输入"
        )
    ]
    
    // 备用URL尝试顺序（如果主URL失败）
    static let alternativeURLs = [
        "https://api.probex.top/v1/chat/completions",
        "https://api.probex.top/v1",
        "https://api.probex.top"
    ]
}

// 模型信息结构
struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let price: String
}

