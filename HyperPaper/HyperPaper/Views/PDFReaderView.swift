//
// PDFReaderView.swift
// HyperPaper
//
// PDF阅读器视图 - 透明覆盖层方案（坐标系统一致）
//

import SwiftUI
import PDFKit
import AppKit

struct PDFReaderView: View {
    let document: PDFDocument
    @Binding var selectedText: String
    @Binding var isSelectionMode: Bool
    @Binding var selectedAnnotationTool: AnnotationTool
    @Binding var selectedAnnotationColor: Color
    var onAnnotationCreated: (() -> Void)? = nil // 注释创建后的回调
    var onNoteEditRequested: ((PDFAnnotation) -> Void)? = nil // Note编辑请求回调
    var noteToJumpTo: Annotation? = nil // 需要跳转到的note（从批注功能区域点击）
    var onClearHighlight: (() -> Void)? = nil // 清除高亮的回调
    var onPDFScroll: ((PDFAnnotation?) -> Void)? = nil // PDF滚动回调，传递当前可见的PDFAnnotation
    
    // 注意：Note编辑相关状态已移除，改为在批注功能区域处理
    @State private var multiPageSelection = MultiPageSelection()
    @State private var selectionStart: CGPoint?
    @State private var selectionEnd: CGPoint?
    @State private var isSelecting: Bool = false
    @State private var pdfView: PDFView?
    @State private var selectionOverlayView: SelectionOverlayNSView?
    
    // 注释相关状态
    @State private var freehandPoints: [CGPoint] = [] // 自由画线的当前路径点
    @State private var isDrawing: Bool = false // 是否正在绘制
    
    // 文本注释覆盖层状态
    @State private var showTextAnnotationOverlay: Bool = false
    @State private var textAnnotationPosition: CGPoint = .zero // PDFView 坐标系的位置
    @State private var textAnnotationPage: PDFPage? = nil
    @State private var editingTextAnnotation: PDFAnnotation? = nil // 正在编辑的文本注释（用于更新）
    
    // Vision API处理状态
    @State private var isProcessingVision: Bool = false
    @State private var visionProcessingStatus: String = ""
    
    // 清除所有选择的回调
    var onClearSelection: (() -> Void)? = nil
    
    // 删除单个选择区域的回调
    private func deleteSelectionRegion(_ regionId: UUID) {
        DispatchQueue.main.async {
            // 从multiPageSelection中删除指定的region
            self.multiPageSelection.regions.removeAll { $0.id == regionId }
            
            // 更新selectedText
            self.selectedText = PDFTextExtractor.extractText(
                from: self.document,
                selection: self.multiPageSelection
            )
            
            // 通知PDFView更新选择框显示
            if let customPDFView = self.pdfView as? CustomPDFView {
                customPDFView.setSelectionData(
                    multiPageSelection: self.multiPageSelection,
                    document: self.document,
                    isSelectionMode: self.isSelectionMode
                )
            }
        }
    }
    
