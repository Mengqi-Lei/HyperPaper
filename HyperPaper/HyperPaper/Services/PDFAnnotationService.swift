//
// PDFAnnotationService.swift
// HyperPaper
//
// PDF注释服务：封装PDFKit的注释API
//

import PDFKit
import AppKit
import SwiftUI

class PDFAnnotationService {
    
    // MARK: - 创建文本标注类注释
    
    /// 创建高亮注释
    static func createHighlight(
        on page: PDFPage,
        selection: PDFSelection,
        color: NSColor = .yellow
    ) -> PDFAnnotation? {
        let bounds = selection.bounds(for: page)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        annotation.color = color
        
        // 设置高亮区域（quadPoints）
        // quadPoints需要是8个点（4个点对，每个点对代表一个矩形的两个角）
        var quadPoints: [NSValue] = []
        let ranges = selection.selectionsByLine()
        for range in ranges {
            let rangeBounds = range.bounds(for: page)
            // 每个矩形需要4个点（按逆时针顺序：左下、右下、右上、左上）
            // PDF坐标系：原点在左下角
            let bottomLeft = CGPoint(x: rangeBounds.minX, y: rangeBounds.minY)
            let bottomRight = CGPoint(x: rangeBounds.maxX, y: rangeBounds.minY)
            let topRight = CGPoint(x: rangeBounds.maxX, y: rangeBounds.maxY)
            let topLeft = CGPoint(x: rangeBounds.minX, y: rangeBounds.maxY)
            
            quadPoints.append(NSValue(point: bottomLeft))
            quadPoints.append(NSValue(point: bottomRight))
            quadPoints.append(NSValue(point: topRight))
            quadPoints.append(NSValue(point: topLeft))
        }
        if !quadPoints.isEmpty {
            annotation.setValue(quadPoints, forAnnotationKey: .quadPoints)
        }
        
        // 确保注释可见
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        
        // 添加到页面
        page.addAnnotation(annotation)
        
        print("PDFAnnotationService: Created highlight annotation")
        print("  - bounds: \(bounds)")
        print("  - quadPoints count: \(quadPoints.count)")
        print("  - color: \(color)")
        print("  - page annotations count: \(page.annotations.count)")
        
        return annotation
    }
    
    /// 创建下划线注释
    static func createUnderline(
        on page: PDFPage,
        selection: PDFSelection,
        color: NSColor = .blue
    ) -> PDFAnnotation? {
        let bounds = selection.bounds(for: page)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
        annotation.color = color
        
        // 设置下划线区域（quadPoints）
        // quadPoints需要是8个点（4个点对，每个点对代表一个矩形的两个角）
        var quadPoints: [NSValue] = []
        let ranges = selection.selectionsByLine()
        for range in ranges {
            let rangeBounds = range.bounds(for: page)
            // 每个矩形需要4个点（按逆时针顺序：左下、右下、右上、左上）
            let bottomLeft = CGPoint(x: rangeBounds.minX, y: rangeBounds.minY)
            let bottomRight = CGPoint(x: rangeBounds.maxX, y: rangeBounds.minY)
            let topRight = CGPoint(x: rangeBounds.maxX, y: rangeBounds.maxY)
            let topLeft = CGPoint(x: rangeBounds.minX, y: rangeBounds.maxY)
            
            quadPoints.append(NSValue(point: bottomLeft))
            quadPoints.append(NSValue(point: bottomRight))
            quadPoints.append(NSValue(point: topRight))
            quadPoints.append(NSValue(point: topLeft))
        }
        if !quadPoints.isEmpty {
            annotation.setValue(quadPoints, forAnnotationKey: .quadPoints)
        }
        
        // 确保注释可见
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        
        // 添加到页面
        page.addAnnotation(annotation)
        
        print("PDFAnnotationService: Created underline annotation")
        print("  - bounds: \(bounds)")
        print("  - quadPoints count: \(quadPoints.count)")
        print("  - color: \(color)")
        
        return annotation
    }
    
    /// 创建删除线注释
    static func createStrikeout(
        on page: PDFPage,
        selection: PDFSelection,
        color: NSColor = .red
    ) -> PDFAnnotation? {
        let bounds = selection.bounds(for: page)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
        annotation.color = color
        
        // 设置删除线区域（quadPoints）
        // quadPoints需要是8个点（4个点对，每个点对代表一个矩形的两个角）
        var quadPoints: [NSValue] = []
        let ranges = selection.selectionsByLine()
        for range in ranges {
            let rangeBounds = range.bounds(for: page)
            // 每个矩形需要4个点（按逆时针顺序：左下、右下、右上、左上）
            let bottomLeft = CGPoint(x: rangeBounds.minX, y: rangeBounds.minY)
            let bottomRight = CGPoint(x: rangeBounds.maxX, y: rangeBounds.minY)
            let topRight = CGPoint(x: rangeBounds.maxX, y: rangeBounds.maxY)
            let topLeft = CGPoint(x: rangeBounds.minX, y: rangeBounds.maxY)
            
            quadPoints.append(NSValue(point: bottomLeft))
            quadPoints.append(NSValue(point: bottomRight))
            quadPoints.append(NSValue(point: topRight))
            quadPoints.append(NSValue(point: topLeft))
        }
        if !quadPoints.isEmpty {
            annotation.setValue(quadPoints, forAnnotationKey: .quadPoints)
        }
        
        // 确保注释可见
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        
        // 添加到页面
        page.addAnnotation(annotation)
        
        print("PDFAnnotationService: Created strikeout annotation")
        print("  - bounds: \(bounds)")
        print("  - quadPoints count: \(quadPoints.count)")
        print("  - color: \(color)")
        
        return annotation
    }
    
