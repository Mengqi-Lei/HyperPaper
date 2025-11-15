//
// AnnotationModeView.swift
// HyperPaper
//
// 批注模式视图：显示和管理PDF批注
//

import SwiftUI
import PDFKit

struct AnnotationModeView: View {
    @StateObject private var annotationStore = AnnotationStore()
    @Binding var pdfDocument: PDFDocument?
    @Binding var selectedNoteAnnotation: PDFAnnotation? // 当前选中的note注释
    @Binding var selectedAnnotationId: UUID? // 当前选中的注释ID（用于高亮显示）
    var onNoteTap: ((Annotation) -> Void)? = nil // Note点击回调（用于跳转到PDF区域）
    var onAnnotationDelete: ((Annotation) -> Void)? = nil // 注释删除回调
    
    // 注意：不能直接存储ScrollViewReader.Proxy类型，需要在闭包内使用
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // 顶部 padding，确保内容不被上方的 bar 遮挡
                Spacer()
                    .frame(height: 0)
                    .id("top-spacer")
                VStack(spacing: 20) {
                    if annotationStore.annotations.isEmpty {
                        // 空状态
                        VStack(spacing: 16) {
                            Image(systemName: "note.text")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("还没有批注")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Text("在PDF上使用注释工具创建批注")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .id("empty-state")
                    } else {
                        // 批注列表（使用排序后的列表）
                        VStack(alignment: .leading, spacing: 12) {
                            // 使用排序后的注释列表，按照在 PDF 中的位置排序
                            ForEach(annotationStore.sortedAnnotations) { annotation in
                                annotationRow(for: annotation) { id in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(8)
            }
            .onChange(of: selectedAnnotationId) { oldValue, newValue in
                // 当selectedAnnotationId变化时，滚动到对应的注释位置
                // 优化响应速度：减少延迟时间，使用更快的动画
                if let annotationId = newValue, oldValue != newValue {
                    // 立即尝试（视图可能已经渲染）
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(annotationId, anchor: .center)
                    }
                    // 快速延迟尝试（确保视图已渲染，但更快）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(annotationId, anchor: .center)
                        }
                    }
                    // 备用延迟尝试（处理延迟渲染的情况，但时间更短）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(annotationId, anchor: .center)
                        }
                    }
                }
            }
            .onAppear {
            // 设置文档URL用于加载批注
            if let document = pdfDocument,
               let url = document.documentURL {
                // 只设置URL，不从UserDefaults加载（避免重复）
                annotationStore.setDocumentURLOnly(url)
            }
            // 从PDF文档加载注释
            if let document = pdfDocument {
                loadPDFAnnotations(from: document)
            }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PDFScrollDetected"))) { notification in
            // 处理PDF滚动通知：匹配PDFAnnotation到Annotation ID
            guard let userInfo = notification.userInfo,
                  let pageIndex = userInfo["pageIndex"] as? Int,
                  let boundsX = userInfo["boundsX"] as? CGFloat,
                  let boundsY = userInfo["boundsY"] as? CGFloat else {
                return
            }
            
            // 在annotationStore中查找匹配的Annotation（支持所有注释类型）
            let matchingAnnotation = annotationStore.sortedAnnotations.first { annotation in
                annotation.pageIndex == pageIndex &&
                abs(annotation.rect.origin.x - boundsX) < 1.0 &&
                abs(annotation.rect.origin.y - boundsY) < 1.0
            }
            
            if let matched = matchingAnnotation {
                // 找到匹配的注释，高亮显示（但不触发滚动，因为这是PDF滚动触发的）
                selectedAnnotationId = matched.id
            } else {
                // 没有找到匹配的注释，清除高亮
                selectedAnnotationId = nil
            }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PDFAnnotationCreated"))) { notification in
            // 当新注释创建时，立即同步单个注释（支持所有注释类型）
            if let pdfAnnotation = notification.userInfo?["pdfAnnotation"] as? PDFAnnotation {
                // 优先使用通知中传递的颜色（创建时用户选择的颜色）
                let providedColor = notification.userInfo?["annotationColor"] as? AnnotationColor
                print("📝 AnnotationModeView: 收到新注释创建通知，开始同步，提供的颜色=\(providedColor?.rawValue ?? "nil")")
                syncPDFAnnotationToStore(pdfAnnotation: pdfAnnotation, providedColor: providedColor) { annotationId in
                    print("📝 AnnotationModeView: 新注释同步完成，ID=\(annotationId)")
                }
            }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PDFAnnotationUpdated"))) { _ in
            // 当PDF注释更新时，重新加载注释列表
            if let document = pdfDocument {
                loadPDFAnnotations(from: document)
            }
            }
            .onChange(of: pdfDocument) { oldValue, newValue in
            // 文档切换时，更新批注存储
            if let document = newValue,
               let url = document.documentURL {
                // 只设置URL，不从UserDefaults加载（避免重复）
                annotationStore.setDocumentURLOnly(url)
                loadPDFAnnotations(from: document)
            }
            }
            .onChange(of: selectedNoteAnnotation) { oldValue, newValue in
            // 当选中note注释时，同步到annotationStore并高亮
            // 注意：只在用户主动点击注释时才同步，避免在加载时重复添加
            if let pdfAnnotation = newValue, oldValue != newValue {
                print("📝 AnnotationModeView: selectedNoteAnnotation变化，开始同步")
                syncPDFAnnotationToStore(pdfAnnotation: pdfAnnotation) { noteId in
                    print("📝 AnnotationModeView: 同步完成，noteId=\(noteId)")
                    // 设置选中的注释ID，用于高亮显示
                    selectedAnnotationId = noteId
                }
            } else if newValue == nil {
                // 如果selectedNoteAnnotation被清空，也清空selectedAnnotationId
                selectedAnnotationId = nil
            }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 创建注释行视图（简化类型检查）
    @ViewBuilder
    private func annotationRow(for annotation: Annotation, scrollTo: @escaping (UUID) -> Void) -> some View {
        AnnotationRow(
            annotation: annotation,
            isSelected: selectedAnnotationId == annotation.id,
            isEditing: isNoteEditing(annotation),
            onContentChanged: { newContent in
                updateNoteContent(annotation: annotation, content: newContent)
            },
            onTap: {
                selectedAnnotationId = annotation.id
                onNoteTap?(annotation)
            },
            onDelete: {
                deleteAnnotation(annotation)
            }
        )
        .id(annotation.id)
        .onAppear {
            if selectedAnnotationId == annotation.id {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollTo(annotation.id)
                }
            }
        }
    }
    
