//
// PDFDocumentModel.swift
// HyperPaper
//
// PDF文档数据模型
//

import Foundation
import PDFKit

struct PDFDocumentModel: Identifiable {
    let id: UUID
    let url: URL
    let title: String
    let pageCount: Int
    let createdAt: Date
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.lastPathComponent
        self.createdAt = Date()
        
        // 加载PDF获取页数
        if let pdfDocument = PDFDocument(url: url) {
            self.pageCount = pdfDocument.pageCount
        } else {
            self.pageCount = 0
        }
    }
}

struct SelectionRegion: Identifiable {
    let id: UUID
    let pageIndex: Int
    let rect: CGRect
    var text: String?
    
    init(pageIndex: Int, rect: CGRect) {
        self.id = UUID()
        self.pageIndex = pageIndex
        self.rect = rect
        self.text = nil
    }
}

struct MultiPageSelection {
    var regions: [SelectionRegion] = []
    
    var combinedText: String {
        regions.compactMap { $0.text }.joined(separator: "\n\n")
    }
    
    var isMultiPage: Bool {
        let pageIndices = Set(regions.map { $0.pageIndex })
        return pageIndices.count > 1
    }
}