    // MARK: - 创建Note注释
    
    /// 创建Note注释（点击位置添加）
    static func createNote(
        on page: PDFPage,
        at point: CGPoint,
        content: String = "",
        color: NSColor = .yellow
    ) -> PDFAnnotation? {
        // Note注释使用小图标区域（12x12，像个小标记）
        let iconSize: CGFloat = 12
        let bounds = CGRect(x: point.x, y: point.y, width: iconSize, height: iconSize)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.color = color
        annotation.contents = content
        
        // 确保注释可见和可编辑
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        // 注意：PDFAnnotation默认是可编辑的，不需要设置isLocked属性
        
        page.addAnnotation(annotation)
        return annotation
    }
    
    // MARK: - 创建文字注释
    
    /// 创建文字注释（自由文本）
    static func createText(
        on page: PDFPage,
        at point: CGPoint,
        text: String,
        fontSize: CGFloat = 10,
        color: NSColor = .black
    ) -> PDFAnnotation? {
        // 估算文本大小
        let font = NSFont.systemFont(ofSize: fontSize)
        
        // 创建段落样式，确保行间距正确
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2.0 // 添加行间距
        paragraphStyle.lineHeightMultiple = 1.0
        paragraphStyle.lineBreakMode = .byWordWrapping // 按单词换行
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        // 确保换行符被正确处理（\n 会被 PDFAnnotation 正确显示为换行）
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // 计算文本大小（考虑多行文本）
        // 使用 NSTextStorage 和 NSLayoutManager 来更准确地计算文本高度
        let maxWidth: CGFloat = 400 // 假设最大宽度
        
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        
        // 确保布局完成
        layoutManager.ensureLayout(for: textContainer)
        
        // 获取实际使用的矩形区域
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        // 计算行高（用于添加 padding）
        let lineHeight = font.ascender - font.descender + font.leading
        
        // 添加足够的 padding 确保文本完全显示
        // 顶部和底部各添加一个行高的 padding，确保第一行和最后一行都完整显示
        let topPadding = lineHeight * 0.4
        let bottomPadding = lineHeight * 0.8 // 增加底部 padding，确保 descender 和最后一行完全显示
        let textHeight = ceil(usedRect.height) + topPadding + bottomPadding
        let textWidth = max(ceil(usedRect.width), 100)
        
        Swift.print("✅ PDFAnnotationService.createText: 使用 NSLayoutManager 计算文本大小")
        Swift.print("  - usedRect: \(usedRect)")
        Swift.print("  - lineHeight: \(lineHeight)")
        Swift.print("  - topPadding: \(topPadding)")
        Swift.print("  - bottomPadding: \(bottomPadding)")
        Swift.print("  - textHeight (最终): \(textHeight)")
        
        let bounds = CGRect(x: point.x, y: point.y - textHeight, width: textWidth, height: textHeight)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        
        // 关键：设置文本内容
        annotation.contents = text
        
        // 设置字体
        annotation.font = font
        
        // 关键：背景色设置为透明（或 nil），只有文字有颜色
        // FreeText 注释的 color 属性控制背景色，fontColor 控制文字颜色
        annotation.color = NSColor.clear // 背景透明
        
        // 关键：设置字体颜色（文字颜色使用用户选择的颜色）
        if annotation.responds(to: Selector(("setFontColor:"))) {
            annotation.perform(Selector(("setFontColor:")), with: color)
        }
        
        // 关键：设置 defaultAppearanceString（PDF 标准属性）
        // FreeText 注释需要 defaultAppearanceString 来显示文本
        // 格式：/Helv 12 Tf 0 0 0 rg（字体名 字号 Tf，RGB 颜色 rg）
        var appearanceString: String? = nil
        let cgColor = color.cgColor
        if let components = cgColor.components,
           components.count >= 3 {
            let red = components[0]
            let green = components[1]
            let blue = components[2]
            
            // 使用标准字体名称（Helvetica 是 PDF 标准字体）
            let fontName = "Helv" // PDF 标准字体名称
            appearanceString = "/\(fontName) \(Int(fontSize)) Tf \(red) \(green) \(blue) rg"
            
            // 尝试设置 defaultAppearanceString
            if annotation.responds(to: Selector(("setDefaultAppearanceString:"))) {
                annotation.perform(Selector(("setDefaultAppearanceString:")), with: appearanceString!)
            } else {
                // 备用方案：使用 setValue
                annotation.setValue(appearanceString!, forAnnotationKey: PDFAnnotationKey(rawValue: "defaultAppearanceString"))
            }
        }
        
        // 确保注释可见和可编辑
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        
        // 关键：设置注释为可编辑状态
        // 确保注释没有被锁定
        if annotation.responds(to: Selector(("setLocked:"))) {
            annotation.perform(Selector(("setLocked:")), with: false)
        }
        
        // 设置文本对齐方式
        if annotation.responds(to: Selector(("setAlignment:"))) {
            annotation.perform(Selector(("setAlignment:")), with: NSTextAlignment.left.rawValue)
        }
        
        // 不设置边框，让文本框完全透明，只有文字可见
        // 如果需要边框，可以取消下面的注释
        // let border = PDFBorder()
        // border.lineWidth = 0.5
        // annotation.border = border
        
        // 添加到页面
        page.addAnnotation(annotation)
        
        // 关键：更新 appearance stream 以确保文本显示
        if annotation.responds(to: Selector(("updateAppearanceStream"))) {
            annotation.perform(Selector(("updateAppearanceStream")))
        }
        
        Swift.print("✅ PDFAnnotationService.createText: 创建了文本注释")
        Swift.print("  - text: \(text)")
        Swift.print("  - bounds: \(bounds)")
        Swift.print("  - font: \(font)")
        Swift.print("  - color: \(color)")
        Swift.print("  - appearanceString: \(appearanceString ?? "nil")")
        
        return annotation
    }
    