    /// 从PDF文档加载所有注释到annotationStore（支持所有注释类型）
    private func loadPDFAnnotations(from document: PDFDocument) {
        print("📝 loadPDFAnnotations: 开始加载PDF注释，当前store中有 \(annotationStore.annotations.count) 个注释")
        
        // 先清除当前文档的所有注释，避免重复（PDF是唯一真实来源）
        if let url = document.documentURL {
            // 如果文档URL变化了，清除所有注释
            if annotationStore.documentURL != url {
                print("📝 loadPDFAnnotations: 文档URL变化，清除所有注释")
                annotationStore.clearAll()
            }
            // 只设置文档URL，不从UserDefaults加载（避免重复）
            // PDF是唯一真实来源，应该只从PDF加载注释
            annotationStore.setDocumentURLOnly(url)
        }
        
        var pdfAnnotations: [PDFAnnotation] = []
        
        // 遍历所有页面，提取所有注释（note、高亮、下划线、删除线）
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                for annotation in page.annotations {
                    let normalizedType = (annotation.type ?? "").hasPrefix("/") ? String((annotation.type ?? "").dropFirst()) : (annotation.type ?? "")
                    
                    // 检查是否是支持的注释类型
                    if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue ||
                       normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue ||
                       normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue ||
                       normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
                        pdfAnnotations.append(annotation)
                    }
                }
            }
        }
        
        print("📝 loadPDFAnnotations: 从PDF中找到 \(pdfAnnotations.count) 个注释")
        
        // 将PDF注释转换为Annotation并添加到store
        var addedCount = 0
        for pdfAnnotation in pdfAnnotations {
            if let page = pdfAnnotation.page {
                let pageIndex = document.index(for: page)
                let bounds = pdfAnnotation.bounds
                let content = pdfAnnotation.contents ?? ""
                let normalizedType = (pdfAnnotation.type ?? "").hasPrefix("/") ? String((pdfAnnotation.type ?? "").dropFirst()) : (pdfAnnotation.type ?? "")
                
                // 将PDF注释类型转换为AnnotationType
                let annotationType: AnnotationType
                if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue {
                    annotationType = .textNote
                } else if normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue {
                    annotationType = .highlight
                } else if normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue {
                    annotationType = .underline
                } else if normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
                    annotationType = .strikeout
                } else {
                    continue // 跳过不支持的类型
                }
                
                // 对于文本注释（高亮、下划线、删除线），区分选中的文本和批注内容
                var annotationContent: String? = nil // 批注内容（可编辑）
                var sourceText: String? = nil // 选中的文本（只读）
                
                if annotationType != .textNote {
                    // 尝试从注释的选中文本中提取源文本
                    if let selection = page.selection(for: bounds) {
                        sourceText = selection.string ?? ""
                    }
                    // PDF 注释的 contents 作为批注内容（如果存在）
                    if !content.isEmpty {
                        annotationContent = content
                    }
                } else {
                    // Note 注释：content 就是批注内容
                    annotationContent = content.isEmpty ? nil : content
                }
                
                // 检查是否已存在（使用更严格的匹配，包括类型、页面、位置）
                let existingAnnotation = annotationStore.annotations.first { annotation in
                    annotation.type == annotationType &&
                    annotation.pageIndex == pageIndex &&
                    abs(annotation.rect.origin.x - bounds.origin.x) < 0.5 &&
                    abs(annotation.rect.origin.y - bounds.origin.y) < 0.5
                }
                
                // 获取PDF注释的颜色
                let detectedColor = annotationColor(from: pdfAnnotation.color)
                
                if let existing = existingAnnotation {
                    // 即使注释已存在，也要检查并更新颜色（如果不同）
                    if existing.color != detectedColor {
                        // 更新颜色
                        let colorUpdated = Annotation(
                            id: existing.id,
                            type: existing.type,
                            pageIndex: existing.pageIndex,
                            rect: existing.rect,
                            color: detectedColor, // 使用检测到的颜色
                            content: existing.content,
                            createdAt: existing.createdAt,
                            updatedAt: Date(),
                            sourceText: existing.sourceText,
                            translation: existing.translation,
                            qaResult: existing.qaResult,
                            startPoint: existing.startPoint,
                            endPoint: existing.endPoint,
                            path: existing.path
                        )
                        annotationStore.update(colorUpdated)
                        print("📝 loadPDFAnnotations: 更新已存在注释的颜色，从 \(existing.color) 到 \(detectedColor), 类型=\(annotationType), pageIndex=\(pageIndex)")
                    } else {
                        print("📝 loadPDFAnnotations: 跳过已存在的注释，类型=\(annotationType), pageIndex=\(pageIndex), bounds=\(bounds), 颜色=\(existing.color)")
                    }
                } else {
                    let annotation = Annotation(
                        type: annotationType,
                        pageIndex: pageIndex,
                        rect: bounds,
                        color: detectedColor, // 使用检测到的颜色
                        content: annotationContent,
                        createdAt: Date(),
                        updatedAt: Date(),
                        sourceText: sourceText
                    )
                    annotationStore.add(annotation)
                    addedCount += 1
                    print("📝 loadPDFAnnotations: 添加新注释，类型=\(annotationType), pageIndex=\(pageIndex), bounds=\(bounds), 颜色=\(detectedColor)")
                }
            }
        }
        
        print("📝 loadPDFAnnotations: 加载完成，添加了 \(addedCount) 个新注释，store中现在有 \(annotationStore.annotations.count) 个注释")
    }
    
    /// 同步PDF注释到annotationStore（支持所有注释类型）
    /// - Parameters:
    ///   - pdfAnnotation: PDF注释对象
    ///   - providedColor: 可选的颜色（如果提供，优先使用，避免从PDF注释推断）
    ///   - onComplete: 完成回调
    private func syncPDFAnnotationToStore(pdfAnnotation: PDFAnnotation, providedColor: AnnotationColor? = nil, onComplete: @escaping (UUID) -> Void) {
        guard let document = pdfDocument,
              let page = pdfAnnotation.page else { 
            print("❌ syncPDFAnnotationToStore: document or page is nil")
            return 
        }
        
        let pageIndex = document.index(for: page)
        let bounds = pdfAnnotation.bounds
        let content = pdfAnnotation.contents ?? ""
        let normalizedType = (pdfAnnotation.type ?? "").hasPrefix("/") ? String((pdfAnnotation.type ?? "").dropFirst()) : (pdfAnnotation.type ?? "")
        
        // 将PDF注释类型转换为AnnotationType
        let annotationType: AnnotationType
        if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue {
            annotationType = .textNote
        } else if normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue {
            annotationType = .highlight
        } else if normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue {
            annotationType = .underline
        } else if normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
            annotationType = .strikeout
        } else {
            print("❌ syncPDFAnnotationToStore: 不支持的注释类型: \(normalizedType)")
            return
        }
        
        // 对于文本注释（高亮、下划线、删除线），区分选中的文本和批注内容
        var annotationContent: String? = nil // 批注内容（可编辑）
        var sourceText: String? = nil // 选中的文本（只读）
        
        if annotationType != .textNote {
            // 尝试从注释的选中文本中提取源文本
            if let selection = page.selection(for: bounds) {
                sourceText = selection.string ?? ""
            }
            // PDF 注释的 contents 作为批注内容（如果存在）
            if !content.isEmpty {
                annotationContent = content
            }
        } else {
            // Note 注释：content 就是批注内容
            annotationContent = content.isEmpty ? nil : content
        }
        
        print("📝 syncPDFAnnotationToStore: pageIndex=\(pageIndex), bounds=\(bounds), type=\(annotationType), content=\(annotationContent?.isEmpty ?? true ? "empty" : "\(annotationContent!.count) chars"), sourceText=\(sourceText?.isEmpty ?? true ? "empty" : "\(sourceText!.count) chars")")
        
        // 检查是否已存在对应的Annotation
        let existingAnnotation = annotationStore.annotations.first { annotation in
            annotation.type == annotationType &&
            annotation.pageIndex == pageIndex &&
            abs(annotation.rect.origin.x - bounds.origin.x) < 1.0 &&
            abs(annotation.rect.origin.y - bounds.origin.y) < 1.0
        }
        
        // 优先使用提供的颜色，如果没有提供，才从PDF注释推断（用于加载已存在的PDF）
        let finalColor: AnnotationColor
        if let providedColor = providedColor {
            finalColor = providedColor
            print("📝 syncPDFAnnotationToStore: 使用提供的颜色=\(providedColor)")
        } else {
            finalColor = annotationColor(from: pdfAnnotation.color)
            print("📝 syncPDFAnnotationToStore: 从PDF注释推断颜色=\(finalColor), PDF注释颜色=\(pdfAnnotation.color.description)")
        }
        
        if let existing = existingAnnotation {
            print("✅ syncPDFAnnotationToStore: 找到现有注释，ID=\(existing.id), 当前颜色=\(existing.color), 新颜色=\(finalColor)")
            // 更新现有注释（包括内容和颜色）
            let updated = existing.updatingContent(annotationContent ?? "")
            // 如果颜色不同或 sourceText 不同，需要更新（创建新实例）
            if updated.color != finalColor || updated.sourceText != sourceText {
                let colorUpdated = Annotation(
                    id: updated.id,
                    type: updated.type,
                    pageIndex: updated.pageIndex,
                    rect: updated.rect,
                    color: finalColor, // 使用最终确定的颜色
                    content: updated.content,
                    createdAt: updated.createdAt,
                    updatedAt: Date(),
                    sourceText: sourceText ?? updated.sourceText, // 更新 sourceText
                    translation: updated.translation,
                    qaResult: updated.qaResult,
                    startPoint: updated.startPoint,
                    endPoint: updated.endPoint,
                    path: updated.path
                )
                annotationStore.update(colorUpdated)
                print("📝 syncPDFAnnotationToStore: 注释颜色已更新，从 \(updated.color) 到 \(finalColor)")
            } else {
                annotationStore.update(updated)
            }
            print("📝 syncPDFAnnotationToStore: 注释已更新，准备调用onComplete回调")
            // 在主线程上调用完成回调
            DispatchQueue.main.async {
                print("📝 syncPDFAnnotationToStore: 在主线程上调用onComplete，ID=\(existing.id)")
                onComplete(existing.id)
            }
        } else {
            // 创建新注释
            let annotation = Annotation(
                type: annotationType,
                pageIndex: pageIndex,
                rect: bounds,
                color: finalColor, // 使用最终确定的颜色
                content: annotationContent,
                createdAt: Date(),
                updatedAt: Date(),
                sourceText: sourceText
            )
            print("✅ syncPDFAnnotationToStore: 创建新注释，ID=\(annotation.id), 颜色=\(finalColor)")
            annotationStore.add(annotation)
            // 在主线程上调用完成回调
            DispatchQueue.main.async {
                onComplete(annotation.id)
            }
        }
    }
    
    /// 检查note是否被选中
    private func isNoteSelected(_ annotation: Annotation) -> Bool {
        guard let pdfAnnotation = selectedNoteAnnotation,
              let document = pdfDocument,
              let page = pdfAnnotation.page else { return false }
        
        let pageIndex = document.index(for: page)
        let bounds = pdfAnnotation.bounds
        
        return annotation.type == .textNote &&
               annotation.pageIndex == pageIndex &&
               abs(annotation.rect.origin.x - bounds.origin.x) < 1.0 &&
               abs(annotation.rect.origin.y - bounds.origin.y) < 1.0
    }
    
    /// 检查note是否正在编辑
    private func isNoteEditing(_ annotation: Annotation) -> Bool {
        // 如果selectedAnnotationId匹配，且内容为空或刚创建，则进入编辑状态
        return selectedAnnotationId == annotation.id && (annotation.content?.isEmpty ?? true)
    }
    
    /// 更新note内容（也支持文本注释的批注内容）
    private func updateNoteContent(annotation: Annotation, content: String) {
        // 如果内容没有变化，跳过更新（避免不必要的重绘）
        if annotation.content == content {
            return
        }
        
        // 先同步到PDF注释
        guard let document = pdfDocument,
              let page = document.page(at: annotation.pageIndex) else {
            return
        }
        
        // 查找匹配的PDF注释并更新（同步执行）
        let matchingPDFAnnotation = page.annotations.first { pdfAnnotation in
            let normalizedType = (pdfAnnotation.type ?? "").hasPrefix("/") ? String((pdfAnnotation.type ?? "").dropFirst()) : (pdfAnnotation.type ?? "")
            let pdfAnnotationType: AnnotationType?
            
            if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue {
                pdfAnnotationType = .textNote
            } else if normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue {
                pdfAnnotationType = .highlight
            } else if normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue {
                pdfAnnotationType = .underline
            } else if normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
                pdfAnnotationType = .strikeout
            } else {
                pdfAnnotationType = nil
            }
            
            return pdfAnnotationType == annotation.type &&
                   abs(pdfAnnotation.bounds.origin.x - annotation.rect.origin.x) < 1.0 &&
                   abs(pdfAnnotation.bounds.origin.y - annotation.rect.origin.y) < 1.0
        }
        
        if let pdfAnnotation = matchingPDFAnnotation {
            // 更新PDF注释的contents（批注内容）
            pdfAnnotation.contents = content.isEmpty ? nil : content
        }
        
        // 立即更新 annotationStore（因为只在点击保存时才调用，不需要延迟）
        if let currentAnnotation = self.annotationStore.annotation(withId: annotation.id),
           currentAnnotation.content != content {
            let updated = currentAnnotation.updatingContent(content)
            self.annotationStore.update(updated)
        } else if self.annotationStore.annotation(withId: annotation.id) == nil {
            // 如果找不到，使用传入的 annotation
            let updated = annotation.updatingContent(content)
            self.annotationStore.update(updated)
        }
        
        // 触发保存通知
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("PDFAnnotationUpdated"), object: nil)
        }
    }
    
    /// 删除注释（从PDF和AnnotationStore中删除）
    private func deleteAnnotation(_ annotation: Annotation) {
        // 从AnnotationStore中删除
        annotationStore.remove(annotation)
        
        // 从PDF中删除对应的注释
        guard let document = pdfDocument,
              let page = document.page(at: annotation.pageIndex) else {
            return
        }
        
        // 查找匹配的PDF注释
        let matchingPDFAnnotation = page.annotations.first { pdfAnnotation in
            let normalizedType = (pdfAnnotation.type ?? "").hasPrefix("/") ? String((pdfAnnotation.type ?? "").dropFirst()) : (pdfAnnotation.type ?? "")
            let pdfAnnotationType: AnnotationType?
            
            if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue {
                pdfAnnotationType = .textNote
            } else if normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue {
                pdfAnnotationType = .highlight
            } else if normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue {
                pdfAnnotationType = .underline
            } else if normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
                pdfAnnotationType = .strikeout
            } else {
                pdfAnnotationType = nil
            }
            
            return pdfAnnotationType == annotation.type &&
                   abs(pdfAnnotation.bounds.origin.x - annotation.rect.origin.x) < 1.0 &&
                   abs(pdfAnnotation.bounds.origin.y - annotation.rect.origin.y) < 1.0
        }
        
        if let pdfAnnotation = matchingPDFAnnotation {
            page.removeAnnotation(pdfAnnotation)
            // 触发保存
            NotificationCenter.default.post(name: NSNotification.Name("PDFAnnotationUpdated"), object: nil)
        }
        
        // 如果删除的是当前选中的注释，清除选中状态
        if selectedAnnotationId == annotation.id {
            selectedAnnotationId = nil
        }
        
        // 调用删除回调
        onAnnotationDelete?(annotation)
    }
    
    /// 从NSColor转换为AnnotationColor（改进的颜色匹配逻辑）
    /// 使用 CGColor 来避免 NSColor.getRed 的类型推断问题
    private func annotationColor(from nsColor: NSColor?) -> AnnotationColor {
        guard let color = nsColor else { return .yellow }
        
        // 使用 CGColor 来获取 RGB 分量（更可靠，避免类型推断问题）
        let cgColor = color.cgColor
        
        // 转换为RGB颜色空间
        guard let rgbColor = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let components = rgbColor.components, components.count >= 3 else {
            // 如果无法转换为RGB，返回默认黄色
            return .yellow
        }
        
        // 获取RGB分量
        let r = components[0]
        let g = components.count >= 2 ? components[1] : 0
        let b = components.count >= 3 ? components[2] : 0
        
        // 改进的颜色匹配逻辑（使用更精确的阈值和优先级）
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

// MARK: - 批注行视图
struct AnnotationRow: View {
    let annotation: Annotation
    let isSelected: Bool // 是否被选中
    let isEditing: Bool // 是否正在编辑
    let onContentChanged: (String) -> Void // 内容改变回调
    var onTap: (() -> Void)? = nil // 点击回调（用于跳转到PDF区域）
    var onDelete: (() -> Void)? = nil // 删除回调
    
    @State private var isExpanded: Bool = true // 默认展开
    @State private var editingContent: String = ""
    @State private var localEditingState: Bool = false // 本地编辑状态（用于管理编辑/确认按钮）
    
    // 计算注释标题（区分便签注释和文本注释）
    private var annotationTitle: String {
        switch annotation.type {
        case .textNote:
            return "便签注释"
        case .highlight, .underline, .strikeout:
            return "文本注释"
        default:
            return annotation.type.displayName
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行（可点击，用于跳转到PDF区域）
            HStack {
                Image(systemName: annotation.type.systemImage)
                    .foregroundColor(annotation.color.color)
                    .font(.system(size: 14))
                
                // 显示注释类型标题（区分便签注释和文本注释）
                Text(annotationTitle)
                    .font(.headline)
                
                Spacer()
                
                Text("第 \(annotation.pageIndex + 1) 页")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 删除按钮
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("删除注释")
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 展开内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Note类型：显示可编辑的文本框
                    if annotation.type == .textNote {
                        NoteContentEditorView(
                            content: annotation.content ?? "",
                            isEditing: isEditing || localEditingState,
                            onContentChanged: onContentChanged,
                            onEditToggle: {
                                localEditingState.toggle()
                            }
                        )
                    } else if annotation.type == .highlight || annotation.type == .underline || annotation.type == .strikeout {
                        // 文本注释（高亮、下划线、删除线）：显示选中的文本（只读）+ 可编辑的批注
                        VStack(alignment: .leading, spacing: 8) {
                            // 显示选中的文本（只读，带背景色）
                            if let sourceText = annotation.sourceText, !sourceText.isEmpty {
                                Text(sourceText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(annotation.color.color.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            // 可编辑的批注内容（类似 note 注释）
                            NoteContentEditorView(
                                content: annotation.content ?? "",
                                isEditing: isEditing || localEditingState,
                                onContentChanged: onContentChanged,
                                onEditToggle: {
                                    localEditingState.toggle()
                                }
                            )
                        }
                    } else if let content = annotation.content {
                        // 其他类型：只显示内容
                        Text(content)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    // Agent模式特有内容
                    if annotation.type == .agentNote {
                        if let sourceText = annotation.sourceText {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("原始文本:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(sourceText)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        if let translation = annotation.translation {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("翻译:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(translation)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        if let qaResult = annotation.qaResult {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("问答结果:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(qaResult)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
                    // 时间信息
                    Text("创建于: \(formatDate(annotation.createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.6))
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .overlay(
            // 选中状态的高亮边框
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle()) // 使整个注释框可点击
        .onTapGesture {
            // 点击注释框任何地方都可以跳转（但排除按钮和编辑区域）
            if let tap = onTap {
                tap()
            }
        }
        .onAppear {
            // 如果正在编辑，自动展开并进入编辑状态
            if isEditing {
                isExpanded = true
                localEditingState = true
            }
            editingContent = annotation.content ?? ""
        }
        .onChange(of: isEditing) { oldValue, newValue in
            // 当开始编辑时，自动展开并进入编辑状态
            if newValue {
                isExpanded = true
                localEditingState = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Note编辑器视图（简化版，用于批注功能区域）
struct NoteContentEditorView: View {
    let content: String
    let isEditing: Bool
    let onContentChanged: (String) -> Void
    var onEditToggle: (() -> Void)? = nil // 编辑状态切换回调
    
    @State private var editingText: String
    @FocusState private var isFocused: Bool
    init(content: String, isEditing: Bool, onContentChanged: @escaping (String) -> Void, onEditToggle: (() -> Void)? = nil) {
        self.content = content
        self.isEditing = isEditing
        self.onContentChanged = onContentChanged
        self.onEditToggle = onEditToggle
        _editingText = State(initialValue: content)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing || content.isEmpty {
                // 编辑模式：显示TextEditor和确认按钮
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $editingText)
                        .font(.body)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .focused($isFocused)
                        .onAppear {
                            // 自动聚焦
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isFocused = true
                            }
                        }
                        // 移除自动保存逻辑，只在点击"确认"按钮时才保存
                    
                    // 确认按钮
                    HStack {
                        Spacer()
                        Button(action: {
                            // 确认时立即保存（这是唯一触发保存的地方）
                            onContentChanged(editingText)
                            onEditToggle?()
                        }) {
                            Text("确认")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } else {
                // 只读模式：显示文本和编辑按钮
                HStack {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: {
                        onEditToggle?()
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("编辑")
                }
            }
        }
        .onChange(of: content) { oldValue, newValue in
            // 当外部内容变化时，更新编辑文本（只在非编辑状态时更新，避免覆盖用户正在输入的内容）
            // 同时检查内容是否真的变化了，避免不必要的更新
            if !isEditing && !isFocused && editingText != newValue {
                editingText = newValue
            }
        }
    }
}

// MARK: - 预览
#Preview {
    AnnotationModeView(
        pdfDocument: .constant(nil),
        selectedNoteAnnotation: .constant(nil),
        selectedAnnotationId: .constant(nil)
    )
    .frame(width: 400, height: 600)
}
