//
// MainView.swift
// HyperPaper
//
// 主视图：整合PDF阅读器和问答功能
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct MainView: View {
    @State private var pdfDocument: PDFDocument?
    @State private var pdfFileURL: URL? // 存储原始PDF文件URL，用于保存注释
    @State private var selectedText: String = ""
    @State private var showFilePicker: Bool = false
    @State private var showQuestionAnswer: Bool = false
    @State private var isQuestionAnswerCollapsed: Bool = false // 问答面板是否折叠
    @State private var isSelectionMode: Bool = false // 框选模式开关
    @State private var showPreferences: Bool = false // 偏好设置窗口
    @StateObject private var apiService = QwenAPIService() // API服务实例
    @State private var contentMode: ContentMode = .agent // 内容模式：Agent模式或批注模式
    @State private var selectedAnnotationTool: AnnotationTool = .none // 选中的注释工具
    @State private var selectedAnnotationColor: Color = .yellow // 选中的注释颜色（默认黄色）
    
    // Note编辑相关状态
    @State private var selectedNoteAnnotation: PDFAnnotation? = nil // 当前选中的note注释（用于在批注功能区域显示）
    @State private var noteToJumpTo: Annotation? = nil // 需要跳转到的note（从批注功能区域点击）
    @State private var selectedAnnotationId: UUID? = nil // 当前选中的注释ID（用于在注释区域高亮显示）
    
    var body: some View {
        // 主体区域：左侧PDF + 右侧问答
        HSplitView {
            // 左侧：PDF展示、交互、框选的区域 + 悬浮工具栏
            ZStack(alignment: .topLeading) {
                // 底层：PDF视图（占据整个区域）
                if let document = pdfDocument {
                    PDFReaderView(
                        document: document,
                        selectedText: $selectedText,
                        isSelectionMode: $isSelectionMode,
                        selectedAnnotationTool: $selectedAnnotationTool,
                        selectedAnnotationColor: $selectedAnnotationColor,
                        onAnnotationCreated: {
                            // 注释创建后自动保存PDF
                            print("📝 MainView: 收到注释创建回调")
                            self.savePDFDocument()
                        },
                        onNoteEditRequested: { annotation in
                            // Note编辑请求：跳转到批注功能区域
                            handleNoteEditRequest(annotation: annotation)
                        },
                        noteToJumpTo: noteToJumpTo,
                        onClearHighlight: {
                            // 清除所有高亮
                            selectedAnnotationId = nil
                            selectedNoteAnnotation = nil
                        },
                        onPDFScroll: { pdfAnnotation in
                            // PDF滚动回调：根据PDFAnnotation找到对应的Annotation ID
                            handlePDFScroll(pdfAnnotation: pdfAnnotation)
                        }
                    )
                    .onChange(of: noteToJumpTo) { oldValue, newValue in
                        // 当noteToJumpTo变化时，延迟一点后清除（让PDFView有时间处理跳转）
                        if newValue != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                noteToJumpTo = nil
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AnnotationCreatedResetTool"))) { _ in
                        // 注释创建后，自动恢复非注释模式
                        selectedAnnotationTool = .none
                    }
                    .frame(minWidth: 400)
                } else {
                    // 空状态：提示打开文件
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("打开PDF文件")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Button("选择PDF文件") {
                            showFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // 顶层：悬浮工具栏
                FloatingToolbar(
                    pdfDocument: $pdfDocument,
                    isSelectionMode: $isSelectionMode,
                    selectedText: $selectedText,
                    showFilePicker: $showFilePicker,
                    showPreferences: $showPreferences,
                    contentMode: $contentMode,
                    selectedAnnotationTool: $selectedAnnotationTool,
                    selectedAnnotationColor: $selectedAnnotationColor,
                    onClearSelection: clearAllSelections
                )
            }
            
            // 右侧：问答区域
            if isQuestionAnswerCollapsed {
                // 折叠状态：显示一个窄的按钮条
                VStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isQuestionAnswerCollapsed = false
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .help("展开问答面板")
                }
                .frame(width: 20)
                .background(Color(NSColor.controlBackgroundColor))
            } else if showQuestionAnswer || pdfDocument == nil {
                // 展开状态：显示完整的问答面板（占据整个右侧页面）
                ZStack(alignment: .top) {
                    // 内容区域（不使用外层 ScrollView，避免嵌套问题）
                    // 注意：AnnotationModeView 和 QuestionAnswerViewWrapper 内部已经有自己的滚动机制
                    VStack(spacing: 0) {
                        // 顶部 padding，让内容从 bar 下方滑过
                        // Mode switch toolbar 高度约为 70px（包括 padding），添加 80px 的 padding
                        Spacer()
                            .frame(height: 80)
                        
                        // 根据模式显示不同内容
                        if contentMode == .agent {
                            // Agent模式：显示问答功能
                            QuestionAnswerViewWrapper(selectedText: $selectedText)
                        } else {
                            // 批注模式：显示批注管理
                            // 注意：AnnotationModeView 内部已经有 ScrollView，不需要外层再包一层
                            AnnotationModeView(
                                pdfDocument: $pdfDocument,
                                selectedNoteAnnotation: $selectedNoteAnnotation,
                                selectedAnnotationId: $selectedAnnotationId,
                                onNoteTap: { annotation in
                                    // 从批注功能区域点击note时，跳转到PDF区域
                                    selectedAnnotationId = annotation.id // 高亮选中的注释
                                    noteToJumpTo = annotation
                                },
                                onAnnotationDelete: { annotation in
                                    // 注释删除后，清除选中状态
                                    if selectedAnnotationId == annotation.id {
                                        selectedAnnotationId = nil
                                    }
                                    if let pdfAnnotation = selectedNoteAnnotation,
                                       let page = pdfAnnotation.page,
                                       let document = pdfDocument,
                                       document.index(for: page) == annotation.pageIndex {
                                        selectedNoteAnnotation = nil
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 悬浮的模式切换栏（与PDF区域的bar位置对齐）
                    ModeSwitchToolbar(
                        currentMode: $contentMode,
                        onCollapse: {
                            isQuestionAnswerCollapsed = true
                        }
                    )
                }
                .frame(minWidth: 400, idealWidth: 400, maxWidth: 600)
            } else {
                // 提示打开问答面板
                VStack(spacing: 20) {
                    Image(systemName: "questionmark.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("点击\"显示问答\"按钮\n开始与文档交互")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("显示问答") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showQuestionAnswer = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(minWidth: 300, idealWidth: 400, maxWidth: 600)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadPDF(from: url)
                }
            case .failure(let error):
                print("文件选择错误: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PDFAnnotationUpdated"))) { _ in
            // 当注释内容更新时，保存PDF
            self.savePDFDocument()
        }
    }
    
    private func clearAllSelections() {
        selectedText = ""
        // 不需要强制刷新PDFReaderView，直接清除selectedText即可
        // PDFReaderView会通过onChange(of: selectedText)自动清除内部选择
    }
    
    private func loadPDF(from url: URL) {
        // 获取访问权限
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        if let document = PDFDocument(url: url) {
            self.pdfDocument = document
            self.pdfFileURL = url // 保存原始文件URL
            self.selectedText = ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showQuestionAnswer = true
                self.isQuestionAnswerCollapsed = false
            }
        } else {
            print("无法加载PDF文件")
        }
    }
    
    /// 保存PDF文档（包含注释）到原始文件
    private func savePDFDocument() {
        guard let document = pdfDocument,
              let fileURL = pdfFileURL else {
            print("❌ PDF保存失败: 文档或文件URL为空")
            print("   - pdfDocument: \(pdfDocument != nil)")
            print("   - pdfFileURL: \(pdfFileURL?.path ?? "nil")")
            return
        }
        
        print("📝 开始保存PDF: \(fileURL.path)")
        print("   - 文件存在: \(FileManager.default.fileExists(atPath: fileURL.path))")
        print("   - 可写: \(FileManager.default.isWritableFile(atPath: fileURL.path))")
        
        // 获取文件访问权限
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        print("   - 安全作用域访问: \(hasAccess)")
        
        defer {
            if hasAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // 尝试保存PDF到文件
        // 注意：write(to:) 方法可能在某些情况下失败但不抛出异常
        let success = document.write(to: fileURL)
        
        if success {
            print("✅ PDF已成功保存（包含注释）: \(fileURL.path)")
            
            // 验证文件是否真的被更新了
            if let savedDocument = PDFDocument(url: fileURL) {
                var totalAnnotations = 0
                for i in 0..<savedDocument.pageCount {
                    if let page = savedDocument.page(at: i) {
                        totalAnnotations += page.annotations.count
                    }
                }
                print("   - 验证: 保存后的PDF包含 \(totalAnnotations) 个注释")
            }
        } else {
            print("❌ PDF保存失败: \(fileURL.path)")
            print("   尝试使用dataRepresentation方法...")
            
            // 备用方法：使用dataRepresentation
            if let data = document.dataRepresentation() {
                do {
                    try data.write(to: fileURL, options: .atomic)
                    print("✅ PDF已通过dataRepresentation方法保存: \(fileURL.path)")
                } catch {
                    print("❌ dataRepresentation保存也失败: \(error.localizedDescription)")
                }
            } else {
                print("❌ 无法获取PDF的dataRepresentation")
            }
        }
    }
    
    /// 处理Note编辑请求
    private func handleNoteEditRequest(annotation: PDFAnnotation) {
        print("📝 MainView: 收到Note编辑请求")
        // 切换到批注模式
        contentMode = .annotation
        // 设置选中的note注释（这会触发AnnotationModeView的onChange，自动同步并滚动）
        selectedNoteAnnotation = annotation
        
        // 根据PDFAnnotation找到对应的Annotation ID，用于高亮显示
        if let page = annotation.page, let document = pdfDocument {
            let pageIndex = document.index(for: page)
            let bounds = annotation.bounds
            // 这里需要从AnnotationModeView获取对应的Annotation ID
            // 暂时设置为nil，由AnnotationModeView在onChange中处理
        }
    }
    
    /// 处理PDF滚动：根据PDFAnnotation找到对应的Annotation ID并高亮（优化响应速度）
    private func handlePDFScroll(pdfAnnotation: PDFAnnotation?) {
        guard let pdfAnnotation = pdfAnnotation,
              let page = pdfAnnotation.page,
              let document = pdfDocument else {
            // 没有可见的注释，清除高亮
            selectedAnnotationId = nil
            return
        }
        
        let pageIndex = document.index(for: page)
        let bounds = pdfAnnotation.bounds
        
        // 优化：直接在主线程同步执行，避免 NotificationCenter 的延迟
        // 通过 NotificationCenter 请求 AnnotationModeView 匹配 Annotation ID
        // 使用 UserInfo 传递 PDFAnnotation 信息
        let userInfo: [String: Any] = [
            "pageIndex": pageIndex,
            "boundsX": bounds.origin.x,
            "boundsY": bounds.origin.y
        ]
        // 使用同步通知，减少延迟
        NotificationCenter.default.post(
            name: NSNotification.Name("PDFScrollDetected"),
            object: nil,
            userInfo: userInfo
        )
    }
    
}

// QuestionAnswerView包装器，支持绑定
struct QuestionAnswerViewWrapper: View {
    @Binding var selectedText: String
    @StateObject private var apiService = QwenAPIService()
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false
    
    // 翻译相关状态
    @State private var isTranslating: Bool = false
    @State private var translatedText: String = ""
    @State private var translationError: String? = nil
    @State private var autoTranslate: Bool = true // 自动翻译开关，默认开启
    @State private var showTranslationSection: Bool = true // 翻译区域折叠状态，默认展开
    @State private var showQASection: Bool = true // 问答区域折叠状态，默认展开
    
    // 防抖定时器
    @State private var translationTask: Task<Void, Never>? = nil
    
    // OCR进度相关状态
    @State private var ocrProgress: Double = 0.0
    @State private var isProcessingOCR: Bool = false
    @State private var ocrProgressObserver: NSObjectProtocol?
    @State private var ocrCompletedObserver: NSObjectProtocol?
    
    // OCR完成标志（用于判断是否是OCR更新，不依赖内容特征）
    @State private var isOCRPending: Bool = false
    @State private var lastOCRCompletionTime: Date? = nil
    
    // OCR更新前是否有翻译结果（用于静默更新判断）
    @State private var hadTranslationBeforeOCR: Bool = false
    
    // 是否是OCR更新（用于清除逻辑判断，不依赖LaTeX定界符）
    @State private var isOCRTranslation: Bool = false
    
    // 是否有待处理的OCR翻译（等待OCRCompleted通知触发）
    @State private var pendingOCRTranslation: Bool = false
    
    // 翻译版本管理（用于处理两次翻译请求）
    @State private var translationVersion: String = "original" // "original" 或 "ocr"
    @State private var currentTranslationTask: Task<Void, Never>? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 选中文本区域（只读显示）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("选中的论文内容:")
                            .font(.headline)
                        
                        Spacer()
                        
                        // 自动翻译开关（使用紫色，打开时底色为紫色）
                        Toggle("自动翻译", isOn: $autoTranslate)
                            .toggleStyle(.switch)
                            .tint(Color(red: 0.5, green: 0.2, blue: 0.8)) // 深紫色，控制开关打开时的底色
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView {
                            if selectedText.isEmpty {
                                Text("在PDF中选择区域后，文本将显示在这里")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .foregroundColor(.secondary)
                            } else {
                                MarkdownLaTeXView(content: selectedText)
                                    .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                                    .padding(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
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
                                
                                // 细描边
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            }
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        
                        // OCR进度条（细且不显眼）
                        if isProcessingOCR {
                            ProgressView(value: ocrProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 2) // 细进度条
                                .padding(.horizontal, 8)
                                .padding(.top, 4)
                                .opacity(0.6) // 降低不透明度，不显眼
                        }
                    }
                    .padding(8)
            }
            .padding(8)
            .onAppear {
                // 监听OCR进度更新
                ocrProgressObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("OCRProgressUpdate"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let userInfo = notification.userInfo,
                       let progress = userInfo["progress"] as? Double {
                        let oldProgress = ocrProgress
                        let oldIsProcessing = isProcessingOCR
                        
                        // 检查是否是完成通知
                        let isCompleted = (userInfo["completed"] as? Bool) ?? false
                        
                        if isCompleted {
                            // 如果是完成通知，立即隐藏进度条（不延迟）
                            // 立即隐藏进度条，避免延迟导致的闪现
                            // 注意：这里设置progress为1.0而不是0.0，确保进度条显示为100%后再隐藏
                            ocrProgress = 1.0
                            isProcessingOCR = false
                            
                            // 立即重置进度，不需要延迟（UI更新是同步的）
                            // 使用下一个runloop确保UI已经更新，但不需要等待0.1秒
                            DispatchQueue.main.async {
                                self.ocrProgress = 0.0
                            }
                        } else {
                            // 普通进度更新（progress < 1.0）
                            ocrProgress = progress
                            isProcessingOCR = true
                        }
                    }
                }
                
                // 监听OCR完成通知，在OCR结果返回后触发翻译
                // 这样可以确保OCR结果完全返回后再触发翻译，准确判断是否有旧翻译结果
                ocrCompletedObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("OCRCompleted"),
                    object: nil,
                    queue: .main
                ) { notification in
                    // 设置OCR完成标志（用于onChange判断OCR更新）
                    // 注意：这个标志必须在onChange触发之前设置，所以要在通知处理中立即设置
                    self.isOCRPending = true
                    self.lastOCRCompletionTime = Date()
                    
                    // 使用下一个runloop，确保selectedText已更新，onChange已处理完成
                    // 这样可以确保pendingOCRTranslation标志已经由onChange设置
                    DispatchQueue.main.async {
                        guard !self.selectedText.isEmpty else {
                            return
                        }
                        
                        // 检查是否有待处理的OCR翻译
                        if self.pendingOCRTranslation {
                            // 重置待处理标志
                            self.pendingOCRTranslation = false
                            
                            // 关键：检查自动翻译开关是否开启
                            guard self.autoTranslate else {
                                // 如果自动翻译关闭，清除翻译结果
                                self.translatedText = ""
                                self.translationError = nil
                                self.isTranslating = false
                                return
                            }
                            
                            // 此时OCR结果已完全返回，使用之前保存的hadTranslationBeforeOCR
                            let hadTranslation = self.hadTranslationBeforeOCR
                            
                            // 设置isTranslating状态
                            if hadTranslation {
                                // 有旧翻译结果，静默更新（不显示"翻译中"）
                                self.isTranslating = false
                            } else {
                                // 没有旧翻译结果，显示"翻译中"（避免空白）
                                self.isTranslating = true
                            }
                            
                            // 触发翻译
                            self.triggerTranslationWithDebounce(
                                silent: true, 
                                hadTranslation: hadTranslation
                            )
                        }
                    }
                }
            }
            .onDisappear {
                // 移除观察者
                if let observer = ocrProgressObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                if let observer = ocrCompletedObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            
            // 文段翻译区域（可折叠）
            if !selectedText.isEmpty {
                DisclosureGroup(isExpanded: $showTranslationSection) {
                    VStack(alignment: .leading, spacing: 8) {
                        if isTranslating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("翻译中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                        } else if let translationError = translationError {
                            Text("翻译错误: \(translationError)")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        } else if !translatedText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ScrollView {
                                    MarkdownLaTeXView(content: translatedText)
                                        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                                        .padding(8)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
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
                                        
                                        // 细描边
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                                    }
                                )
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            }
                            .padding(8)
                        } else if autoTranslate {
                            Text("等待自动翻译...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                        } else {
                            Button("手动翻译") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    triggerTranslation()
                                }
                            }
                            .buttonStyle(LiquidGlassButtonStyle(color: Color(red: 0.5, green: 0.2, blue: 0.8), isProminent: true)) // 重要按钮，使用深紫色
                            .padding(8)
                        }
                    }
                } label: {
                    HStack {
                        Text("文段翻译")
                            .font(.headline)
                        Spacer()
                        if isTranslating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .padding(8)
            }
            
            // 问答功能区域（可折叠）
            DisclosureGroup(isExpanded: $showQASection) {
                VStack(spacing: 12) {
                    // 问题输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你的问题:")
                            .font(.headline)
                        
                        TextEditor(text: $question)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40, maxHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(8)
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
                                    
                                    // 细描边
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                                }
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    }
                    .padding(8)
                    
                    // 提交按钮（使用液态玻璃样式，胶囊型，高度较小，文字黑色）
                    Button(action: {
                        submitQuestion()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .tint(.black)
                            }
                            Text(isLoading ? "思考中..." : "提问")
                                .font(.headline)
                                .foregroundColor(.black) // 文字改为黑色
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8) // 减小高度
                    }
                    .buttonStyle(LiquidGlassButtonStyle(color: Color(red: 0.5, green: 0.2, blue: 0.8), isProminent: true, isCapsule: true))
                    .disabled(isLoading || question.isEmpty)
                    .opacity(isLoading || question.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 8)
                    
                    // 回答显示
                    VStack(alignment: .leading, spacing: 8) {
                        Text("回答:")
                            .font(.headline)
                        
                        ScrollView {
                            if answer.isEmpty {
                                Text("等待回答...")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .foregroundColor(.secondary)
                            } else {
                                MarkdownLaTeXView(content: answer)
                                    .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                                    .padding(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
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
                                
                                // 细描边
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            }
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    }
                    .padding(8)
                }
            } label: {
                Text("问答功能")
                    .font(.headline)
            }
            .padding(8)
            
                // 监听selectedText变化，触发自动翻译
                .onChange(of: selectedText) { oldValue, newValue in
                    if oldValue != newValue {
                        // 检测是否是OCR更新
                        // 使用OCR完成标志判断，而不是依赖内容特征（LaTeX定界符）
                        // 这样无论OCR结果是什么（有无公式），都能正确识别为OCR更新
                        let isOCRUpdate: Bool
                        if isOCRPending {
                            // OCR完成标志已设置，认为是OCR更新
                            isOCRUpdate = true
                        } else if let lastTime = lastOCRCompletionTime,
                                  Date().timeIntervalSince(lastTime) < 1.0 {
                            // OCR刚刚完成（1秒内），认为是OCR更新
                            isOCRUpdate = true
                        } else {
                            // 没有OCR完成标志，认为是正常更新（用户手动选择）
                            isOCRUpdate = false
                        }
                        
                        // 如果是OCR更新，重置标志
                        if isOCRUpdate {
                            isOCRPending = false
                            lastOCRCompletionTime = nil
                        }
                        
                        // 根据是否是OCR更新，调用不同的处理函数
                        if isOCRUpdate {
                            handleOCRUpdate(newValue: newValue)
                        } else {
                            handleNormalUpdate(newValue: newValue)
                        }
                    }
                }
                
                // 监听自动翻译开关变化
                .onChange(of: autoTranslate) { oldValue, newValue in
                    if newValue {
                        // 如果开启自动翻译
                        if !selectedText.isEmpty && translatedText.isEmpty {
                            // 如果有选中文本但还没有翻译，立即触发翻译
                            triggerTranslationWithDebounce(silent: false, hadTranslation: false)
                        }
                    } else {
                        // 如果关闭自动翻译，清除翻译结果和错误
                        translatedText = ""
                        translationError = nil
                        isTranslating = false
                        // 取消待处理的翻译任务
                        translationTask?.cancel()
                        currentTranslationTask?.cancel()
                    }
                }
                
                // 错误提示
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 成功提示
                if showSuccess {
                    Text("✓ 回答成功")
                        .foregroundColor(.green)
                        .padding()
                }
            }
            .padding(.bottom) // 底部padding，确保内容不被裁剪
        }
    }
    
    private func submitQuestion() {
        guard !question.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        showSuccess = false
        answer = ""
        
        Task {
            do {
                let response = try await apiService.askQuestion(
                    question: question,
                    context: selectedText.isEmpty ? nil : selectedText
                )
                
                await MainActor.run {
                    answer = response
                    isLoading = false
                    showSuccess = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "错误: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - OCR更新检测和处理
    
    /// 检测是否是OCR更新
    private func detectOCRUpdate(oldValue: String, newValue: String) -> Bool {
        let containsLaTeX = newValue.contains("$") || newValue.contains("\\")
        let oldContainsLaTeX = oldValue.contains("$") || oldValue.contains("\\")
        
        let lengthRatio = oldValue.isEmpty ? 0 : Double(newValue.count) / Double(oldValue.count)
        let isLengthSimilar = lengthRatio >= 0.8 && lengthRatio <= 1.2
        let isContentDifferent = newValue != oldValue && !oldValue.isEmpty
        
        let isOCRUpdate = (containsLaTeX && !oldContainsLaTeX) || 
                         (containsLaTeX && newValue.count > Int(Double(oldValue.count) * 1.5)) ||
                         (isLengthSimilar && isContentDifferent && containsLaTeX) ||
                         (newValue.count > oldValue.count && newValue.count > Int(Double(oldValue.count) * 1.1) && containsLaTeX)
        
        return isOCRUpdate
    }
    
    /// 处理OCR更新
    private func handleOCRUpdate(newValue: String) {
        // 关键：如果自动翻译关闭，不处理OCR更新
        guard autoTranslate else {
            // 清除翻译结果
            translatedText = ""
            translationError = nil
            isTranslating = false
            return
        }
        
        // 1. 保存是否有旧翻译结果（在清除前保存）
        hadTranslationBeforeOCR = !translatedText.isEmpty
        
        // 2. 设置OCR更新标志（用于清除逻辑判断，不依赖LaTeX定界符）
        isOCRTranslation = true
        
        // 3. 设置待处理标志（等待OCRCompleted通知触发翻译）
        // 这样可以确保OCR结果完全返回后再触发翻译，准确判断是否有旧翻译结果
        pendingOCRTranslation = true
        
        // 4. 重置版本，让OCR版本可以更新
        translationVersion = "original"
        
        // 5. 不立即触发翻译，等待OCRCompleted通知
        // 这样可以确保OCR结果完全返回后再触发翻译
    }
    
    /// 处理正常更新（用户选择新区域）
    private func handleNormalUpdate(newValue: String) {
        // 重置OCR更新标志
        isOCRTranslation = false
        
        // 重置翻译版本
        translationVersion = "original"
        
        // 如果自动翻译开启，触发翻译（带防抖）
        if autoTranslate && !newValue.isEmpty {
            triggerTranslationWithDebounce(silent: false, hadTranslation: false)
        } else {
            // 如果自动翻译关闭，清除翻译结果
            translatedText = ""
            translationError = nil
        }
    }
    
    // MARK: - 翻译触发函数
    
    // 触发翻译（带防抖，延迟500ms）
    private func triggerTranslationWithDebounce(silent: Bool = false, hadTranslation: Bool = false) {
        // 取消之前的任务
        translationTask?.cancel()
        
        // 创建新的任务，延迟500ms后执行
        translationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            // 检查selectedText是否仍然有效
            guard !selectedText.isEmpty else { return }
            
            // 触发翻译（传递silent和hadTranslation参数）
            await MainActor.run {
                triggerTranslation(silent: silent, hadTranslation: hadTranslation)
            }
        }
    }
    
    // 触发翻译（立即执行）
    private func triggerTranslation(silent: Bool = false, hadTranslation: Bool = false) {
        guard !selectedText.isEmpty else {
            return
        }
        
        // 取消之前的翻译任务（如果存在）
        currentTranslationTask?.cancel()
        
        // 确定当前版本（如果selectedText包含LaTeX公式，可能是OCR版本）
        let currentVersion = selectedText.contains("$") || selectedText.contains("\\") ? "ocr" : "original"
        
        // 如果是OCR更新，且之前是原始版本，清除旧结果
        // 但是，如果是静默更新（有旧翻译结果），不清除旧结果，保留显示直到新结果返回
        // 这样可以避免显示"等待自动翻译..."，提供更好的用户体验
        // 使用isOCRTranslation标志判断，不依赖LaTeX定界符
        if isOCRTranslation && translationVersion == "original" {
            if silent && hadTranslation {
                // 静默更新：不清除旧翻译结果，保留显示直到新结果返回
            } else {
                // 非静默更新：清除旧结果
                translatedText = ""
                translationError = nil
            }
            // 重置OCR更新标志
            isOCRTranslation = false
        }
        
        // 统一管理isTranslating状态
        // 规则：
        // 1. 非静默模式：总是显示"翻译中"
        // 2. 静默模式 + 有旧翻译结果：不显示"翻译中"（静默更新）
        // 3. 静默模式 + 没有旧翻译结果：显示"翻译中"（避免空白）
        if !silent {
            // 非静默模式：总是显示"翻译中"
            isTranslating = true
        } else {
            // 静默模式：根据hadTranslation参数决定
            if hadTranslation {
                // 有旧翻译结果，静默更新（不显示"翻译中"）
                isTranslating = false
            } else {
                // 没有旧翻译结果，显示"翻译中"（避免空白）
                isTranslating = true
            }
        }
        translationError = nil
        
        // 检测源文本语言
        let sourceLanguage = detectLanguage(text: selectedText)
        
        // 使用用户选择的目标语言设置
        let targetLanguage = TranslationTargetLanguage.current.getTargetLanguage(sourceLanguage: sourceLanguage)
        
        // 创建独立的Task，确保与提问API调用并行，不互相干扰
        currentTranslationTask = Task {
            do {
                let translation = try await apiService.translate(
                    text: selectedText,
                    targetLanguage: targetLanguage
                )
                
                await MainActor.run {
                    // 检查任务是否被取消
                    guard !Task.isCancelled else {
                        return
                    }
                    
                    // 检查selectedText是否仍然有效（防止在翻译过程中文本被改变）
                    guard !selectedText.isEmpty else {
                        return
                    }
                    
                    // 更新翻译结果
                    // 规则：
                    // 1. 如果当前是OCR版本，总是更新（OCR版本优先级最高）
                    // 2. 如果当前是原始版本，且已有OCR版本，则不更新（等待OCR版本）
                    // 3. 如果当前是原始版本，且没有OCR版本，则更新
                    let shouldUpdate: Bool
                    if currentVersion == "ocr" {
                        // OCR版本总是更新
                        shouldUpdate = true
                    } else if translationVersion == "ocr" {
                        // 当前是原始版本，但已有OCR版本，不更新
                        shouldUpdate = false
                    } else {
                        // 当前是原始版本，且没有OCR版本，更新
                        shouldUpdate = true
                    }
                    
                    if shouldUpdate {
                        // 如果是OCR版本，直接替换（清除之前的原始版本）
                        // 如果是原始版本，只有在没有OCR版本时才更新
                        translatedText = translation
                        translationVersion = currentVersion
                        translationError = nil
                        
                        // 重置OCR更新标志
                        isOCRTranslation = false
                        
                        // 静默模式下，确保不显示"翻译中"状态
                        if silent {
                            isTranslating = false
                        }
                    }
                    
                    // 静默模式下不需要更新isTranslating（因为从未设置为true）
                    if !silent {
                        isTranslating = false
                    }
                }
            } catch {
                await MainActor.run {
                    // 检查任务是否被取消
                    guard !Task.isCancelled else {
                        return
                    }
                    
                    translationError = error.localizedDescription
                    // 静默模式下不需要更新isTranslating（因为从未设置为true）
                    if !silent {
                        isTranslating = false
                    }
                }
            }
        }
    }
    
    private func detectLanguage(text: String) -> String {
        // 简单的语言检测：检查是否包含中文字符
        let chinesePattern = "[\\u4e00-\\u9fa5]"
        if text.range(of: chinesePattern, options: .regularExpression) != nil {
            return "中文"
        }
        return "English"
    }
}

// MARK: - 圆形液态玻璃按钮样式（用于注释工具）
struct CircularLiquidGlassButtonStyle: ButtonStyle {
    var color: Color = Color(red: 0.5, green: 0.2, blue: 0.8) // 深紫色
    var isProminent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        // 计算按钮总尺寸：36x36（与其他按钮高度一致）
        // padding(8) 意味着内容区域是 20x20，加上 padding 8*2 = 36
        return configuration.label
            .frame(width: 20, height: 20) // 内容区域大小
            .padding(8) // 添加 padding，确保背景正确显示
            .background(
                Group {
                    if isProminent {
                        // 主要按钮：深紫色液态玻璃
                        ZStack {
                            // 基础玻璃材质
                            Circle()
                                .fill(.thinMaterial)
                            
                            // 深紫色渐变背景
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.4),
                                            color.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // 高光效果
                            Circle()
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
                        }
                        .shadow(color: color.opacity(0.2), radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 2)
                    } else {
                        // 次要按钮：更透明的玻璃效果
                        ZStack {
                            Circle()
                                .fill(.thinMaterial)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.2),
                                            color.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: color.opacity(0.15), radius: configuration.isPressed ? 1 : 2, y: configuration.isPressed ? 0.5 : 1)
                    }
                }
            )
            .clipShape(Circle()) // 确保圆形
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 液态玻璃按钮样式
struct LiquidGlassButtonStyle: ButtonStyle {
    var color: Color = Color(red: 0.5, green: 0.2, blue: 0.8) // 深紫色
    var isProminent: Bool = false
    var isCapsule: Bool = false // 是否使用胶囊型
    
    func makeBody(configuration: Configuration) -> some View {
        let cornerRadius: CGFloat = isCapsule ? 20 : 8
        
        return configuration.label
            .padding(.horizontal, isCapsule ? 20 : 16)
            .padding(.vertical, isCapsule ? 8 : (isProminent ? 10 : 8))
            .background(
                Group {
                    if isProminent {
                        // 主要按钮：深紫色液态玻璃
                        ZStack {
                            // 基础玻璃材质
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.thinMaterial)
                            
                            // 深紫色渐变背景
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.4),
                                            color.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // 高光效果
                            RoundedRectangle(cornerRadius: cornerRadius)
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
                        }
                        .shadow(color: color.opacity(0.2), radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 2)
                    } else {
                        // 次要按钮：更透明的玻璃效果
                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.thinMaterial)
                            
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.2),
                                            color.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: color.opacity(0.15), radius: configuration.isPressed ? 1 : 2, y: configuration.isPressed ? 0.5 : 1)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 液态玻璃文本框样式
struct LiquidGlassTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                ZStack {
                    // 玻璃材质背景
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                    
                    // 白色背景（增强不透明度）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.6))
                    
                    // 边框高光
                    RoundedRectangle(cornerRadius: 8)
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
                }
            )
            .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
    }
}

