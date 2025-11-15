//
// PDFImageExtractor.swift
// HyperPaper
//
// PDF图像提取服务 - 从PDF区域提取图像
//

import Foundation
import PDFKit
import AppKit

enum PDFImageExtractionError: Error, LocalizedError {
    case invalidPage
    case invalidRegion
    case contextCreationFailed
    case renderingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPage:
            return "无效的页面索引"
        case .invalidRegion:
            return "无效的选择区域"
        case .contextCreationFailed:
            return "无法创建图像上下文"
        case .renderingFailed:
            return "PDF渲染失败"
        }
    }
}

class PDFImageExtractor {
    /// 从PDF区域提取图像（使用PDFView的坐标转换逻辑）
    /// - Parameters:
    ///   - document: PDF文档
    ///   - region: 选择区域（PDF坐标系，左下角为原点）
    ///   - pdfView: PDFView实例（用于坐标转换验证）
    ///   - scale: 缩放比例（默认2.0，提高识别质量）
    /// - Returns: 提取的图像（NSImage）
    static func extractImage(
        from document: PDFDocument,
        region: SelectionRegion,
        pdfView: PDFView? = nil,
        scale: CGFloat = 2.0
    ) throws -> NSImage {
        guard region.pageIndex >= 0 && region.pageIndex < document.pageCount else {
            throw PDFImageExtractionError.invalidPage
        }
        
        guard let page = document.page(at: region.pageIndex) else {
            throw PDFImageExtractionError.invalidPage
        }
        
        guard region.rect.width > 0 && region.rect.height > 0 else {
            throw PDFImageExtractionError.invalidRegion
        }
        
        // 限制最大图像尺寸（避免内存问题）
        let maxSize: CGFloat = 4096
        let adjustedScale = min(scale, maxSize / max(region.rect.width, region.rect.height))
        
        // 计算图像尺寸
        let imageSize = CGSize(
            width: region.rect.width * adjustedScale,
            height: region.rect.height * adjustedScale
        )
        
        // 确保最小尺寸满足Vision API要求（>10像素）
        guard imageSize.width > 10 && imageSize.height > 10 else {
            throw PDFImageExtractionError.invalidRegion
        }
        
        // 获取PDF页面的边界框
        let pageBounds = page.bounds(for: .mediaBox)
        let pageHeight = pageBounds.height
        
        // ============================================
        // 新的坐标转换逻辑（基于蓝色矩形框的逻辑）
        // ============================================
        // 
        // 蓝色矩形框的工作原理：
        // 1. 使用 pdfView.convert(region.rect, from: page) 将PDF坐标转换为视图坐标
        // 2. PDFView自动处理坐标系转换（左下角→左上角）
        // 3. 直接使用视图坐标显示
        //
        // 图像提取的逻辑应该类似：
        // 1. 我们需要在图像坐标系（左上角原点）中绘制
        // 2. PDF的draw方法期望PDF坐标系（左下角原点）
        // 3. 我们需要将PDF坐标系转换为图像坐标系
        //
        // 关键理解：
        // - PDF坐标系：左下角(0,0)，Y向上
        // - 图像坐标系：左上角(0,0)，Y向下
        // - 转换关系：图像Y = pageHeight - PDF_Y - height
        //
        // 但是，PDF的draw方法会绘制整个页面，我们需要：
        // 1. 设置正确的变换矩阵，使得PDF的(region.rect.origin.x, region.rect.origin.y)映射到图像的(0, 0)
        // 2. 裁剪到区域大小
        
        // ============================================
        // 方案：先绘制整个页面到临时图像，然后裁剪
        // ============================================
        // 1. 创建临时图像（整个页面大小）
        // 2. 绘制整个PDF页面到临时图像
        // 3. 从临时图像中裁剪出目标区域
        
        // 1. 创建临时图像（整个页面大小）
        let tempImageSize = CGSize(
            width: pageBounds.width * adjustedScale,
            height: pageBounds.height * adjustedScale
        )
        
        // 创建临时图像表示
        guard let tempImageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(tempImageSize.width),
            pixelsHigh: Int(tempImageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw PDFImageExtractionError.contextCreationFailed
        }
        
        // 创建临时图形上下文
        guard let tempContext = NSGraphicsContext(bitmapImageRep: tempImageRep) else {
            throw PDFImageExtractionError.contextCreationFailed
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = tempContext
        
        let tempCGContext = tempContext.cgContext
        
        // 2. 绘制整个PDF页面到临时图像
        // 坐标转换：图像坐标系 → PDF坐标系
        tempCGContext.translateBy(x: 0, y: tempImageSize.height)
        tempCGContext.scaleBy(x: adjustedScale, y: -adjustedScale)
        // 现在上下文是PDF坐标系，原点在PDF的(0, 0)
        
        page.draw(with: .mediaBox, to: tempCGContext)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // 创建临时NSImage
        let tempImage = NSImage(size: tempImageSize)
        tempImage.addRepresentation(tempImageRep)
        
        // 3. 从临时图像中裁剪出目标区域
        // 计算裁剪区域在临时图像中的位置（图像坐标系，左上角原点）
        let cropRect = CGRect(
            x: region.rect.origin.x * adjustedScale,
            y: (pageHeight - region.rect.origin.y - region.rect.height) * adjustedScale,
            width: region.rect.width * adjustedScale,
            height: region.rect.height * adjustedScale
        )
        
        // 创建最终图像
        let finalImage = NSImage(size: imageSize)
        finalImage.lockFocus()
        
        // 从临时图像中绘制裁剪区域
        tempImage.draw(
            at: .zero,
            from: cropRect,
            operation: .copy,
            fraction: 1.0
        )
        
        finalImage.unlockFocus()
        
        // 4. 翻转图像并添加白色背景（因为PDF坐标系和图像坐标系的Y轴方向相反）
        // 创建翻转后的图像（带白色背景）
        let flippedImage = NSImage(size: imageSize)
        flippedImage.lockFocus()
        
        // 先填充白色背景
        NSColor.white.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        
        // 应用翻转变换
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: imageSize.height)
        transform.scaleX(by: 1.0, yBy: -1.0)
        transform.concat()
        
        // 绘制原始图像（在白色背景上）
        finalImage.draw(
            at: .zero,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        
        flippedImage.unlockFocus()
        
        // 创建NSImage（使用翻转后的图像）
        let image = flippedImage
        
        return image
    }
    
    /// 从多个区域提取图像（跨页选择）
    /// - Parameters:
    ///   - document: PDF文档
    ///   - regions: 选择区域数组
    ///   - scale: 缩放比例
    /// - Returns: 合并后的图像数组（按顺序）
    static func extractImages(
        from document: PDFDocument,
        regions: [SelectionRegion],
        scale: CGFloat = 2.0
    ) throws -> [NSImage] {
        var images: [NSImage] = []
        for region in regions {
            let image = try extractImage(from: document, region: region, scale: scale)
            images.append(image)
        }
        return images
    }
    
    /// 将NSImage转换为Base64编码字符串
    /// - Parameter image: 待转换的图像
    /// - Returns: Base64编码字符串（格式：data:image/png;base64,...）
    static func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let base64String = pngData.base64EncodedString()
        return "data:image/png;base64,\(base64String)"
    }
    
    /// 保存图像到本地文件（用于调试）
    /// - Parameters:
    ///   - image: 待保存的图像
    ///   - filename: 文件名（可选，默认使用时间戳）
    /// - Returns: 保存的文件路径
    static func saveImageToFile(_ image: NSImage, filename: String? = nil) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("❌ 无法将图像转换为PNG数据")
            return nil
        }
        
        // 创建保存目录（在用户桌面）
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let saveDir = desktopURL.appendingPathComponent("HyperPaper_ExtractedImages", isDirectory: true)
        
        // 创建目录（如果不存在）
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        
        // 生成文件名
        let fileName = filename ?? "extracted_\(Date().timeIntervalSince1970).png"
        let fileURL = saveDir.appendingPathComponent(fileName)
        
        // 保存文件
        do {
            try pngData.write(to: fileURL)
            print("✅ 图像已保存到: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ 保存图像失败: \(error.localizedDescription)")
            return nil
        }
    }
    
}