    var body: some View {
        ZStack {
            // PDF视图（底层，内部管理选择框）
            PDFViewWrapper(
                document: document,
                pdfView: $pdfView,
                isSelectionMode: isSelectionMode,
                multiPageSelection: multiPageSelection,
                selectedAnnotationTool: selectedAnnotationTool,
                selectedAnnotationColor: selectedAnnotationColor,
                onDeleteRegion: deleteSelectionRegion,
                onNoteEditRequested: onNoteEditRequested,
                noteToJumpTo: noteToJumpTo,
                onClearHighlight: onClearHighlight,
                onPDFScroll: onPDFScroll,
                onAnnotationCreated: onAnnotationCreated
            )
            
            // 透明覆盖层（仅在选择模式下显示，上层，使用全局事件监听器捕获鼠标事件）
            // 注意：覆盖层不拦截任何事件，所有事件都穿透，选择通过全局事件监听器处理
            if isSelectionMode {
                SelectionOverlayView(
                    selectionStart: $selectionStart,
                    selectionEnd: $selectionEnd,
                    isSelecting: $isSelecting,
                    multiPageSelection: $multiPageSelection,
                    document: document,
                    pdfView: $pdfView,
                    isSelectionMode: isSelectionMode,
                    onSelectionComplete: { start, end in
                        // 完成选择，添加到多区域选择中
                        completeSelection(start: start, end: end)
                        // 不自动退出框选模式，允许继续选择
                    }
                )
                .allowsHitTesting(false) // 不拦截任何事件，让所有事件穿透
            }
            
            // 注释交互层（仅在选中了注释工具时显示）
            if selectedAnnotationTool != .none {
                AnnotationInteractionView(
                    selectedAnnotationTool: $selectedAnnotationTool,
                    selectedAnnotationColor: $selectedAnnotationColor,
                    document: document,
                    pdfView: $pdfView,
                    onAnnotationCreated: {
                        print("📝 PDFReaderView: 收到注释创建回调，转发到MainView")
                        onAnnotationCreated?()
                    },
                    onEditRequested: { annotation in
                        print("📝 PDFReaderView: 收到Note编辑请求，转发到MainView")
                        onNoteEditRequested?(annotation)
                    }
                )
                .allowsHitTesting(false) // 不拦截事件，事件由NSEvent monitor处理，但view需要可见以绘制预览
                .onAppear {
                    // 进入注释模式：临时隐藏覆盖层以避免遮挡注释渲染
                    if let customPDFView = pdfView as? CustomPDFView {
                        customPDFView.setAnnotationMode(true)
                    }
                }
                .onDisappear {
                    // 退出注释模式：恢复覆盖层显示
                    if let customPDFView = pdfView as? CustomPDFView {
                        customPDFView.setAnnotationMode(false)
                    }
                }
            }
            
            // 注意：Note编辑界面已移除，改为在批注功能区域显示
            
            // 文本注释输入覆盖层（参考 Apple 预览应用的实现方式）
            if showTextAnnotationOverlay, let page = textAnnotationPage {
                TextAnnotationOverlay(
                    isPresented: $showTextAnnotationOverlay,
                    initialPosition: textAnnotationPosition,
                    page: page,
                    pdfView: pdfView,
                    color: selectedAnnotationColor,
                    existingAnnotation: editingTextAnnotation, // 传入现有注释（如果有）
                    onSave: { text, bounds in
                        saveTextAnnotation(text: text, bounds: bounds, on: page, existingAnnotation: editingTextAnnotation)
                    },
                    onDelete: editingTextAnnotation != nil ? {
                        deleteTextAnnotation(editingTextAnnotation!)
                    } : nil,
                    onCancel: {
                        cancelTextAnnotation()
                    }
                )
            }
            
            // Vision API处理状态显示
            if isProcessingVision {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    
                    if !visionProcessingStatus.isEmpty {
                        Text(visionProcessingStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
                .shadow(radius: 4)
            }
        }
        .onChange(of: isSelectionMode) { _, newValue in
            // 退出选择模式时清除选择状态
            if !newValue {
                isSelecting = false
                selectionStart = nil
                selectionEnd = nil
                // 注意：不清除multiPageSelection，保留已选择的区域
                
                // 确保 SelectionOverlayNSView 的状态也被清理
                // 通过设置 isSelectionMode 来触发清理
                // 注意：这里不能直接访问 SelectionOverlayNSView，因为它可能已经被移除
                // 但 SwiftUI 会在 updateNSView 中处理
            }
        }
        .onChange(of: selectedText) { oldValue, newValue in
            // 如果selectedText被外部清空，也清除内部选择
            if newValue.isEmpty && !multiPageSelection.regions.isEmpty {
                // 在主线程上清除选择
                DispatchQueue.main.async {
                    self.multiPageSelection.regions.removeAll()
                    // 通知PDFView清除选择框显示
                    if let pdfView = self.pdfView as? CustomPDFView {
                        pdfView.clearSelections()
                    }
                }
            }
        }
        .onChange(of: selectedAnnotationTool) { oldValue, newValue in
            // 监听注释工具变化，控制覆盖层显示/隐藏
            // 这是测试方案：如果隐藏覆盖层后注释显示，说明是覆盖层遮挡问题
            if let customPDFView = pdfView as? CustomPDFView {
                customPDFView.setAnnotationMode(newValue != .none)
            }
            
            // 如果用户在编辑文本注释时切换工具，自动退出编辑状态
            if oldValue == .text && newValue != .text && showTextAnnotationOverlay {
                Swift.print("✅ PDFReaderView: 工具从 text 切换到 \(newValue)，自动关闭文本编辑覆盖层")
                cancelTextAnnotation()
            }
        }
        // 注意：multiPageSelection的变化通过PDFViewWrapper的updateNSView处理
        // 这里不需要额外的onChange监听
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTextAnnotationOverlay"))) { notification in
            // 接收显示文本注释覆盖层的通知
            if let userInfo = notification.userInfo,
               let windowPoint = userInfo["position"] as? CGPoint,
               let page = userInfo["page"] as? PDFPage {
                // 窗口坐标需要转换为 SwiftUI 视图坐标
                // 使用 GeometryReader 和 PreferenceKey 来获取 PDFView 的实际位置
                // 暂时直接使用窗口坐标，在 TextAnnotationOverlay 中转换
                textAnnotationPosition = windowPoint
                textAnnotationPage = page
                
                // 检查是否有现有注释需要编辑
                if let existingAnnotation = userInfo["existingAnnotation"] as? PDFAnnotation {
                    editingTextAnnotation = existingAnnotation
                } else {
                    editingTextAnnotation = nil
                }
                
                showTextAnnotationOverlay = true
                
                Swift.print("✅ PDFReaderView: 收到显示文本注释覆盖层通知")
                Swift.print("  - windowPoint: \(windowPoint)")
                Swift.print("  - editingTextAnnotation: \(editingTextAnnotation != nil ? "有" : "无")")
            }
        }
        .overlay(
            // 添加滚轮事件监听（在SwiftUI层面，透明层）
            ScrollWheelHandler(pdfView: $pdfView)
        )
    }
    
    // MARK: - 文本注释覆盖层相关方法
    
    /// 保存文本注释到 PDF
    private func saveTextAnnotation(text: String, bounds: CGRect, on page: PDFPage, existingAnnotation: PDFAnnotation? = nil) {
        guard let pdfView = pdfView else { return }
        
        if let existingAnnotation = existingAnnotation {
            // 更新现有注释
            Swift.print("✅ PDFReaderView.saveTextAnnotation: 更新现有文本注释")
            
            // 更新文本内容
            existingAnnotation.contents = text
            
            // 更新 bounds（如果文本大小变化）
            existingAnnotation.bounds = bounds
            
            // 更新 appearance stream
            if existingAnnotation.responds(to: Selector(("updateAppearanceStream"))) {
                existingAnnotation.perform(Selector(("updateAppearanceStream")))
            }
            
            // 刷新 PDFView 显示
            pdfView.setNeedsDisplay(pdfView.bounds)
            pdfView.display()
            
            // 发送通知，让 AnnotationModeView 同步
            NotificationCenter.default.post(
                name: NSNotification.Name("PDFAnnotationUpdated"),
                object: nil,
                userInfo: [
                    "annotation": existingAnnotation,
                    "page": page
                ]
            )
            
            // 通知注释已更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onAnnotationCreated?()
            }
        } else {
            // 创建新注释
            let color = PDFAnnotationService.nsColor(from: selectedAnnotationColor)
            let annotation = PDFAnnotationService.createText(
                on: page,
                at: CGPoint(x: bounds.midX, y: bounds.midY),
                text: text,
                fontSize: 10,
                color: color
            )
            
            // 设置精确的 bounds 并确保文本显示
            if let annotation = annotation {
                annotation.bounds = bounds
                
                // 关键：确保文本内容正确设置
                annotation.contents = text
                
                // 关键：更新 appearance stream 以确保文本显示
                if annotation.responds(to: Selector(("updateAppearanceStream"))) {
                    annotation.perform(Selector(("updateAppearanceStream")))
                }
                
                // 刷新 PDFView 显示
                pdfView.setNeedsDisplay(pdfView.bounds)
                pdfView.display()
                
                Swift.print("✅ PDFReaderView.saveTextAnnotation: 创建了新文本注释")
                Swift.print("  - text: \(text)")
                Swift.print("  - bounds: \(bounds)")
                
                // 通知注释已创建
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.onAnnotationCreated?()
                }
                
                // 发送通知，让 AnnotationModeView 同步
                NotificationCenter.default.post(
                    name: NSNotification.Name("PDFAnnotationCreated"),
                    object: nil,
                    userInfo: [
                        "annotation": annotation,
                        "page": page,
                        "providedColor": AnnotationColor.from(selectedAnnotationColor)
                    ]
                )
                
                // 立即恢复非注释模式（移除延迟，防止重复创建）
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AnnotationCreatedResetTool"),
                        object: nil
                    )
                }
            }
        }
        
        // 关闭覆盖层
        cancelTextAnnotation()
    }
    
    /// 删除文本注释
    private func deleteTextAnnotation(_ annotation: PDFAnnotation) {
        guard let page = annotation.page else { return }
        
        // 从PDF中删除注释
        page.removeAnnotation(annotation)
        
        // 刷新 PDFView 显示
        if let pdfView = pdfView {
            pdfView.setNeedsDisplay(pdfView.bounds)
            pdfView.display()
        }
        
        // 发送通知，让 AnnotationModeView 同步
        NotificationCenter.default.post(
            name: NSNotification.Name("PDFAnnotationUpdated"),
            object: nil
        )
        
        // 通知注释已删除
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onAnnotationCreated?()
        }
        
        // 关闭覆盖层
        cancelTextAnnotation()
    }
    
    /// 取消文本注释输入
    private func cancelTextAnnotation() {
        // 关闭覆盖层
        showTextAnnotationOverlay = false
        textAnnotationPage = nil
        textAnnotationPosition = .zero
        editingTextAnnotation = nil
    }
    
    private func completeSelection(start: CGPoint, end: CGPoint) {
        guard let pdfView = pdfView,
              let currentPage = pdfView.currentPage else {
            return
        }
        
        let pageIndex = document.index(for: currentPage)
        
        // 计算选择矩形
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        
        let width = maxX - minX
        let height = maxY - minY
        
        // 面积阈值检查：如果框选区域太小，不保留选择
        // 最小宽度和高度阈值（单位：点）
        let minSelectionWidth: CGFloat = 20.0
        let minSelectionHeight: CGFloat = 20.0
        let minSelectionArea: CGFloat = minSelectionWidth * minSelectionHeight
        
        // 计算实际面积
        let selectionArea = width * height
        
        // 如果宽度或高度小于阈值，或者面积小于阈值，则不保留选择
        if width < minSelectionWidth || height < minSelectionHeight || selectionArea < minSelectionArea {
            // 区域太小，不创建选择，直接返回
            return
        }
        
        let rect = CGRect(
            x: minX,
            y: minY,
            width: width,
            height: height
        )
        
        // 将视图坐标转换为PDF页面坐标
        // 注意：convert(_:to:)方法将视图坐标（左上角原点）转换为PDF页面坐标（左下角原点）
        let pdfRect = pdfView.convert(rect, to: currentPage)
        
        // 创建选择区域
        let region = SelectionRegion(
            pageIndex: pageIndex,
            rect: pdfRect
        )
        
        // 根据公式处理模式选择处理路径
        let mode = FormulaProcessingMode.current
        switch mode {
        case .none:
            // 不处理公式：直接提取文本
            processSelectionWithTextOnly(region: region)
        case .localOCR:
            // 本地OCR处理：先提取文本，再OCR更新
            processSelectionWithLocalOCR(region: region)
        case .vlmAPI:
            // Vision API处理：统一处理
            processSelectionWithVision(region: region)
        }
    }
    
    /// 仅提取文本（不处理公式）
    private func processSelectionWithTextOnly(region: SelectionRegion) {
        // 直接提取文本
        if let text = PDFTextExtractor.extractText(
            from: document,
            pageIndex: region.pageIndex,
            rect: region.rect
        ), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var updatedRegion = region
            updatedRegion.text = text
            
            DispatchQueue.main.async {
                self.multiPageSelection.regions.append(updatedRegion)
                self.selectedText = PDFTextExtractor.extractText(
                    from: self.document,
                    selection: self.multiPageSelection
                )
                
                if let customPDFView = self.pdfView as? CustomPDFView {
                    customPDFView.setSelectionData(
                        multiPageSelection: self.multiPageSelection,
                        document: self.document,
                        isSelectionMode: self.isSelectionMode
                    )
                }
            }
        }
    }
    
    /// 使用本地OCR处理选择区域（先提取文本，再OCR更新）
    private func processSelectionWithLocalOCR(region: SelectionRegion) {
        // 1. 立即提取原始文本并更新UI
        var originalText: String = ""
        if let text = PDFTextExtractor.extractText(
            from: document,
            pageIndex: region.pageIndex,
            rect: region.rect
        ), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            originalText = text
            var updatedRegion = region
            updatedRegion.text = originalText
            
            DispatchQueue.main.async {
                // 追加原始文本到现有选择
                self.multiPageSelection.regions.append(updatedRegion)
                let oldSelectedText = self.selectedText
                self.selectedText = PDFTextExtractor.extractText(
                    from: self.document,
                    selection: self.multiPageSelection
                )
                
                if let customPDFView = self.pdfView as? CustomPDFView {
                    customPDFView.setSelectionData(
                        multiPageSelection: self.multiPageSelection,
                        document: self.document,
                        isSelectionMode: self.isSelectionMode
                    )
                }
            }
        }
        
        // 2. 并行启动OCR处理
        Task {
            do {
                // 提取图像
                let image = try PDFImageExtractor.extractImage(
                    from: document,
                    region: region,
                    pdfView: pdfView,
                    scale: 2.0
                )
                
                // 调用本地OCR（带进度回调）
                let ocrService = Pix2TextService.shared
                let ocrResult = try await ocrService.recognizeImage(
                    image: image,
                    progressCallback: { progress in
                        // 更新OCR进度（通过通知或绑定传递）
                        // 注意：progress=1.0时不发送通知，避免与OCR完成通知冲突
                        // OCR完成通知会在OCR结果更新时统一发送
                        if progress < 1.0 {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("OCRProgressUpdate"),
                                    object: nil,
                                    userInfo: ["progress": progress, "regionId": region.id.uuidString]
                                )
                            }
                        }
                    }
                )
                
                // 3. OCR完成后，更新对应region的text
                await MainActor.run {
                    // 找到对应的region并更新
                    if let index = self.multiPageSelection.regions.firstIndex(where: { $0.id == region.id }) {
                        var updatedRegion = self.multiPageSelection.regions[index]
                        updatedRegion.text = ocrResult
                        self.multiPageSelection.regions[index] = updatedRegion
                        
                        // 重新合并所有区域的文本
                        let oldSelectedText = self.selectedText
                        self.selectedText = self.multiPageSelection.regions
                            .compactMap { $0.text }
                            .joined(separator: "\n\n")
                        
                        // 通知PDFView更新
                        if let customPDFView = self.pdfView as? CustomPDFView {
                            customPDFView.setSelectionData(
                                multiPageSelection: self.multiPageSelection,
                                document: self.document,
                                isSelectionMode: self.isSelectionMode
                            )
                        }
                    }
                    
                    // 在同一runloop中，先发送OCR完成通知（隐藏进度条），再发送OCRCompleted通知（触发翻译）
                    // 这样可以确保进度条隐藏和文本框更新同步，避免闪现
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OCRProgressUpdate"),
                        object: nil,
                        userInfo: ["progress": 1.0, "regionId": region.id.uuidString, "completed": true]
                    )
                    
                    // 立即发送OCRCompleted通知，确保onChange触发时能检测到OCR更新
                    // 这样可以解决第一次框选时无法静默更新的问题
                    // 注意：虽然selectedText在同一runloop中更新，但onChange会在下一个runloop触发
                    // 所以OCRCompleted通知会在onChange之前发送，确保isOCRPending已设置
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OCRCompleted"),
                        object: nil,
                        userInfo: ["regionId": region.id.uuidString]
                    )
                }
                
            } catch {
                // OCR失败，保持原始文本
                await MainActor.run {
                    // 清除OCR进度
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OCRProgressUpdate"),
                        object: nil,
                        userInfo: ["progress": 0.0, "regionId": region.id.uuidString, "completed": true, "error": true]
                    )
                }
            }
        }
    }
    
    /// 使用Vision API处理选择区域
    private func processSelectionWithVision(region: SelectionRegion) {
        // 更新处理状态
        DispatchQueue.main.async {
            self.isProcessingVision = true
            self.visionProcessingStatus = "提取图像中..."
        }
        
        Task {
            do {
                // 1. 提取图像
                let image = try PDFImageExtractor.extractImage(
                    from: document,
                    region: region,
                    pdfView: pdfView,
                    scale: 2.0
                )
                
                await MainActor.run {
                    self.visionProcessingStatus = "识别内容中..."
                }
                
                // 2. 转换为Base64
                guard let imageBase64 = PDFImageExtractor.imageToBase64(image) else {
                    throw PDFImageExtractionError.renderingFailed
                }
                
                // 3. 调用Vision API识别内容
                let apiService = QwenAPIService()
                let recognizedText = try await apiService.recognizeImage(
                    imageBase64: imageBase64,
                    model: "Qwen-VL-Max"
                )
                
                // 4. 更新UI（主线程）
                await MainActor.run {
                    var updatedRegion = region
                    updatedRegion.text = recognizedText
                    
                    // 追加到现有选择（支持多区域选择）
                    self.multiPageSelection.regions.append(updatedRegion)
                    
                    // 更新选中文本（合并所有区域的文本）
                    self.selectedText = self.multiPageSelection.regions
                        .compactMap { $0.text }
                        .joined(separator: "\n\n")
                    
                    // 通知PDFView更新选择框显示
                    if let customPDFView = self.pdfView as? CustomPDFView {
                        customPDFView.setSelectionData(
                            multiPageSelection: self.multiPageSelection,
                            document: self.document,
                            isSelectionMode: self.isSelectionMode
                        )
                    }
                    
                    // 清除处理状态
                    self.isProcessingVision = false
                    self.visionProcessingStatus = ""
                }
                
            } catch {
                // 处理错误：降级到文本提取
                await MainActor.run {
                    self.visionProcessingStatus = "Vision API失败，使用文本提取..."
                }
                
                // 降级方案：使用普通文本提取
                if let text = PDFTextExtractor.extractText(
                    from: document,
                    pageIndex: region.pageIndex,
                    rect: region.rect
                ), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    var updatedRegion = region
                    updatedRegion.text = text
                    
                    DispatchQueue.main.async {
                        self.multiPageSelection.regions.append(updatedRegion)
                        self.selectedText = PDFTextExtractor.extractText(
                            from: self.document,
                            selection: self.multiPageSelection
                        )
                        
                        if let customPDFView = self.pdfView as? CustomPDFView {
                            customPDFView.setSelectionData(
                                multiPageSelection: self.multiPageSelection,
                                document: self.document,
                                isSelectionMode: self.isSelectionMode
                            )
                        }
                        
                        self.isProcessingVision = false
                        self.visionProcessingStatus = ""
                    }
                } else {
                    // 如果文本提取也失败，显示错误
                    await MainActor.run {
                        self.isProcessingVision = false
                        self.visionProcessingStatus = "处理失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

// PDFView包装器（支持常规操作）
struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    @Binding var pdfView: PDFView?
    let isSelectionMode: Bool
    let multiPageSelection: MultiPageSelection // 传递选择数据
    let selectedAnnotationTool: AnnotationTool // 当前选中的注释工具
    let selectedAnnotationColor: Color // 当前选中的注释颜色
    let onDeleteRegion: (UUID) -> Void // 删除单个区域的回调
    var onNoteEditRequested: ((PDFAnnotation) -> Void)? = nil // Note编辑请求回调
    var noteToJumpTo: Annotation? = nil // 需要跳转到的note（从批注功能区域点击）
    var onClearHighlight: (() -> Void)? = nil // 清除高亮的回调
    var onPDFScroll: ((PDFAnnotation?) -> Void)? = nil // PDF滚动回调，传递当前可见的PDFAnnotation
    var onAnnotationCreated: (() -> Void)? = nil // 注释创建后的回调
    
    func makeNSView(context: Context) -> CustomPDFView {
        let view = CustomPDFView()
        view.document = document
        
        // 禁用自动缩放，允许用户手动控制
        view.autoScales = false
        
        // 设置初始缩放比例（100%）
        view.scaleFactor = 1.0
        
        view.displayMode = .singlePageContinuous // 连续模式，支持无缝滚动
        view.displayDirection = .vertical
        
        // 关键：启用注释编辑功能
        // 注意：在 macOS 中，PDFView 默认允许编辑注释，但我们需要确保它被启用
        // 通过设置 delegate 或使用其他方法确保编辑功能可用
        
        // 设置缩放范围
        view.minScaleFactor = 0.25
        view.maxScaleFactor = 4.0
        
        // 确保可以接收事件
        view.wantsLayer = true
        
        // 确保PDFView可以显示注释
        // 注意：某些macOS版本的PDFView可能需要显式启用注释显示
        // 但displaysAnnotations属性在当前版本中不存在
        
        // 启用滚动条（如果存在）
        if let scrollView = view.enclosingScrollView {
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = true
            // 确保滚动条始终可见（在需要时）
            scrollView.scrollerStyle = .overlay
        }
        
        // 设置选择框数据（传递 isSelectionMode）
        view.setSelectionData(multiPageSelection: multiPageSelection, document: document, isSelectionMode: isSelectionMode)
        
        // 设置删除回调
        view.setDeleteCallback(onDeleteRegion)
        
        // 设置Note编辑请求回调
        view.onNoteEditRequested = onNoteEditRequested
        
        // 设置跳转note
        view.noteToJumpTo = noteToJumpTo
        
        // 设置清除高亮回调
        view.onClearHighlight = onClearHighlight
        
        // 设置PDF滚动回调
        view.onPDFScroll = onPDFScroll
        
        // 设置注释工具和颜色（用于创建文本注释）
        view.selectedAnnotationTool = selectedAnnotationTool
        view.selectedAnnotationColor = selectedAnnotationColor
        view.onAnnotationCreated = onAnnotationCreated
        
        DispatchQueue.main.async {
            self.pdfView = view
            // 尝试让PDFView成为第一响应者
            if let window = view.window {
                window.makeFirstResponder(view)
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: CustomPDFView, context: Context) {
        nsView.document = document
        nsView.selectedAnnotationTool = selectedAnnotationTool
        nsView.selectedAnnotationColor = selectedAnnotationColor
        nsView.onAnnotationCreated = onAnnotationCreated
        
        // 常规模式下恢复显示模式（连续模式支持无缝滚动）
        nsView.displayMode = .singlePageContinuous
        
        // 更新选择框数据（传递 isSelectionMode）
        nsView.setSelectionData(multiPageSelection: multiPageSelection, document: document, isSelectionMode: isSelectionMode)
        
        // 更新删除回调
        nsView.setDeleteCallback(onDeleteRegion)
        
        // 更新Note编辑请求回调
        nsView.onNoteEditRequested = onNoteEditRequested
        
        // 更新清除高亮回调
        nsView.onClearHighlight = onClearHighlight
        
        // 更新PDF滚动回调
        nsView.onPDFScroll = onPDFScroll
        
        // 更新跳转note（如果变化了，执行跳转）
        let shouldJump = nsView.noteToJumpTo?.id != noteToJumpTo?.id
        nsView.noteToJumpTo = noteToJumpTo
        
        if shouldJump, let note = noteToJumpTo {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nsView.jumpToNote(note)
            }
        }
        
        DispatchQueue.main.async {
            self.pdfView = nsView
        }
    }
    
    static func dismantleNSView(_ nsView: CustomPDFView, coordinator: ()) {
        // 清理资源
        nsView.clearSelections()
    }
}

// 自定义PDFView（管理选择框）
class CustomPDFView: PDFView {
    // 选择框覆盖层（直接添加到PDFView内部，坐标系一致）
    // 注意：需要可以被SelectionOverlayNSView访问，用于检查点击是否在选择框上
    var selectionOverlay: PDFInternalSelectionOverlay?
    
    // Note编辑请求回调（用于点击note时跳转到批注功能区域）
    var onNoteEditRequested: ((PDFAnnotation) -> Void)? = nil
    var onClearHighlight: (() -> Void)? = nil // 清除高亮的回调
    var onPDFScroll: ((PDFAnnotation?) -> Void)? = nil // PDF滚动回调，传递当前可见的PDFAnnotation
    var onAnnotationCreated: (() -> Void)? = nil // 注释创建后的回调
    
    // 注释工具相关
    var selectedAnnotationTool: AnnotationTool = .none // 当前选中的注释工具
    var selectedAnnotationColor: Color = .yellow // 当前选中的注释颜色

    // 跳转note相关状态
    var noteToJumpTo: Annotation? = nil // 需要跳转到的note（从批注功能区域点击）
    private var highlightLayer: CALayer? = nil // 高亮层（用于显示note位置）
    private var highlightTimer: Timer? = nil // 高亮定时器（已废弃，不再自动取消高亮）
    private var highlightedPDFAnnotation: PDFAnnotation? = nil // 当前高亮的PDFAnnotation
    
    // PDF滚动监听相关
    private var scrollTimer: Timer? = nil // 滚动节流定时器
    
    // 确保可以接收滚轮事件
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // 确保可以成为第一响应者
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // 确保滚动事件能正确处理
    override func scrollWheel(with event: NSEvent) {
        // 让PDFView自己处理滚动
        super.scrollWheel(with: event)
        
        // 滚动后，延迟检测当前可见的注释（节流，优化响应速度）
        scrollTimer?.invalidate()
        // 减少节流时间从 0.1 秒到 0.05 秒，提高响应速度
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.detectVisibleAnnotation()
        }
    }
    
    /// 检测当前可见的注释
    private func detectVisibleAnnotation() {
        guard let document = self.document else { return }
        
        // 获取当前可见区域（视图坐标）
        let visibleRect = self.visibleRect
        
        // 找到可见区域内的第一个note注释（按从上到下的顺序）
        var visibleAnnotation: PDFAnnotation? = nil
        var topmostY: CGFloat = -CGFloat.greatestFiniteMagnitude // 记录最上方的Y坐标
        
        // 优化：只检查可见区域附近的页面，减少遍历范围
        // 计算可见区域覆盖的页面范围
        let visibleTop = visibleRect.maxY
        let visibleBottom = visibleRect.minY
        
        // 遍历所有页面，找到可见区域内的注释
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            // 获取页面在视图中的位置
            let pageRect = self.convert(page.bounds(for: .mediaBox), from: page)
            
            // 快速检查：如果页面完全在可见区域上方或下方，跳过（优化性能）
            if pageRect.maxY < visibleBottom || pageRect.minY > visibleTop {
                continue
            }
            
            // 检查页面是否在可见区域内
            if pageRect.intersects(visibleRect) {
                // 检查页面内的注释（支持所有注释类型）
                for annotation in page.annotations {
                    let annotationType = annotation.type ?? ""
                    let normalizedType = annotationType.hasPrefix("/") ? String(annotationType.dropFirst()) : annotationType
                    
                    // 支持所有注释类型（note、高亮、下划线、删除线）
                    if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue ||
                       normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue ||
                       normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue ||
                       normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
                        // 获取注释在视图中的位置
                        let annotationRect = self.convert(annotation.bounds, from: page)
                        
                        // 检查注释是否在可见区域内（至少部分可见）
                        if annotationRect.intersects(visibleRect) {
                            // 找到最上方的注释（Y坐标最大，因为PDF坐标系是左下角为原点）
                            let annotationY = annotationRect.maxY
                            if annotationY > topmostY {
                                topmostY = annotationY
                                visibleAnnotation = annotation
                            }
                        }
                    }
                }
            }
        }
        
        // 通知回调（优化：直接调用，因为已经在主线程）
        self.onPDFScroll?(visibleAnnotation)
    }
    
    // 重写mouseDown，拦截点击note注释的事件，防止PDFView显示默认编辑面板
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        let viewLocation = self.convert(location, from: nil)
        
        // 检查是否点击在PDF内容区域内
        guard self.bounds.contains(viewLocation) else {
            super.mouseDown(with: event)
            return
        }
        
        // 获取当前页面和页面坐标
        guard let currentPage = self.currentPage else {
            super.mouseDown(with: event)
            return
        }
        
        let pagePoint = self.convert(viewLocation, to: currentPage)
        
        // 关键：如果选择了 text 工具，显示文本输入覆盖层（参考 Apple 预览应用的实现方式）
        // 或者点击现有 FreeText 注释时，显示编辑覆盖层
        var hitFreeTextAnnotation: PDFAnnotation? = nil
        for annotation in currentPage.annotations {
            let annotationType = annotation.type ?? ""
            let normalizedType = annotationType.hasPrefix("/") ? String(annotationType.dropFirst()) : annotationType
            
            if normalizedType == "FreeText" || normalizedType == PDFAnnotationSubtype.freeText.rawValue {
                let bounds = annotation.bounds
                
                // 计算实际文本内容的区域（排除多余的 padding）
                // FreeText 注释的 bounds 可能包含额外的 padding，我们需要计算实际文本区域
                let actualTextBounds: CGRect
                if let contents = annotation.contents, !contents.isEmpty {
                    // 使用文本内容计算实际区域
                    let font = annotation.font ?? NSFont.systemFont(ofSize: 10)
                    let attributes: [NSAttributedString.Key: Any] = [.font: font]
                    let attributedString = NSAttributedString(string: contents, attributes: attributes)
                    
                    // 计算文本的实际大小
                    let maxWidth = bounds.width
                    let textStorage = NSTextStorage(attributedString: attributedString)
                    let layoutManager = NSLayoutManager()
                    textStorage.addLayoutManager(layoutManager)
                    let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
                    textContainer.lineFragmentPadding = 0
                    layoutManager.addTextContainer(textContainer)
                    layoutManager.ensureLayout(for: textContainer)
                    let usedRect = layoutManager.usedRect(for: textContainer)
                    
                    // 实际文本区域：从 bounds 的左上角开始，使用文本的实际宽度和高度
                    // 注意：PDF 坐标系原点在左下角，但 bounds 的 origin 是左下角
                    let textWidth = min(ceil(usedRect.width), bounds.width)
                    let textHeight = ceil(usedRect.height)
                    
                    // 计算实际文本区域（考虑 bounds 的 origin 和文本的实际大小）
                    // 文本在 bounds 内的位置：通常文本从 bounds 的底部开始（PDF 坐标系）
                    actualTextBounds = CGRect(
                        x: bounds.origin.x,
                        y: bounds.origin.y,
                        width: textWidth,
                        height: textHeight
                    )
                } else {
                    // 如果没有文本内容，使用一个很小的区域
                    actualTextBounds = CGRect(
                        x: bounds.origin.x,
                        y: bounds.origin.y,
                        width: min(bounds.width, 100),
                        height: min(bounds.height, 20)
                    )
                }
                
                // 只在实际文本区域加上小的 padding 进行点击检测
                let padding: CGFloat = 3 // 减小 padding，只在实际文本区域附近
                let hitTestBounds = actualTextBounds.insetBy(dx: -padding, dy: -padding)
                
                if hitTestBounds.contains(pagePoint) {
                    hitFreeTextAnnotation = annotation
                    break
                }
            }
        }
        
        // 如果点击了现有 FreeText 注释，显示编辑覆盖层
        if let existingAnnotation = hitFreeTextAnnotation {
            // 计算注释在视图中的位置（用于显示覆盖层）
            let annotationBounds = existingAnnotation.bounds
            let annotationCenter = CGPoint(x: annotationBounds.midX, y: annotationBounds.midY)
            let viewCenter = self.convert(annotationCenter, from: currentPage)
            let windowPoint = self.convert(viewCenter, to: nil)
            
            Swift.print("✅ CustomPDFView.mouseDown: 点击了现有 FreeText 注释，显示编辑覆盖层")
            Swift.print("  - annotation.contents: \(existingAnnotation.contents ?? "nil")")
            Swift.print("  - viewCenter: \(viewCenter)")
            Swift.print("  - windowPoint: \(windowPoint)")
            
            // 通过 NotificationCenter 通知 PDFReaderView 显示编辑覆盖层
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowTextAnnotationOverlay"),
                object: nil,
                userInfo: [
                    "position": windowPoint,
                    "page": currentPage,
                    "existingAnnotation": existingAnnotation
                ]
            )
            
            // 不调用 super.mouseDown，因为我们自己处理了
            return
        }
        
        // 如果选择了 text 工具且没有点击现有注释，显示新建覆盖层
        if selectedAnnotationTool == .text {
            // 关键：viewLocation 是相对于 CustomPDFView 的坐标
            // 需要转换为窗口坐标，然后在 SwiftUI 中转换回视图坐标
            // 这样可以确保坐标系统一致
            let windowPoint = self.convert(viewLocation, to: nil) // 转换为窗口坐标
            
            Swift.print("✅ CustomPDFView.mouseDown: 显示文本输入覆盖层")
            Swift.print("  - viewLocation (PDFView坐标): \(viewLocation)")
            Swift.print("  - windowPoint (窗口坐标): \(windowPoint)")
            Swift.print("  - PDFView.bounds: \(self.bounds)")
            
            // 通过 NotificationCenter 通知 PDFReaderView 显示覆盖层
            // 传递窗口坐标，让 SwiftUI 层转换回视图坐标
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowTextAnnotationOverlay"),
                object: nil,
                userInfo: [
                    "position": windowPoint, // 使用窗口坐标
                    "page": currentPage,
                    "pdfViewBounds": NSStringFromRect(self.bounds) // 传递 PDFView 的 bounds 用于验证
                ]
            )
            
            // 不调用 super.mouseDown，因为我们自己处理了
            return
        }
        
        // 检查是否点击了注释（支持所有注释类型）
        for annotation in currentPage.annotations {
            let annotationType = annotation.type ?? ""
            let normalizedType = annotationType.hasPrefix("/") ? String(annotationType.dropFirst()) : annotationType
            
            // 支持所有注释类型（note、高亮、下划线、删除线）
            // 注意：FreeText 注释让 PDFView 自己处理编辑，不拦截
            if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue ||
               normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue ||
               normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue ||
               normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue {
                let bounds = annotation.bounds
                
                // Note注释：扩大点击区域以便于点击
                let expandedSize: CGFloat = normalizedType == "Text" ? 24 : 0
                let hitTestBounds = CGRect(
                    x: bounds.midX - expandedSize / 2,
                    y: bounds.midY - expandedSize / 2,
                    width: bounds.width + expandedSize,
                    height: bounds.height + expandedSize
                )
                
                if hitTestBounds.contains(pagePoint) {
                    // 点击了注释，不调用super.mouseDown，防止PDFView显示默认编辑面板
                    // 高亮这个注释并跳转到批注功能区域
                    Swift.print("📝 CustomPDFView: 检测到点击注释（\(normalizedType)），拦截事件，跳转到批注功能区域")
                    DispatchQueue.main.async {
                        // 高亮这个注释
                        self.showNoteHighlight(annotation: annotation, on: currentPage)
                        // 跳转到批注功能区域
                        self.onNoteEditRequested?(annotation)
                    }
                    return
                }
            }
            
            // FreeText 注释：已经在上面处理了（显示编辑覆盖层），这里不再处理
        }
        
        // 没有点击note注释，点击了空白区域，清除所有高亮
        Swift.print("📝 CustomPDFView: 点击空白区域，清除所有高亮")
        clearNoteHighlight()
        DispatchQueue.main.async {
            self.onClearHighlight?()
        }
        
        // 让PDFView正常处理
        super.mouseDown(with: event)
    }
    
    // mouseUp 不拦截，让 PDFView 检测到新创建的注释并自动进入编辑模式
    // 注释已在 mouseDown 中创建，PDFView 会在 mouseUp 时检测到并进入编辑模式
    
    // 重写rightMouseDown，处理右键菜单（删除注释）
    override func rightMouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        let viewLocation = self.convert(location, from: nil)
        
        // 检查是否点击在PDF内容区域内
        guard self.bounds.contains(viewLocation) else {
            super.rightMouseDown(with: event)
            return
        }
        
        // 获取当前页面和页面坐标
        guard let currentPage = self.currentPage else {
            super.rightMouseDown(with: event)
            return
        }
        
        let pagePoint = self.convert(viewLocation, to: currentPage)
        
        // 检查是否右键点击了注释（支持所有注释类型）
        var hitAnnotation: PDFAnnotation? = nil
        for annotation in currentPage.annotations {
            let annotationType = annotation.type ?? ""
            let normalizedType = annotationType.hasPrefix("/") ? String(annotationType.dropFirst()) : annotationType
            
            // 检查是否是支持的注释类型（包括 FreeText）
            if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue ||
               normalizedType == "Highlight" || normalizedType == PDFAnnotationSubtype.highlight.rawValue ||
               normalizedType == "Underline" || normalizedType == PDFAnnotationSubtype.underline.rawValue ||
               normalizedType == "StrikeOut" || normalizedType == PDFAnnotationSubtype.strikeOut.rawValue ||
               normalizedType == "FreeText" || normalizedType == PDFAnnotationSubtype.freeText.rawValue {
                
                // 检查点击位置是否在注释范围内
                let bounds = annotation.bounds
                // 对于note注释，扩大点击区域
                let expandedSize: CGFloat = normalizedType == "Text" ? 24 : 0
                let hitTestBounds = CGRect(
                    x: bounds.midX - expandedSize / 2,
                    y: bounds.midY - expandedSize / 2,
                    width: bounds.width + expandedSize,
                    height: bounds.height + expandedSize
                )
                
                if hitTestBounds.contains(pagePoint) {
                    hitAnnotation = annotation
                    break
                }
            }
        }
        
        if let annotation = hitAnnotation {
            // 显示右键菜单
            let menu = NSMenu()
            let deleteItem = NSMenuItem(title: "删除", action: #selector(deleteAnnotation(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = annotation
            menu.addItem(deleteItem)
            
            // 显示菜单
            menu.popUp(positioning: deleteItem, at: viewLocation, in: self)
        } else {
            // 没有点击注释，让PDFView正常处理
            super.rightMouseDown(with: event)
        }
    }
    
    // 删除注释的方法
    @objc private func deleteAnnotation(_ sender: NSMenuItem) {
        guard let annotation = sender.representedObject as? PDFAnnotation,
              let page = annotation.page else {
            return
        }
        
        // 从PDF中删除注释
        page.removeAnnotation(annotation)
        
        // 通知更新（触发保存）
        NotificationCenter.default.post(name: NSNotification.Name("PDFAnnotationUpdated"), object: nil)
        
        // 清除高亮
        clearNoteHighlight()
        DispatchQueue.main.async {
            self.onClearHighlight?()
        }
    }
    
    // 设置选择框数据
    func setSelectionData(multiPageSelection: MultiPageSelection, document: PDFDocument, isSelectionMode: Bool) {
        // 确保选择框覆盖层存在
        if selectionOverlay == nil {
            setupSelectionOverlay()
        }
        
        // 更新选择模式状态（控制是否允许删除）
        selectionOverlay?.isSelectionMode = isSelectionMode
        
        // 更新选择框数据
        selectionOverlay?.updateSelections(multiPageSelection: multiPageSelection, document: document, pdfView: self)
    }
    
    // 设置注释模式（临时隐藏覆盖层以允许注释显示）
    func setAnnotationMode(_ isAnnotationMode: Bool) {
        // 在注释模式下，临时隐藏覆盖层以避免遮挡注释渲染
        selectionOverlay?.isHidden = isAnnotationMode
    }
    
    // 清除选择框
    func clearSelections() {
        selectionOverlay?.clearSelections()
    }
    
    // 设置删除回调
    func setDeleteCallback(_ callback: @escaping (UUID) -> Void) {
        selectionOverlay?.onDeleteRegion = callback
    }
    
    // 设置选择框覆盖层
    private func setupSelectionOverlay() {
        let overlay = PDFInternalSelectionOverlay()
        
        // 关键：确保frame和bounds对齐，坐标系一致
        overlay.frame = self.bounds
        overlay.autoresizingMask = [.width, .height] // 自动调整大小以匹配PDFView
        
        // 添加到PDFView内部，作为子视图
        // 使用positioned: .above确保在最上层，但不遮挡滚动条
        self.addSubview(overlay, positioned: .above, relativeTo: nil)
        
        // 设置PDFView引用（这会设置监听）
        overlay.setPDFView(self)
        
        selectionOverlay = overlay
        
        // 确保frame正确设置（延迟一点，确保bounds已经正确）
        DispatchQueue.main.async { [weak self, weak overlay] in
            guard let self = self, let overlay = overlay else { return }
            overlay.frame = self.bounds
        }
    }
    
    // 当bounds变化时，更新选择框覆盖层的frame
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        // 使用autoresizingMask自动调整，但为了确保同步，也手动更新
        selectionOverlay?.frame = self.bounds
        // 触发选择框更新（因为bounds变化可能影响坐标）
        if let overlay = selectionOverlay,
           let multiPageSelection = overlay.multiPageSelection,
           let document = overlay.document {
            // 保持当前的 isSelectionMode 状态
            overlay.updateSelections(multiPageSelection: multiPageSelection, document: document, pdfView: self)
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        selectionOverlay?.frame = self.bounds
        // 触发选择框更新
        if let overlay = selectionOverlay,
           let multiPageSelection = overlay.multiPageSelection,
           let document = overlay.document {
            overlay.updateSelections(multiPageSelection: multiPageSelection, document: document, pdfView: self)
        }
    }
    
    // 当视图布局变化时，确保选择框覆盖层frame正确
    override func layout() {
        super.layout()
        // 确保选择框覆盖层的frame始终和PDFView的bounds对齐
        if let overlay = selectionOverlay {
            overlay.frame = self.bounds
        }
    }
    
    // 跳转到指定的注释位置并高亮显示（支持所有注释类型）
    func jumpToNote(_ annotation: Annotation) {
        guard let document = self.document,
              annotation.pageIndex < document.pageCount,
              let page = document.page(at: annotation.pageIndex) else {
            return
        }
        
        // 跳转到指定页面
        self.go(to: page)
        
        // 找到对应的PDFAnnotation（支持所有注释类型）
        let rect = annotation.rect
        var foundAnnotation: PDFAnnotation? = nil
        
        // 将AnnotationType转换为PDF注释类型字符串
        let targetType: String
        switch annotation.type {
        case .textNote:
            targetType = "Text"
        case .highlight:
            targetType = "Highlight"
        case .underline:
            targetType = "Underline"
        case .strikeout:
            targetType = "StrikeOut"
        default:
            targetType = "Text" // 默认
        }
        
        for pdfAnnotation in page.annotations {
            let annotationType = pdfAnnotation.type ?? ""
            let normalizedType = annotationType.hasPrefix("/") ? String(annotationType.dropFirst()) : annotationType
            
            // 检查类型和位置是否匹配
            if normalizedType == targetType || normalizedType == PDFAnnotationSubtype.text.rawValue ||
               (targetType == "Highlight" && normalizedType == PDFAnnotationSubtype.highlight.rawValue) ||
               (targetType == "Underline" && normalizedType == PDFAnnotationSubtype.underline.rawValue) ||
               (targetType == "StrikeOut" && normalizedType == PDFAnnotationSubtype.strikeOut.rawValue) {
                let bounds = pdfAnnotation.bounds
                // 检查位置是否匹配（允许1.0的误差）
                if abs(bounds.origin.x - rect.origin.x) < 1.0 &&
                   abs(bounds.origin.y - rect.origin.y) < 1.0 {
                    foundAnnotation = pdfAnnotation
                    break
                }
            }
        }
        
        if let found = foundAnnotation {
            // 延迟一点显示高亮，确保页面已经跳转完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showNoteHighlight(annotation: found, on: page)
            }
        }
    }
    
    // 显示note高亮
    func showNoteHighlight(annotation: PDFAnnotation, on page: PDFPage) {
        // 如果点击的是同一个note，不重复高亮
        if highlightedPDFAnnotation === annotation && highlightLayer != nil {
            return
        }
        
        // 清除之前的高亮
        clearNoteHighlight()
        
        // 保存当前高亮的annotation
        highlightedPDFAnnotation = annotation
        
        // 将页面坐标转换为视图坐标
        let viewRect = self.convert(annotation.bounds, from: page)
        
        // 创建高亮层
        let layer = CALayer()
        layer.borderColor = NSColor.systemBlue.cgColor
        layer.borderWidth = 3.0
        layer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
        layer.frame = viewRect
        layer.cornerRadius = 4.0
        
        // 添加到PDFView的layer
        if let pdfLayer = self.layer {
            pdfLayer.addSublayer(layer)
            highlightLayer = layer
        }
        
        // 不再自动取消高亮，只有点击其他地方时才清除
    }
    
    // 清除note高亮
    func clearNoteHighlight() {
        highlightLayer?.removeFromSuperlayer()
        highlightLayer = nil
        highlightTimer?.invalidate()
        highlightTimer = nil
        highlightedPDFAnnotation = nil
    }
    
    // 清理资源
    deinit {
        selectionOverlay?.removeFromSuperview()
        selectionOverlay = nil
        clearNoteHighlight()
    }
}

