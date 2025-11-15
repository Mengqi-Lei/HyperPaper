//
// TranslationTargetLanguage.swift
// HyperPaper
//
// 翻译目标语言配置
//

import Foundation

/// 翻译目标语言枚举
enum TranslationTargetLanguage: String, CaseIterable, Identifiable {
    case auto = "自动检测"
    case chinese = "中文"
    case english = "English"
    case japanese = "日本語"
    case korean = "한국어"
    case french = "Français"
    case german = "Deutsch"
    case spanish = "Español"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto:
            return "自动检测"
        case .chinese:
            return "中文"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Español"
        }
    }
    
    var apiName: String {
        switch self {
        case .auto:
            return "auto" // 自动检测时，需要根据源文本语言决定
        case .chinese:
            return "中文"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Español"
        }
    }
    
    /// 从UserDefaults读取当前目标语言
    static var current: TranslationTargetLanguage {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "translationTargetLanguage"),
               let language = TranslationTargetLanguage(rawValue: rawValue) {
                return language
            }
            return .auto // 默认自动检测
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "translationTargetLanguage")
            UserDefaults.standard.synchronize()
        }
    }
    
    /// 根据源文本语言和目标语言设置，返回实际的目标语言
    /// - Parameter sourceLanguage: 源文本语言（"中文" 或 "English"）
    /// - Returns: 实际的目标语言名称
    func getTargetLanguage(sourceLanguage: String) -> String {
        if self == .auto {
            // 自动检测：如果包含中文，翻译成英文；否则翻译成中文
            return sourceLanguage == "中文" ? "English" : "中文"
        } else {
            // 使用用户选择的目标语言
            return self.apiName
        }
    }
}


