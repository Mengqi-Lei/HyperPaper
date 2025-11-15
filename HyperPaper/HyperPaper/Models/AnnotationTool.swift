//
// AnnotationTool.swift
// HyperPaper
//
// 注释工具枚举和模型
//

import SwiftUI

// MARK: - 注释工具枚举
enum AnnotationTool: String, CaseIterable {
    case none = "none"              // 无工具选中
    case freehand = "freehand"      // 自由画线
    case eraser = "eraser"          // 橡皮擦（对象橡皮擦，擦除整条线）
    case highlight = "highlight"    // 高亮（选中文本）
    case underline = "underline"    // 下划线（选中文本）
    case strikeout = "strikeout"    // 删除线（选中文本）
    case note = "note"             // Note（点击添加）
    case text = "text"             // 添加文字（点击添加）
    
    var displayName: String {
        switch self {
        case .none: return "无"
        case .freehand: return "自由画线"
        case .eraser: return "橡皮擦"
        case .highlight: return "高亮"
        case .underline: return "下划线"
        case .strikeout: return "删除线"
        case .note: return "Note"
        case .text: return "添加文字"
        }
    }
    
    var systemImage: String {
        switch self {
        case .none: return "hand.point.up.left"
        case .freehand: return "pencil.tip"
        case .eraser: return "eraser"
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikeout: return "strikethrough"
        case .note: return "note.text"
        case .text: return "textformat"
        }
    }
    
    // 是否为文本标注类工具（需要选中文本）
    var isTextAnnotation: Bool {
        switch self {
        case .highlight, .underline, .strikeout:
            return true
        default:
            return false
        }
    }
    
    // 是否为绘制类工具（需要绘制）
    var isDrawingTool: Bool {
        switch self {
        case .freehand:
            return true
        default:
            return false
        }
    }
    
    // 是否为橡皮擦工具
    var isEraserTool: Bool {
        switch self {
        case .eraser:
            return true
        default:
            return false
        }
    }
    
    // 是否为点击添加类工具（点击位置添加）
    var isClickToAdd: Bool {
        switch self {
        case .note, .text:
            return true
        default:
            return false
        }
    }
}