// 透明覆盖层视图（使用全局事件监听器捕获鼠标事件并绘制选择框）
struct SelectionOverlayView: NSViewRepresentable {
    @Binding var selectionStart: CGPoint?
    @Binding var selectionEnd: CGPoint?
    @Binding var isSelecting: Bool
    @Binding var multiPageSelection: MultiPageSelection
    let document: PDFDocument
    @Binding var pdfView: PDFView?
    let isSelectionMode: Bool
    let onSelectionComplete: (CGPoint, CGPoint) -> Void
    
    func makeNSView(context: Context) -> SelectionOverlayNSView {
        let view = SelectionOverlayNSView()
        view.pdfView = pdfView
        view.onMouseDown = { location in
            selectionStart = location
            selectionEnd = location
            isSelecting = true
            view.updateSelection(start: location, end: location, isSelecting: true)
        }
        view.onMouseDragged = { location in
            if isSelecting, let start = selectionStart {
                selectionEnd = location
                view.updateSelection(start: start, end: location, isSelecting: true)
            }
        }
        view.onMouseUp = { location in
            if isSelecting, let start = selectionStart {
                selectionEnd = location
                // 先完成选择（添加到multiPageSelection），再清除临时选择层
                // 这样可以避免闪烁
                onSelectionComplete(start, location)
                // 延迟清除临时选择层，确保持久选择层已经显示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    view.updateSelection(start: start, end: location, isSelecting: false)
                }
                isSelecting = false
                selectionStart = nil
                selectionEnd = nil
            }
        }
        // 设置选择模式状态
        view.setSelectionMode(isSelectionMode)
        // SelectionOverlayNSView不再负责显示持久选择，由PersistentSelectionOverlay负责
        return view
    }
    
    func updateNSView(_ nsView: SelectionOverlayNSView, context: Context) {
        // 更新PDFView引用
        nsView.pdfView = pdfView
        
        // 更新选择模式状态（关键：确保状态同步）
        // 如果 isSelectionMode 为 false，强制清理所有状态
        nsView.setSelectionMode(isSelectionMode)
        
        // 如果不在选择模式，确保清理所有选择状态
        if !isSelectionMode {
            // 清除临时选择层
            nsView.updateSelection(start: .zero, end: .zero, isSelecting: false)
            // 确保事件监听器被移除
            // setSelectionMode(false) 应该已经处理了，但这里再次确认
        }
        
        // 更新闭包引用
        nsView.onMouseDown = { location in
            selectionStart = location
            selectionEnd = location
            isSelecting = true
            nsView.updateSelection(start: location, end: location, isSelecting: true)
        }
        nsView.onMouseDragged = { location in
            if isSelecting, let start = selectionStart {
                selectionEnd = location
                nsView.updateSelection(start: start, end: location, isSelecting: true)
            }
        }
        nsView.onMouseUp = { location in
            if isSelecting, let start = selectionStart {
                selectionEnd = location
                // 先完成选择（添加到multiPageSelection），再清除临时选择层
                // 这样可以避免闪烁
                onSelectionComplete(start, location)
                // 延迟清除临时选择层，确保持久选择层已经显示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    nsView.updateSelection(start: start, end: location, isSelecting: false)
                }
                isSelecting = false
                selectionStart = nil
                selectionEnd = nil
            }
        }
        
        // 同步当前状态
        if let start = selectionStart, let end = selectionEnd {
            nsView.updateSelection(start: start, end: end, isSelecting: isSelecting)
        }
        
        // SelectionOverlayNSView不再负责显示持久选择，由PersistentSelectionOverlay负责
    }
    
    static func dismantleNSView(_ nsView: SelectionOverlayNSView, coordinator: ()) {
        // 当 SwiftUI 移除视图时，确保完全清理
        nsView.setSelectionMode(false)
        // 强制移除事件监听器
        if let monitor = nsView.eventMonitor {
            NSEvent.removeMonitor(monitor)
            nsView.eventMonitor = nil
        }
    }
}

