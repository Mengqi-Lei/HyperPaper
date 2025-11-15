//
// FormulaProcessingMode.swift
// HyperPaper
//
// 公式处理模式配置
//

import Foundation

/// 公式处理模式枚举
enum FormulaProcessingMode: String, CaseIterable, Identifiable {
    case none = "不处理公式"
    case localOCR = "基于本地OCR处理公式"
    case vlmAPI = "基于VLM API处理公式"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .none:
            return "直接提取文本，不进行公式识别"
        case .localOCR:
            return "使用本地Pix2Text进行OCR识别，支持公式转LaTeX"
        case .vlmAPI:
            return "使用Vision API（Qwen-VL-Max）进行识别"
        }
    }
    
    /// 从UserDefaults读取当前模式
    static var current: FormulaProcessingMode {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "formulaProcessingMode"),
               let mode = FormulaProcessingMode(rawValue: rawValue) {
                return mode
            }
            return .none // 默认不处理公式
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "formulaProcessingMode")
            UserDefaults.standard.synchronize()
        }
    }
}