extension View {
    func liquidGlassTextField() -> some View {
        modifier(LiquidGlassTextFieldStyle())
    }
}

// 模型选择器视图
struct ModelSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModelId: String
    
    init() {
        // 在初始化时读取当前模型
        _selectedModelId = State(initialValue: APIConfig.model)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("选择模型")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            // 模型列表
            List(APIConfig.availableModels, id: \.id) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(model.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(model.price)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if selectedModelId == model.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.5, green: 0.2, blue: 0.8)) // 深紫色
                            .symbolEffect(.bounce, value: selectedModelId == model.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Group {
                        if selectedModelId == model.id {
                            // 选中时显示淡紫色高光
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.thinMaterial)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2),
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.4),
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        } else {
                            Color.clear
                        }
                    }
                )
                .cornerRadius(8)
                .contentShape(Rectangle()) // 让整个区域可点击
                .onTapGesture {
                    // 使用onTapGesture而不是Button，避免嵌套问题
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedModelId = model.id
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) // 隐藏默认背景
            .background(.clear)
            .frame(height: 300)
            
            // 按钮
            HStack(spacing: 12) {
                Button("取消") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dismiss()
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(color: .gray, isProminent: false)) // 取消按钮使用灰色
                
                Button("确定") {
                    // 保存到UserDefaults
                    APIConfig.model = selectedModelId
                    // 同步UserDefaults
                    UserDefaults.standard.synchronize()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dismiss()
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(color: Color(red: 0.5, green: 0.2, blue: 0.8), isProminent: true))
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .padding()
        .background(.thinMaterial) // 使用thinMaterial，半透明玻璃材质
        .background {
            // 添加微妙的渐变背景，增强玻璃质感（不透明度较高）
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .cornerRadius(20) // 大圆角增强玻璃质感
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4) // 减少阴影，让边缘更清晰
    }
}