// NSView透明覆盖层（使用全局事件监听器捕获鼠标事件，不拦截任何事件）
class SelectionOverlayNSView: NSView {
    weak var pdfView: PDFView?
    var onMouseDown: ((CGPoint) -> Void)?
    var onMouseDragged: ((CGPoint) -> Void)?
    var onMouseUp: ((CGPoint) -> Void)?
    
    private var selectionLayer: CALayer?
    private var isSelecting: Bool = false
    var eventMonitor: Any? // 改为公开，以便 dismantleNSView 访问
    private var isSelectionMode: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func setSelectionMode(_ enabled: Bool) {
        let wasEnabled = isSelectionMode
        isSelectionMode = enabled
        
        if enabled {
            // 如果之前没有启用，现在启用
            if !wasEnabled {
                setupGlobalEventMonitor()
            }
        } else {
            // 如果之前已启用，现在禁用，确保完全清理
            if wasEnabled {
                removeGlobalEventMonitor()
                // 清除临时选择状态
                isSelecting = false
                updateSelection(start: .zero, end: .zero, isSelecting: false)
            }
        }
    }
    
    private func setupGlobalEventMonitor() {
        // 使用全局事件监听器捕获鼠标事件
        // 关键：只处理PDFView区域内的鼠标事件，其他区域（菜单栏、问答区域、Sheet窗口）的事件直接传递
        
        // 先移除旧的监听器（如果存在）
        if let oldMonitor = eventMonitor {
            NSEvent.removeMonitor(oldMonitor)
        }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self else {
                return event // self 已释放，让事件正常传递
            }
            
            // 关键检查：必须在选择模式下才处理
            guard self.isSelectionMode else {
                return event // 不在选择模式，让事件正常传递
            }
            
            guard let pdfView = self.pdfView else {
                return event // PDFView 不存在，让事件正常传递
            }
            
            // 检查鼠标是否在PDFView范围内
            guard let pdfWindow = pdfView.window else {
                return event
            }
            
            // 关键：检查事件是否来自Sheet窗口（如模型选择器）
            // 如果事件来自其他窗口（如Sheet），直接让事件正常传递，不拦截
            if let eventWindow = event.window, eventWindow != pdfWindow {
                return event // 事件来自其他窗口（如Sheet），让事件正常传递
            }
            
            let mouseLocation = event.locationInWindow
            let viewLocation = pdfView.convert(mouseLocation, from: nil)
            
            // 关键：只处理PDFView bounds内的事件
            // 如果不在PDFView范围内（如菜单栏、问答区域），直接让事件正常传递
            guard pdfView.bounds.contains(viewLocation) else {
                return event // 不在PDFView范围内，让事件正常传递
            }
            
            // 关键：检查是否点击在工具栏按钮区域（顶部区域，约70px高度）
            // 工具栏悬浮在PDFView上方，按钮区域需要让事件正常传递
            // 注意：NSView坐标系y=0在底部，所以顶部区域是y值较大的区域
            // 工具栏实际内容高度约50-60px，加上顶部padding 12px，总共约70px
            // 只检查工具栏实际内容区域，不包括阴影区域，这样工具栏附近区域可以正常框选
            let toolbarContentHeight: CGFloat = 70
            if viewLocation.y > pdfView.bounds.height - toolbarContentHeight {
                // 检查是否在工具栏的水平范围内（工具栏有左右padding 12px）
                // 工具栏大约占据中间区域，左右各留12px padding
                let toolbarHorizontalPadding: CGFloat = 12
                if viewLocation.x >= toolbarHorizontalPadding && 
                   viewLocation.x <= pdfView.bounds.width - toolbarHorizontalPadding {
                    return event // 点击在工具栏内容区域，让事件正常传递到工具栏按钮
                }
                // 如果不在工具栏水平范围内，继续处理框选（允许在工具栏附近框选）
            }
            
            // 检查是否点击了滚动条区域
            if let scrollView = pdfView.enclosingScrollView {
                let scrollViewPoint = scrollView.convert(mouseLocation, from: nil)
                let scrollViewBounds = scrollView.bounds
                
                // 检查垂直滚动条
                if scrollView.hasVerticalScroller {
                    let scrollerWidth: CGFloat = 15
                    if scrollViewPoint.x > scrollViewBounds.width - scrollerWidth {
                        return event // 点击了滚动条，让事件正常传递
                    }
                }
                
                // 检查水平滚动条
                if scrollView.hasHorizontalScroller {
                    let scrollerHeight: CGFloat = 15
                    if scrollViewPoint.y < scrollerHeight {
                        return event // 点击了滚动条，让事件正常传递
                    }
                }
            }
            
            // 检查是否点击在选择框上（通过检查PDFInternalSelectionOverlay）
            // 如果点击在选择框上，让事件继续传播到PDFInternalSelectionOverlay处理删除
            if event.type == .leftMouseDown {
                if let customPDFView = pdfView as? CustomPDFView,
                   let selectionOverlay = customPDFView.selectionOverlay {
                    let overlayPoint = selectionOverlay.convert(mouseLocation, from: nil)
                    // 检查是否点击在选择框上
                    if selectionOverlay.hitTest(overlayPoint) != nil {
                        // 点击在选择框上，让事件继续传播到PDFInternalSelectionOverlay处理删除
                        // 不拦截事件，让PDFInternalSelectionOverlay的mouseDown处理
                        return event
                    }
                }
            }
            
            // 在PDF内容区域内，处理选择
            let location = self.convert(mouseLocation, from: nil)
            
            switch event.type {
            case .leftMouseDown:
                self.isSelecting = true
                self.onMouseDown?(location)
                // 阻止事件继续传播（因为我们要处理选择）
                return nil
                
            case .leftMouseDragged:
                if self.isSelecting {
                    self.onMouseDragged?(location)
                    // 阻止事件继续传播
                    return nil
                }
                return event
                
            case .leftMouseUp:
                if self.isSelecting {
                    self.onMouseUp?(location)
                    self.isSelecting = false
                    // 阻止事件继续传播
                    return nil
                }
                return event
                
            default:
                return event
            }
        }
    }
    
    private func removeGlobalEventMonitor() {
        // 确保完全移除事件监听器
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        // 清除所有选择状态
        isSelecting = false
        // 清除临时选择层
        updateSelection(start: .zero, end: .zero, isSelecting: false)
    }
    
    // 完全不拦截任何事件，让所有事件穿透
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // 让所有事件穿透到下层视图
    }
    
    // 确保不成为第一响应者
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    deinit {
        // 强制移除事件监听器（确保完全清理）
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        // 清除所有状态
        isSelecting = false
        updateSelection(start: .zero, end: .zero, isSelecting: false)
    }
    
    func updateSelection(start: CGPoint, end: CGPoint, isSelecting: Bool) {
        if !isSelecting {
            selectionLayer?.removeFromSuperlayer()
            selectionLayer = nil
            return
        }
        
        // 创建或更新选择层
        if selectionLayer == nil {
            let layer = CALayer()
            layer.borderColor = NSColor.systemBlue.cgColor
            layer.borderWidth = 2.0
            layer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
            self.layer?.addSublayer(layer)
            selectionLayer = layer
        }
        
        guard let layer = selectionLayer else { return }
        
        // 计算矩形（使用视图坐标系统）
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        
        let rect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
        
        // 禁用动画，立即更新
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = rect
        CATransaction.commit()
    }
    
}

