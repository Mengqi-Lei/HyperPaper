//
// CustomInkAnnotation.swift
// HyperPaper
//
// 自定义Ink注释类：实现draw方法以确保注释正确显示
//

import PDFKit
import AppKit

/// 自定义Ink注释类，通过实现draw方法确保注释正确显示
class CustomInkAnnotation: PDFAnnotation {
    // 存储ink路径点（相对于bounds的坐标）
    var inkPaths: [[CGPoint]] = []
    var strokeColor: NSColor = .black
    var strokeWidth: CGFloat = 2.0
    
    // 初始化方法
    override init(bounds: CGRect, forType annotationType: PDFAnnotationSubtype, withProperties properties: [AnyHashable : Any]?) {
        super.init(bounds: bounds, forType: annotationType, withProperties: properties)
        self.shouldDisplay = true
        self.shouldPrint = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.shouldDisplay = true
        self.shouldPrint = true
    }
    
    // 实现draw方法，手动绘制ink路径
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        // 保存图形上下文状态
        context.saveGState()
        
        // 关键：PDFKit的draw方法中，context已经转换到视图坐标系统
        // 我们需要使用页面坐标（bounds.origin + 相对坐标）而不是相对坐标
        // 这是因为CTM显示context转换到了视图坐标，而不是bounds坐标
        
        // 设置绘制属性
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setMiterLimit(10.0)
        context.setBlendMode(.normal)
        
        // 绘制所有路径
        for path in inkPaths {
            guard !path.isEmpty else { continue }
            
            // 移动到第一个点（使用页面坐标）
            let firstPoint = path[0]
            let pageFirstPoint = CGPoint(
                x: bounds.origin.x + firstPoint.x,
                y: bounds.origin.y + firstPoint.y
            )
            context.move(to: pageFirstPoint)
            
            // 添加后续点（使用页面坐标）
            for point in path.dropFirst() {
                let pagePoint = CGPoint(
                    x: bounds.origin.x + point.x,
                    y: bounds.origin.y + point.y
                )
                context.addLine(to: pagePoint)
            }
        }
        
        // 绘制路径
        context.strokePath()
        
        // 恢复图形上下文状态
        context.restoreGState()
    }
    
    // 设置ink路径
    func setInkPaths(_ paths: [[CGPoint]], color: NSColor, lineWidth: CGFloat) {
        self.inkPaths = paths
        self.strokeColor = color
        self.strokeWidth = lineWidth
        self.color = color // 也设置PDFAnnotation的color属性
    }
}

