//
// Annotation.swift
// HyperPaper
//
// PDF注释数据模型
//

import Foundation
import PDFKit
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 注释类型枚举
enum AnnotationType: String, Codable, CaseIterable {
    case highlight = "highlight"           // 高亮
    case underline = "underline"           // 下划线
    case strikeout = "strikeout"           // 删除线
    case textNote = "textNote"             // 文本注释
    case line = "line"                     // 直线
    case arrow = "arrow"                   // 箭头
    case rectangle = "rectangle"           // 矩形
    case circle = "circle"                 // 椭圆
    case freehand = "freehand"             // 手写批注
    case agentNote = "agentNote"           // Agent模式生成的注释
    
    var displayName: String {
        switch self {
        case .highlight: return "高亮"
        case .underline: return "下划线"
        case .strikeout: return "删除线"
        case .textNote: return "文本注释"
        case .line: return "直线"
        case .arrow: return "箭头"
        case .rectangle: return "矩形"
        case .circle: return "椭圆"
        case .freehand: return "手写批注"
        case .agentNote: return "智能批注"
        }
    }
    
    var systemImage: String {
        switch self {
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikeout: return "strikethrough"
        case .textNote: return "note.text"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .freehand: return "pencil"
        case .agentNote: return "sparkles"
        }
    }
}

// MARK: - 注释数据模型
struct Annotation: Identifiable, Codable, Equatable {
    let id: UUID
    let type: AnnotationType
    let pageIndex: Int
    let rect: CGRect  // PDF坐标系（左下角为原点）
    let color: AnnotationColor
    let content: String?  // 文本注释内容
    let createdAt: Date
    var updatedAt: Date
    
    // Agent模式特有字段
    let sourceText: String?  // 原始选中文本
    let translation: String?  // 翻译结果
    let qaResult: String?  // 问答结果
    
    // 图形标注特有字段
    let startPoint: CGPoint?  // 起点（用于直线、箭头）
    let endPoint: CGPoint?  // 终点（用于直线、箭头）
    let path: [CGPoint]?  // 路径（用于手写批注、多边形）
    
    init(
        id: UUID = UUID(),
        type: AnnotationType,
        pageIndex: Int,
        rect: CGRect,
        color: AnnotationColor = .yellow,
        content: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceText: String? = nil,
        translation: String? = nil,
        qaResult: String? = nil,
        startPoint: CGPoint? = nil,
        endPoint: CGPoint? = nil,
        path: [CGPoint]? = nil
    ) {
        self.id = id
        self.type = type
        self.pageIndex = pageIndex
        self.rect = rect
        self.color = color
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceText = sourceText
        self.translation = translation
        self.qaResult = qaResult
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.path = path
    }
    
    // 更新内容
    func updatingContent(_ newContent: String) -> Annotation {
        var updated = self
        updated.updatedAt = Date()
        // 注意：Swift 中 struct 是值类型，需要创建新的实例
        return Annotation(
            id: self.id,
            type: self.type,
            pageIndex: self.pageIndex,
            rect: self.rect,
            color: self.color,
            content: newContent,
            createdAt: self.createdAt,
            updatedAt: Date(),
            sourceText: self.sourceText,
            translation: self.translation,
            qaResult: self.qaResult,
            startPoint: self.startPoint,
            endPoint: self.endPoint,
            path: self.path
        )
    }
}

// MARK: - 注释颜色
enum AnnotationColor: String, Codable, CaseIterable {
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case red = "red"
    case orange = "orange"
    case purple = "purple"
    case pink = "pink"
    case gray = "gray"
    
    var color: Color {
        switch self {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
    
    var nsColor: NSColor {
        switch self {
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .gray: return .systemGray
        }
    }
    
    /// 从 SwiftUI Color 转换为 AnnotationColor
    /// 优先直接匹配系统颜色，如果无法匹配则使用 RGB 阈值匹配（与 annotationColor(from: NSColor?) 保持一致）
    static func from(_ color: Color) -> AnnotationColor {
        // 首先尝试直接匹配系统颜色（更准确）
        #if os(macOS)
        let nsColor = NSColor(color)
        #else
        let nsColor = UIColor(color)
        #endif
        
        // 使用与 annotationColor(from: NSColor?) 相同的逻辑
        // 统一使用 CGColor 来获取 RGB 值（跨平台，更可靠）
        let cgColor = nsColor.cgColor
        
        // 转换为RGB颜色空间
        guard let rgbColor = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let components = rgbColor.components, components.count >= 3 else {
            return .yellow // 默认黄色
        }
        
        // 获取RGB分量
        let r = components[0]
        let g = components.count >= 2 ? components[1] : 0
        let b = components.count >= 3 ? components[2] : 0
        
        // 使用与 annotationColor(from: NSColor?) 相同的阈值匹配逻辑（更精确）
        // 优先级：蓝色 > 绿色 > 红色 > 黄色 > 橙色 > 紫色 > 粉色
        
        // 蓝色：B 明显大于 R 和 G
        if b > 0.6 && b > r + 0.2 && b > g + 0.2 {
            return .blue
        }
        
        // 绿色：G 明显大于 R 和 B
        if g > 0.6 && g > r + 0.2 && g > b + 0.2 {
            return .green
        }
        
        // 红色：R 明显大于 G 和 B
        if r > 0.6 && r > g + 0.2 && r > b + 0.2 {
            return .red
        }
        
        // 黄色：R 和 G 都高，B 低
        if r > 0.7 && g > 0.7 && b < 0.4 {
            return .yellow
        }
        
        // 橙色：R 高，G 中等，B 低
        if r > 0.7 && g > 0.4 && g < 0.7 && b < 0.4 {
            return .orange
        }
        
        // 紫色：R 和 B 都高，G 低
        if r > 0.5 && b > 0.5 && g < 0.4 {
            return .purple
        }
        
        // 粉色：R 很高，G 和 B 中等
        if r > 0.8 && g > 0.4 && g < 0.7 && b > 0.4 && b < 0.7 {
            return .pink
        }
        
        // 灰色：RGB 值接近
        if abs(r - g) < 0.2 && abs(g - b) < 0.2 && abs(r - b) < 0.2 {
            return .gray
        }
        
        // 默认：根据主要颜色分量判断
        if b > r && b > g {
            return .blue
        } else if g > r && g > b {
            return .green
        } else if r > g && r > b {
            return .red
        }
        
        return .yellow // 默认黄色
    }
}

// 注意：CGRect 和 CGPoint 在 macOS 26.0+ 中已经原生支持 Codable，无需扩展