// PDFView内部的选择框覆盖层（直接添加到PDFView内部，坐标系一致）
class PDFInternalSelectionOverlay: NSView {
    private var selectionLayers: [CALayer] = []
    private var layerToRegionId: [CALayer: UUID] = [:] // 映射layer到region ID
    private var pdfView: PDFView?
    // 注意：这些属性需要可以被CustomPDFView访问，用于bounds变化时更新
    var multiPageSelection: MultiPageSelection?
    var document: PDFDocument?
    var onDeleteRegion: ((UUID) -> Void)? // 删除区域的回调
    var isSelectionMode: Bool = false // 是否在选择模式下（控制是否允许删除）
    private var scaleObserver: NSKeyValueObservation?
    private var boundsObserver: NSKeyValueObservation?
    private var notificationObserver: NSObjectProtocol?
    private var updateTimer: Timer?
    private var lastBounds: CGRect = .zero
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // 关键：确保覆盖层不遮挡底层PDFView的注释渲染
        // 设置isOpaque为false，允许底层内容显示
        // 注意：NSView没有isOpaque属性，但可以通过layer的opacity和背景色控制
        layer?.opacity = 1.0 // 保持不透明以显示选择框，但不影响底层PDFView
        
        // 确保不拦截任何事件
        // 选择框只是用于显示，不处理交互
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 如果不在选择模式，不允许删除，让事件穿透
        guard isSelectionMode else {
            return nil
        }
        
