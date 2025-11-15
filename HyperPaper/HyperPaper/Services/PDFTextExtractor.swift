//
// PDFTextExtractor.swift
// HyperPaper
//
// PDF文本提取服务
//

import Foundation
import PDFKit

class PDFTextExtractor {
    /// 从PDF文档的指定区域提取文本
    /// - Parameters:
    ///   - document: PDF文档
    ///   - pageIndex: 页面索引（从0开始）
    ///   - rect: 选择区域（PDF坐标系）
    /// - Returns: 提取的文本
    static func extractText(from document: PDFDocument, 
                           pageIndex: Int, 
                           rect: CGRect) -> String? {
        guard pageIndex >= 0 && pageIndex < document.pageCount else {
            return nil
        }
        
        guard let page = document.page(at: pageIndex) else {
            return nil
        }
        
        // 获取页面范围内的文本
        guard let selection = page.selection(for: rect) else {
            return nil
        }
        
        return selection.string
    }
    
    /// 从多个选择区域提取文本
    /// - Parameters:
    ///   - document: PDF文档
    ///   - regions: 选择区域数组
    /// - Returns: 合并后的文本
    static func extractText(from document: PDFDocument, 
                           regions: [SelectionRegion]) -> String {
        var texts: [String] = []
        
        for region in regions {
            if let text = extractText(from: document, 
                                     pageIndex: region.pageIndex, 
                                     rect: region.rect),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                texts.append(text)
            }
        }
        
        return texts.joined(separator: "\n\n")
    }
    
    /// 从多页选择中提取文本
    /// - Parameters:
    ///   - document: PDF文档
    ///   - selection: 多页选择对象
    /// - Returns: 合并后的文本
    static func extractText(from document: PDFDocument, 
                           selection: MultiPageSelection) -> String {
        return extractText(from: document, regions: selection.regions)
    }
}