    // MARK: - 创建自由画线注释
    
    /// 创建自由画线注释
    static func createFreehand(
        on page: PDFPage,
        points: [[CGPoint]],
        color: NSColor = .black,
        lineWidth: CGFloat = 2.0
    ) -> PDFAnnotation? {
        guard !points.isEmpty else { return nil }
        
        // 计算边界
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = CGFloat.leastNormalMagnitude
        var maxY = CGFloat.leastNormalMagnitude
        
        for path in points {
            for point in path {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
        }
        
        // 确保bounds有有效的大小（添加一些padding以确保路径不会被裁剪）
        let padding: CGFloat = lineWidth
        let width = max(maxX - minX, 1.0) + padding * 2
        let height = max(maxY - minY, 1.0) + padding * 2
        let bounds = CGRect(x: minX - padding, y: minY - padding, width: width, height: height)
        
        // 使用自定义的CustomInkAnnotation类
        let annotation = CustomInkAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        
        // 将点坐标转换为相对于bounds的坐标
        var relativePaths: [[CGPoint]] = []
        for path in points {
            var relativePath: [CGPoint] = []
            for point in path {
                let relativePoint = CGPoint(
                    x: point.x - bounds.origin.x,
                    y: point.y - bounds.origin.y
                )
                relativePath.append(relativePoint)
            }
            relativePaths.append(relativePath)
        }
        
        // 设置ink路径（使用自定义方法）
        annotation.setInkPaths(relativePaths, color: color, lineWidth: lineWidth)
        
        // 也设置PDFKit的标准属性（以防万一）
        var inkList: [[NSValue]] = []
        for path in relativePaths {
            var nsValuePath: [NSValue] = []
            for point in path {
                nsValuePath.append(NSValue(point: point))
            }
            inkList.append(nsValuePath)
        }
        annotation.setValue(inkList, forAnnotationKey: PDFAnnotationKey(rawValue: "inkList"))
        annotation.setValue(lineWidth, forAnnotationKey: PDFAnnotationKey(rawValue: "lineWidth"))
        
        // 设置注释的用户名
        annotation.userName = "HyperPaper"
        
        // 添加到页面
        let annotationCountBefore = page.annotations.count
        page.addAnnotation(annotation)
        let annotationCountAfter = page.annotations.count
        
        // 关键：更新appearance stream以确保注释显示
        // 这会在PDF中生成注释的可视化表示
        if annotationCountAfter > annotationCountBefore {
            // 尝试更新appearance stream
            if annotation.responds(to: Selector(("updateAppearanceStream"))) {
                annotation.perform(Selector(("updateAppearanceStream")))
                print("PDFAnnotationService: Called updateAppearanceStream")
            } else {
                print("PDFAnnotationService: updateAppearanceStream method not available")
            }
        }
        
        // 验证注释是否真的被添加
        if annotationCountAfter <= annotationCountBefore {
            print("PDFAnnotationService: WARNING - Annotation count did not increase!")
        }
        
        return annotation
    }
    
    // MARK: - 辅助方法
    
    /// 将SwiftUI Color转换为NSColor
    static func nsColor(from color: Color) -> NSColor {
        #if os(macOS)
        return NSColor(color)
        #else
        return UIColor(color).nsColor
        #endif
    }
    
    /// 删除注释
    static func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        page.removeAnnotation(annotation)
    }
}