        // 检查点击是否在选择框内
        // 如果点击在选择框上，返回self以处理点击事件
        // 否则返回nil让事件穿透到PDFView
        
        // 检查是否点击在任何选择框上
        for (layer, _) in layerToRegionId {
            // 将point转换为layer的坐标系
            let layerPoint = self.layer?.convert(point, to: layer)
            if let layerPoint = layerPoint, layer.bounds.contains(layerPoint) {
                return self // 点击在选择框上，返回self处理
            }
        }
        
        // 没有点击在选择框上，让事件穿透
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        // 如果不在选择模式，不允许删除，传递给下层视图
        guard isSelectionMode else {
            super.mouseDown(with: event)
            return
        }
        
        let point = self.convert(event.locationInWindow, from: nil)
        
        // 检查点击是否在选择框内
        for (layer, regionId) in layerToRegionId {
            // 将point转换为layer的坐标系
            let layerPoint = self.layer?.convert(point, to: layer)
            if let layerPoint = layerPoint, layer.bounds.contains(layerPoint) {
                // 点击在选择框上，删除该区域
                onDeleteRegion?(regionId)
                return
            }
        }
        
        // 没有点击在选择框上，传递给下层视图
        super.mouseDown(with: event)
    }
    
    // 确保frame始终和PDFView的bounds对齐
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let pdfView = superview as? PDFView {
            // 确保frame和PDFView的bounds对齐
            self.frame = pdfView.bounds
            // 设置autoresizingMask确保自动调整
            self.autoresizingMask = [.width, .height]
        }
    }
    
    // 当superview的bounds变化时，更新自己的frame
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        if let pdfView = superview as? PDFView {
            self.frame = pdfView.bounds
        }
    }
    
    func setPDFView(_ pdfView: PDFView?) {
        // 方案3：强制重新设置监听器
        // 即使PDFView没有改变，也重新设置监听器，确保它们被正确设置
        
        // 停止旧的定时器
        stopUpdateTimer()
        
        // 移除旧的观察者
        scaleObserver?.invalidate()
        scaleObserver = nil
        boundsObserver?.invalidate()
        boundsObserver = nil
        
        // 移除通知观察者
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        
        self.pdfView = pdfView
        
        // 监听PDFView的scaleFactor变化（缩放）
        if let pdfView = pdfView {
            scaleObserver = pdfView.observe(\.scaleFactor, options: [.new, .old]) { [weak self] _, _ in
                // PDF缩放时，更新选择框位置
                DispatchQueue.main.async {
                    self?.updateSelectionsFromCache()
                }
            }
            
            // 监听PDFView的滚动变化
            // 方案：使用多种方式监听，不依赖 enclosingScrollView
            // 方法1: 如果 ScrollView 存在，使用 KVO 和通知监听
            if let scrollView = pdfView.enclosingScrollView {
                let contentView = scrollView.contentView
                
                // 关键：启用bounds变化通知（每次设置时都确保启用）
                contentView.postsBoundsChangedNotifications = true
                
                // 方法1: 使用KVO监听bounds变化
                boundsObserver = contentView.observe(\.bounds, options: [.new, .old]) { [weak self] _, _ in
                    // PDF滚动时，更新选择框位置
                    DispatchQueue.main.async {
                        self?.updateSelectionsFromCache()
                    }
                }
                
                // 方法2: 使用通知监听滚动事件
                notificationObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: contentView,
                    queue: .main
                ) { [weak self] _ in
                    self?.updateSelectionsFromCache()
                }
            }
            
            // 方法3: 使用Timer定期检查并更新（最可靠的方法，不依赖 ScrollView）
            // 使用 PDFView 的 visibleRect 来检测滚动
            setupUpdateTimer()
        }
    }
    
    // 清除所有选择框
    func clearSelections() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.selectionLayers.forEach { $0.removeFromSuperlayer() }
            self.selectionLayers.removeAll()
            self.multiPageSelection = nil
        }
    }
    
    private func setupUpdateTimer() {
        // 使用Timer定期检查并更新选择框位置
        // 这是最可靠的方法，可以捕获所有滚动和缩放变化
        // 注意：lastBounds 的初始化将在 updateSelectionsInternal 中完成
        // 这里不初始化，避免在PDFView未完全布局时设置错误的值
        
        // 停止旧的定时器（如果存在）
        stopUpdateTimer()
        
        // 创建定时器，每帧检查一次（约60fps）
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.checkAndUpdateSelections()
        }
        
        // 将定时器添加到RunLoop的common模式，确保在滚动时也能触发
        if let timer = updateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func checkAndUpdateSelections() {
        // 方案：直接重新计算所有选择框的位置，不依赖滚动检测
        // 因为 pdfView.convert() 会自动考虑当前的滚动位置
        // 所以每次调用时都会返回正确的坐标
        // 这是最可靠的方法，可以确保选择框始终跟随PDF内容
        
        guard let pdfView = pdfView,
              let multiPageSelection = multiPageSelection,
              let document = document else {
            return
        }
        
        // 直接更新所有选择框的位置
        // 不检查滚动变化，因为 pdfView.convert() 已经考虑了滚动
        updateSelectionsFromCache()
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateSelectionsFromCache() {
        guard let multiPageSelection = multiPageSelection,
              let document = document,
              let pdfView = pdfView else {
            return
        }
        
        // 直接更新，不重新设置缓存
        updateSelectionsInternal(multiPageSelection: multiPageSelection, document: document, pdfView: pdfView)
    }
    
    func updateSelections(multiPageSelection: MultiPageSelection, document: PDFDocument, pdfView: PDFView) {
        // 缓存数据，用于缩放时更新
        self.multiPageSelection = multiPageSelection
        self.document = document
        
        // 确保frame和PDFView的bounds对齐（关键！）
        if self.superview === pdfView {
            self.frame = pdfView.bounds
        }
        
        // 方案3：强制在每次更新时重新设置监听器，确保监听器被正确设置
        // 不检查 self.pdfView !== pdfView，每次都调用 setPDFView()
        // 这样可以确保监听器始终被正确设置，即使PDFView没有改变
        setPDFView(pdfView)
        
        // 延迟初始化 lastBounds，确保在PDFView完全布局后再初始化
        // 使用 DispatchQueue.main.async 延迟到下一个runloop执行
        // 使用 PDFView 的 visibleRect，不依赖 enclosingScrollView
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let visibleRect = pdfView.visibleRect
            // 确保visibleRect是有效的（宽度和高度都大于0）
            if visibleRect.width > 0 && visibleRect.height > 0 {
                self.lastBounds = visibleRect
            }
        }
        
        // 更新选择层
        updateSelectionsInternal(multiPageSelection: multiPageSelection, document: document, pdfView: pdfView)
    }
    
    private func updateSelectionsInternal(multiPageSelection: MultiPageSelection, document: PDFDocument, pdfView: PDFView) {
        // 方案4：同步执行坐标转换，不使用异步延迟
        // 确保在主线程上立即执行，避免时序问题
        
        // 确保在主线程执行
        if Thread.isMainThread {
            updateSelectionsInternalSync(multiPageSelection: multiPageSelection, document: document, pdfView: pdfView)
        } else {
            // 如果不在主线程，使用 sync 确保立即执行
            DispatchQueue.main.sync { [weak self] in
                guard let self = self else { return }
                self.updateSelectionsInternalSync(multiPageSelection: multiPageSelection, document: document, pdfView: pdfView)
            }
        }
    }
    
    private func updateSelectionsInternalSync(multiPageSelection: MultiPageSelection, document: PDFDocument, pdfView: PDFView) {
        // 清除所有旧层和映射
        self.selectionLayers.forEach { $0.removeFromSuperlayer() }
        self.selectionLayers.removeAll()
        self.layerToRegionId.removeAll()
        
        // 确保self.frame和pdfView.bounds对齐（关键！）
        // 这确保坐标系一致
        if self.superview === pdfView {
            self.frame = pdfView.bounds
        }
        
        // 为每个已选择的区域创建显示层
        for region in multiPageSelection.regions {
            guard let page = document.page(at: region.pageIndex) else { continue }
            
            // 将PDF页面坐标转换为PDFView的视图坐标
            // pdfView.convert(region.rect, from: page) 返回的坐标是相对于PDFView的bounds的
            let viewRect = pdfView.convert(region.rect, from: page)
            
            // 放宽视图范围检查：只要矩形有效（不为空）就显示
            // 因为PDF可能是连续滚动模式，区域可能暂时不在可见范围内
            guard !viewRect.isNull && !viewRect.isInfinite && viewRect.width > 0 && viewRect.height > 0 else {
                continue
            }
            
            // 关键：由于PDFInternalSelectionOverlay是PDFView的直接子视图
            // 且self.frame和pdfView.bounds对齐，所以viewRect可以直接用作layer.frame
            // layer.frame是相对于self.layer的，而self.frame和pdfView.bounds对齐，所以坐标系一致
            let layer = CALayer()
            layer.borderColor = NSColor.systemBlue.withAlphaComponent(0.7).cgColor
            layer.borderWidth = 1.5
            layer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
            layer.frame = viewRect
            
            // 使用CATransaction禁用动画，立即更新
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.layer?.addSublayer(layer)
            CATransaction.commit()
            
            self.selectionLayers.append(layer)
            // 存储layer到region ID的映射，用于点击检测
            self.layerToRegionId[layer] = region.id
        }
        
        // 方案：使用 PDFView 的 visibleRect 来初始化 lastBounds，不依赖 enclosingScrollView
        // visibleRect 是 PDFView 当前可见区域的矩形，即使 ScrollView 不存在也能使用
        let currentVisibleRect = pdfView.visibleRect
        
        // 检查 visibleRect 是否有效（避免无效值）
        let isValidRect = currentVisibleRect.width > 0 && 
                         currentVisibleRect.height > 0 &&
                         currentVisibleRect.width < 100000 &&
                         currentVisibleRect.height < 100000 &&
                         abs(currentVisibleRect.origin.x) < 100000 &&
                         abs(currentVisibleRect.origin.y) < 100000
        
        if isValidRect {
            self.lastBounds = currentVisibleRect
        } else {
            // 如果 visibleRect 无效，使用 bounds 作为备用
            let bounds = pdfView.bounds
            if bounds.width > 0 && bounds.height > 0 {
                self.lastBounds = bounds
            }
        }
    }
    
    deinit {
        stopUpdateTimer()
        scaleObserver?.invalidate()
        boundsObserver?.invalidate()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - PDFReaderView扩展：Note编辑相关方法

extension PDFReaderView {
    /// 处理Note编辑请求
    // 注意：handleNoteEditRequest 和 saveNoteContent 已移除，改为在MainView中处理
}
