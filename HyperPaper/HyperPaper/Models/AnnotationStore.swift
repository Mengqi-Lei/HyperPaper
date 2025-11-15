//
// AnnotationStore.swift
// HyperPaper
//
// 注释存储和管理类
//

import Foundation
import SwiftUI
import PDFKit
import Combine

class AnnotationStore: ObservableObject {
    // MARK: - 发布属性
    @Published var annotations: [Annotation] = []
    
    // MARK: - 私有属性
    private let storageKey = "HyperPaper.Annotations"
    private(set) var documentURL: URL? // 改为 private(set)，允许外部读取
    
    // MARK: - 初始化
    init(documentURL: URL? = nil) {
        self.documentURL = documentURL
        loadAnnotations()
    }
    
    // MARK: - 公共方法
    
    /// 添加注释
    func add(_ annotation: Annotation) {
        annotations.append(annotation)
        saveAnnotations()
    }
    
    /// 删除注释
    func remove(_ annotation: Annotation) {
        annotations.removeAll { $0.id == annotation.id }
        saveAnnotations()
    }
    
    /// 更新注释
    func update(_ annotation: Annotation) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            // 如果内容没有变化，跳过更新（避免不必要的保存和视图重绘）
            if annotations[index].content == annotation.content &&
               annotations[index].color == annotation.color {
                return
            }
            annotations[index] = annotation
            // 异步保存，避免阻塞主线程
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.saveAnnotations()
            }
        }
    }
    
    /// 获取指定页面的注释
    func annotations(for pageIndex: Int) -> [Annotation] {
        return annotations.filter { $0.pageIndex == pageIndex }
    }
    
    /// 获取指定类型的注释
    func annotations(ofType type: AnnotationType) -> [Annotation] {
        return annotations.filter { $0.type == type }
    }
    
    /// 根据ID获取注释
    func annotation(withId id: UUID) -> Annotation? {
        return annotations.first { $0.id == id }
    }
    
    /// 清除所有注释
    func clearAll() {
        annotations.removeAll()
        saveAnnotations()
    }
    
    /// 清除指定页面的注释
    func clearAnnotations(for pageIndex: Int) {
        annotations.removeAll { $0.pageIndex == pageIndex }
        saveAnnotations()
    }
    
    /// 设置文档URL（用于持久化）
    func setDocumentURL(_ url: URL?) {
        self.documentURL = url
        loadAnnotations()
    }
    
    /// 仅设置文档URL，不加载注释（用于从PDF加载时避免重复）
    func setDocumentURLOnly(_ url: URL?) {
        self.documentURL = url
    }
    
    /// 获取排序后的注释列表（按页面索引和坐标位置排序）
    var sortedAnnotations: [Annotation] {
        annotations.sorted { a1, a2 in
            // 首先按页面索引排序
            if a1.pageIndex != a2.pageIndex {
                return a1.pageIndex < a2.pageIndex
            }
            // 同一页面，按 Y 坐标排序（从下到上，PDF 坐标系：Y 越大越靠上）
            let yDiff = abs(a1.rect.origin.y - a2.rect.origin.y)
            if yDiff > 1.0 {
                return a1.rect.origin.y > a2.rect.origin.y  // Y 越大越靠上，所以排在前面
            }
            // 同一 Y 坐标（或非常接近），按 X 坐标排序（从左到右）
            return a1.rect.origin.x < a2.rect.origin.x
        }
    }
    
    // MARK: - 私有方法
    
    /// 保存注释到 UserDefaults
    private func saveAnnotations() {
        // 使用文档URL作为key的一部分，实现按文档存储
        let key = storageKeyForDocument()
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(annotations)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("保存注释失败: \(error)")
        }
    }
    
    /// 从 UserDefaults 加载注释
    private func loadAnnotations() {
        let key = storageKeyForDocument()
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            annotations = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            annotations = try decoder.decode([Annotation].self, from: data)
        } catch {
            print("加载注释失败: \(error)")
            annotations = []
        }
    }
    
    /// 获取文档特定的存储key
    private func storageKeyForDocument() -> String {
        if let url = documentURL {
            // 使用文档路径的hash作为key的一部分
            let pathHash = url.path.hash
            return "\(storageKey).\(pathHash)"
        }
        return storageKey
    }
}