// 公式处理模式选择器视图
struct FormulaModeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: FormulaProcessingMode
    
    init() {
        // 在初始化时读取当前模式
        _selectedMode = State(initialValue: FormulaProcessingMode.current)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("公式处理模式")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            // 模式列表
            List(FormulaProcessingMode.allCases, id: \.id) { mode in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if selectedMode.id == mode.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.5, green: 0.2, blue: 0.8)) // 深紫色
                            .symbolEffect(.bounce, value: selectedMode.id == mode.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Group {
                        if selectedMode.id == mode.id {
                            // 选中时显示淡紫色高光
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.thinMaterial)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2),
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.4),
                                                Color(red: 0.5, green: 0.2, blue: 0.8).opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        } else {
                            Color.clear
                        }
                    }
                )
                .cornerRadius(8)
                .contentShape(Rectangle()) // 让整个区域可点击
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) // 隐藏默认背景
            .background(.clear)
            .frame(height: 300)
            
            // 按钮
            HStack(spacing: 12) {
                Button("取消") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dismiss()
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(color: .gray, isProminent: false)) // 取消按钮使用灰色
                
                Button("确定") {
                    // 保存到UserDefaults
                    FormulaProcessingMode.current = selectedMode
                    // 检查是否需要Python环境
                    if selectedMode == .localOCR {
                        checkPythonEnvironment()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dismiss()
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(color: Color(red: 0.5, green: 0.2, blue: 0.8), isProminent: true))
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .padding()
        .background(.thinMaterial) // 使用thinMaterial，半透明玻璃材质
        .background {
            // 添加微妙的渐变背景，增强玻璃质感（不透明度较高）
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .cornerRadius(20) // 大圆角增强玻璃质感
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4) // 减少阴影，让边缘更清晰
    }
    
    /// 检查Python环境
    private func checkPythonEnvironment() {
        // 检查Python环境是否存在
        if Pix2TextService.shared.findPythonPath() == nil {
            // 显示提示：Python环境不存在，已自动降级到"不处理公式"模式
            // 这里可以使用Alert或Toast提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 自动降级
                FormulaProcessingMode.current = .none
                // TODO: 显示提示对话框
            }
        }
    }
}


