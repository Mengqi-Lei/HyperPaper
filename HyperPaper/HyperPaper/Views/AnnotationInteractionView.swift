//
// AnnotationInteractionView.swift
// HyperPaper
//
// 注释交互视图：处理注释工具的交互（文本标注、自由画线、Note、文字添加）
//

import SwiftUI
import PDFKit
import AppKit

struct AnnotationInteractionView: NSViewRepresentable {
    @Binding var selectedAnnotationTool: AnnotationTool
    @Binding var selectedAnnotationColor: Color
    let document: PDFDocument
    @Binding var pdfView: PDFView?
    var onAnnotationCreated: (() -> Void)? = nil // 注释创建后的回调
    var onEditRequested: ((PDFAnnotation) -> Void)? = nil // Note编辑请求回调（传递annotation）
    
    func makeNSView(context: Context) -> AnnotationInteractionNSView {
        let view = AnnotationInteractionNSView()
        view.document = document
        view.pdfView = pdfView
        view.selectedAnnotationTool = selectedAnnotationTool
        view.selectedAnnotationColor = selectedAnnotationColor
        view.onAnnotationCreated = onAnnotationCreated
        view.onEditRequested = onEditRequested
        
        // 设置frame以匹配PDFView（用于实时预览绘制）
        if let pdfView = pdfView {
            view.frame = pdfView.bounds
        }
        
        view.setupEventMonitor()
        return view
    }
    
    func updateNSView(_ nsView: AnnotationInteractionNSView, context: Context) {
        nsView.document = document
        nsView.pdfView = pdfView
        nsView.onAnnotationCreated = onAnnotationCreated
        nsView.onEditRequested = onEditRequested
        let toolChanged = nsView.selectedAnnotationTool != selectedAnnotationTool
        nsView.selectedAnnotationTool = selectedAnnotationTool
        nsView.selectedAnnotationColor = selectedAnnotationColor
        
        // 更新frame以匹配PDFView（用于实时预览绘制）
        if let pdfView = pdfView {
            nsView.frame = pdfView.bounds
        }
        
        // 如果工具改变了，重新设置事件监听器
        if toolChanged {
            nsView.setupEventMonitor()
            // 如果切换到非橡皮擦工具，清除光标位置
            if selectedAnnotationTool != .eraser {
                nsView.clearEraserCursor()
            }
        }
    }
}

class AnnotationInteractionNSView: NSView {
    var document: PDFDocument?
    var pdfView: PDFView?
    var selectedAnnotationTool: AnnotationTool = .none
    var selectedAnnotationColor: Color = .yellow
    var onAnnotationCreated: (() -> Void)? = nil // 注释创建后的回调
    
    private var eventMonitor: Any?
    private var isDrawing: Bool = false
    private var drawingPoints: [CGPoint] = [] // 当前绘制的路径点
    private var currentPath: [CGPoint] = [] // 当前路径（用于自由画线）
    
    // 实时预览相关
    private var previewPath: [CGPoint] = [] // 预览路径（视图坐标）
    private var previewStartPoint: CGPoint? // 预览起始点（视图坐标）
    
    // 橡皮擦相关
    private var eraserCursorLocation: CGPoint? = nil // 橡皮擦光标位置（视图坐标）
    private var isErasing: Bool = false // 是否正在拖动擦除
    private var erasedAnnotations: Set<PDFAnnotation> = [] // 已擦除的注释（避免重复删除）
    
    // 文本注释相关
    private var newlyCreatedTextAnnotation: PDFAnnotation? = nil // 新创建的文本注释（用于触发编辑）
    
    // 标记是否点击了现有注释（用于跳过创建新注释）
    private var clickedExistingAnnotation: Bool = false
    // 标记点击的注释类型（用于区分note和text）
    private var clickedAnnotationType: PDFAnnotationSubtype? = nil
    
    // 防止重复创建注释的标志
    private var isCreatingAnnotation: Bool = false
    
    // Note编辑相关状态
    var onEditRequested: ((PDFAnnotation) -> Void)? = nil // Note编辑请求回调（传递annotation）
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 启用实时绘制
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // 允许鼠标事件穿透到PDFView（用于滚动等操作）
        // 但通过NSEvent monitor来捕获特定事件
        
        // 启用鼠标跟踪（用于橡皮擦光标显示）
        // 注意：即使 hitTest 返回 nil，我们仍然可以通过 NSEvent monitor 捕获鼠标移动
    }
    
    // 重写hitTest，允许滚动和其他非绘制事件穿透
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 始终返回nil，让所有事件穿透到PDFView
        // 这样滚动、缩放等操作可以正常工作
        // 鼠标事件通过NSEvent monitor捕获，不需要通过hitTest
        return nil
    }
    
    // 重写scrollWheel，确保滚动事件能传递到PDFView
    override func scrollWheel(with event: NSEvent) {
        // 不处理滚动事件，让事件穿透到PDFView
        if let pdfView = pdfView {
            pdfView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 重写draw方法以实现实时预览
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        
        context.saveGState()
        
        // 自由画线预览
        if selectedAnnotationTool == .freehand,
           isDrawing,
           !previewPath.isEmpty,
           previewPath.count >= 2 {
            // 设置绘制属性
            let color = PDFAnnotationService.nsColor(from: selectedAnnotationColor)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setAlpha(0.8) // 稍微透明，以区分预览和最终注释
            
            // 绘制预览路径
            let firstPoint = previewPath[0]
            context.move(to: firstPoint)
            for point in previewPath.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }
        
        // 橡皮擦光标阴影
        if selectedAnnotationTool == .eraser,
           let cursorLocation = eraserCursorLocation {
            // 橡皮擦点击区域半径（与 findFreehandAnnotation 中的 padding 一致）
            let eraserRadius: CGFloat = 10.0
            
            // 绘制圆形阴影
            let circleRect = CGRect(
                x: cursorLocation.x - eraserRadius,
                y: cursorLocation.y - eraserRadius,
                width: eraserRadius * 2,
                height: eraserRadius * 2
            )
            
            // 外圈：半透明灰色阴影
            context.setFillColor(NSColor.black.withAlphaComponent(0.15).cgColor)
            context.fillEllipse(in: circleRect)
            
            // 内圈：更透明的边框
            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: circleRect)
        }
        
        context.restoreGState()
    }
    
    deinit {
        removeEventMonitor()
    }
    
    /// 清除橡皮擦光标位置（供外部调用）
    func clearEraserCursor() {
        eraserCursorLocation = nil
        needsDisplay = true
    }
    
    func setupEventMonitor() {
        removeEventMonitor()
        
        // 只在有注释工具选中时才设置事件监听器
        guard selectedAnnotationTool != .none else {
            // 清除橡皮擦光标位置
            clearEraserCursor()
            return
        }
        
        // 监听鼠标事件（包括鼠标移动，用于橡皮擦光标显示）
        let eventTypes: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .mouseMoved]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventTypes) { [weak self] event in
            guard let self = self,
                  let pdfView = self.pdfView,
                  let document = self.document else {
                return event
            }
            
            // 只在有注释工具选中时处理
            guard self.selectedAnnotationTool != .none else {
                return event
            }
            
            // 关键：对于 text 工具，完全让 PDFView 自己处理，不拦截事件
            // 这样 PDFView 可以自动创建和编辑 FreeText 注释
            if self.selectedAnnotationTool == .text {
                return event
            }
            
            // 如果是滚动事件，直接返回，不拦截
            if event.type == .scrollWheel {
                return event
            }
            
            // 检查鼠标是否在PDFView范围内
            guard let pdfWindow = pdfView.window,
                  let eventWindow = event.window,
                  eventWindow == pdfWindow else {
                // 如果鼠标不在窗口内，清除橡皮擦光标位置
                if self.selectedAnnotationTool == .eraser {
                    self.eraserCursorLocation = nil
                    self.needsDisplay = true
                }
                return event
            }
            
            let mouseLocation = event.locationInWindow
            let viewLocation = pdfView.convert(mouseLocation, from: nil)
            
            // 处理鼠标移动事件（用于橡皮擦光标显示）
            if event.type == .mouseMoved {
                if self.selectedAnnotationTool == .eraser {
                    // 更新橡皮擦光标位置
                    if pdfView.bounds.contains(viewLocation) {
                        self.eraserCursorLocation = viewLocation
                        self.needsDisplay = true
                    } else {
                        self.eraserCursorLocation = nil
                        self.needsDisplay = true
                    }
                } else {
                    // 其他工具：清除橡皮擦光标位置
                    if self.eraserCursorLocation != nil {
                        self.eraserCursorLocation = nil
                        self.needsDisplay = true
                    }
                }
                return event // 不拦截鼠标移动事件
            }
            
            guard pdfView.bounds.contains(viewLocation) else {
                // 如果鼠标不在PDFView范围内，清除橡皮擦光标位置
                if self.selectedAnnotationTool == .eraser {
                    self.eraserCursorLocation = nil
                    self.needsDisplay = true
                }
                return event
            }
            
            // 更新橡皮擦光标位置（对于其他鼠标事件）
            if self.selectedAnnotationTool == .eraser {
                self.eraserCursorLocation = viewLocation
                self.needsDisplay = true
            }
            
            print("AnnotationInteraction: Event received - type: \(event.type), tool: \(self.selectedAnnotationTool)")
            
            // 关键：检查是否点击在工具栏按钮区域（顶部区域，约70px高度）
            // 工具栏悬浮在PDFView上方，按钮区域需要让事件正常传递
            // 注意：NSView坐标系y=0在底部，所以顶部区域是y值较大的区域
            // 工具栏实际内容高度约50-60px，加上顶部padding 12px，总共约70px
            let toolbarContentHeight: CGFloat = 70
            if viewLocation.y > pdfView.bounds.height - toolbarContentHeight {
                // 检查是否在工具栏的水平范围内（工具栏有16px左右padding）
                let toolbarHorizontalPadding: CGFloat = 16
                if viewLocation.x >= toolbarHorizontalPadding &&
                   viewLocation.x <= pdfView.bounds.width - toolbarHorizontalPadding {
                    return event // 点击在工具栏内容区域，让事件正常传递到工具栏按钮
                }
                // 如果不在工具栏的水平范围内，继续处理注释（允许在工具栏附近区域进行注释）
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
            
            // 获取当前页面和页面坐标
            guard let currentPage = pdfView.currentPage else {
                return event
            }
            let pagePoint = pdfView.convert(viewLocation, to: currentPage)
            
            // 对于note注释，无论是否选中note工具，点击时都跳转到批注功能区域
            // 对于text工具，在mouseDown时检查是否点击了现有注释
            if event.type == .leftMouseDown {
                // 检查是否点击了note注释（无论当前工具是什么）
                let noteAnnotation = findAnnotation(at: pagePoint, on: currentPage, type: .text)
                if let hitNote = noteAnnotation {
                    print("📝 检测到点击note注释，跳转到批注功能区域: \(hitNote.bounds)")
                    // 标记已点击现有note注释，后续事件都拦截
                    self.clickedExistingAnnotation = true
                    self.clickedAnnotationType = .text
                    // 调用回调，跳转到批注功能区域
                    DispatchQueue.main.async {
                        self.onEditRequested?(hitNote)
                    }
                    // 拦截事件，不让PDFView显示编辑弹窗
                    return nil
                }
                
                // 对于text工具，检查是否点击了现有text注释
                if selectedAnnotationTool == .text {
                    let textAnnotation = findAnnotation(at: pagePoint, on: currentPage, type: .freeText)
                    if let hitText = textAnnotation {
                        print("📝 检测到点击text注释，让PDFView处理编辑: \(hitText.bounds)")
                        // 标记已点击现有text注释，后续事件让PDFView处理
                        self.clickedExistingAnnotation = true
                        self.clickedAnnotationType = .freeText
                        // 让PDFView处理编辑
                        return event
                    } else {
                        // 没有点击现有注释，重置标记
                        self.clickedExistingAnnotation = false
                        self.clickedAnnotationType = nil
                    }
                } else if selectedAnnotationTool == .note {
                    // note工具：没有点击现有note，将创建新note
                    print("❌ mouseDown: 未找到现有note注释，将创建新注释")
                    self.clickedExistingAnnotation = false
                    self.clickedAnnotationType = nil
                } else {
                    // 其他工具，重置标记
                    self.clickedExistingAnnotation = false
                    self.clickedAnnotationType = nil
                }
            }
            
            // 在switch之前检查：如果之前点击了现有注释，根据类型决定处理方式
            if clickedExistingAnnotation {
                if clickedAnnotationType == .text {
                    // note注释：已跳转到批注功能区域，拦截所有事件
                    print("📝 事件监听器: 检测到点击了note注释，已跳转到批注功能区域，拦截事件")
                    if event.type == .leftMouseUp {
                        print("📝 事件监听器: mouseUp时检测到点击了note注释，已跳转到批注功能区域")
                        clickedExistingAnnotation = false
                        clickedAnnotationType = nil
                    }
                    // 对于所有事件（包括dragged和up），都拦截
                    return nil
                } else {
                    // text注释：让PDFView处理编辑
                    print("📝 事件监听器: 检测到点击了text注释，让PDFView处理")
                    if event.type == .leftMouseUp {
                        print("📝 事件监听器: mouseUp时检测到点击了text注释，让PDFView处理")
                        clickedExistingAnnotation = false
                        clickedAnnotationType = nil
                    }
                    // 对于所有事件（包括dragged和up），都让PDFView处理
                    return event
                }
            }
            
            switch event.type {
            case .leftMouseDown:
                // 如果之前没有检测到现有注释，继续处理
                return self.handleMouseDown(at: pagePoint, in: currentPage, event: event)
                
            case .leftMouseDragged:
                return self.handleMouseDragged(at: pagePoint, in: currentPage, event: event)
                
            case .leftMouseUp:
                return self.handleMouseUp(at: pagePoint, in: currentPage, event: event)
                
            default:
                return event
            }
        }
    }
    
    private func handleMouseDown(at point: CGPoint, in page: PDFPage, event: NSEvent) -> NSEvent? {
        switch selectedAnnotationTool {
        case .freehand:
            // 开始自由画线
            isDrawing = true
            currentPath = [point]
            drawingPoints = [point]
            
            // 初始化预览路径（转换为视图坐标）
            if let pdfView = pdfView {
                let viewPoint = pdfView.convert(point, from: page)
                previewPath = [viewPoint]
                previewStartPoint = viewPoint
                
                // 确保view的frame与PDFView匹配
                if frame != pdfView.bounds {
                    frame = pdfView.bounds
                }
            }
            
            // 触发draw方法（在主线程）
            DispatchQueue.main.async { [weak self] in
                self?.needsDisplay = true
            }
            return nil // 拦截事件
            
        case .eraser:
            // 橡皮擦工具：开始拖动擦除
            isErasing = true
            erasedAnnotations.removeAll() // 清除之前的记录
            
            // 检测点击位置是否在自由画线注释上
            eraseAnnotationAt(point: point, on: page)
            
            return nil // 拦截事件，开始拖动擦除
            
        case .note:
            // Note：在mouseUp时检查是否点击了现有注释
            // 如果点击了现有注释，让事件传递以进行编辑
            // 如果没有，在mouseUp时创建新注释
            // 这里先让事件传递，在mouseUp时再判断
            return event
            
        case .text:
            // Text工具：不在这里创建注释，让事件传递给PDFView
            // PDFView会在mouseUp时检测到点击，如果点击了现有注释则编辑，否则创建新注释
            // 我们通过CustomPDFView来处理创建和编辑逻辑
            return event
            
        case .highlight, .underline, .strikeout:
            // 文本标注：需要先选择文本，这里不处理
            // PDFView会自动处理文本选择
            return event
            
        default:
            return event
        }
    }
    
    private func handleMouseDragged(at point: CGPoint, in page: PDFPage, event: NSEvent) -> NSEvent? {
        switch selectedAnnotationTool {
        case .freehand:
            if isDrawing {
                currentPath.append(point)
                drawingPoints.append(point)
                
                // 更新预览路径（转换为视图坐标）
                if let pdfView = pdfView {
                    let viewPoint = pdfView.convert(point, from: page)
                    previewPath.append(viewPoint)
                    
                    // 确保view的frame与PDFView匹配（可能在滚动/缩放后改变）
                    if frame != pdfView.bounds {
                        frame = pdfView.bounds
                    }
                }
                
                // 触发实时绘制（在主线程）
                DispatchQueue.main.async { [weak self] in
                    self?.needsDisplay = true
                }
                return nil // 拦截事件
            }
            return event
            
        case .eraser:
            // 橡皮擦工具：拖动时持续擦除经过的线条
            if isErasing {
                eraseAnnotationAt(point: point, on: page)
                return nil // 拦截事件
            }
            return event
            
        default:
            return event
        }
    }
    
    private func handleMouseUp(at point: CGPoint, in page: PDFPage, event: NSEvent) -> NSEvent? {
        switch selectedAnnotationTool {
        case .eraser:
            // 橡皮擦工具：结束拖动擦除
            if isErasing {
                isErasing = false
                
                // 刷新PDFView
                DispatchQueue.main.async { [weak self] in
                    if let pdfView = self?.pdfView {
                        pdfView.setNeedsDisplay(pdfView.bounds)
                        pdfView.display()
                    }
                }
                
                // 触发保存
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.onAnnotationCreated?()
                }
                
                // 发送通知，更新注释列表
                NotificationCenter.default.post(name: NSNotification.Name("PDFAnnotationUpdated"), object: nil)
                
                // 清除已擦除注释记录
                erasedAnnotations.removeAll()
            }
            return nil // 拦截事件
            
        case .freehand:
            if isDrawing && !currentPath.isEmpty {
                // 完成自由画线
                let color = PDFAnnotationService.nsColor(from: selectedAnnotationColor)
                let paths: [[CGPoint]] = [currentPath]
                let annotation = PDFAnnotationService.createFreehand(
                    on: page,
                    points: paths,
                    color: color,
                    lineWidth: 2.0
                )
                
                // 验证注释是否创建成功
                if let annotation = annotation {
                    print("✅ 自由画线注释已创建: bounds=\(annotation.bounds), page=\(page.label ?? "nil")")
                    
                    // 清除预览路径
                    previewPath = []
                    previewStartPoint = nil
                    needsDisplay = true
                    
                    // 刷新PDFView以显示注释（优化：减少页面跳动）
                    DispatchQueue.main.async {
                        guard let pdfView = self.pdfView, let currentPage = pdfView.currentPage else { return }
                        
                        // 保存当前视图状态（避免go(to:)导致的位置重置）
                        let currentScale = pdfView.scaleFactor
                        let currentBounds = pdfView.bounds
                        
                        // 方法1：直接刷新，不使用go(to:)（避免页面跳动）
                        pdfView.setNeedsDisplay(pdfView.bounds)
                        pdfView.display()
                        
                        // 方法2：如果方法1无效，使用更平滑的刷新方式
                        // 延迟一点再刷新，避免与预览清除冲突
                        // 注意：不调用go(to:)，因为它会重置视图位置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // 只刷新显示，不改变视图位置
                            pdfView.setNeedsDisplay(pdfView.bounds)
                            pdfView.display()
                            
                            // 确保缩放比例不变
                            if pdfView.scaleFactor != currentScale {
                                pdfView.scaleFactor = currentScale
                            }
                        }
                        
                        // 延迟一点再触发保存，确保注释已经完全添加到文档
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("📝 触发PDF保存回调...")
                            self.onAnnotationCreated?()
                        }
                        // 自由画线功能保持激活状态，直到用户手动点击按钮关闭
                        // 不自动恢复非注释模式，允许连续绘制多笔
                    }
                } else {
                    print("❌ AnnotationInteraction: ERROR - Failed to create freehand annotation")
                }
                
                // 重置状态
                isDrawing = false
                currentPath = []
                drawingPoints = []
                return nil // 拦截事件
            }
            return event
            
        case .note:
            // 注意：如果点击了现有note注释，事件在mouseDown时已经被拦截并跳转到批注功能区域了
            // 这里只处理点击空白区域的情况（创建新注释）
            // 双重检查：如果标记显示点击了现有注释，直接返回
            if clickedExistingAnnotation {
                print("📝 handleMouseUp: 标记显示点击了现有note注释，已跳转到批注功能区域")
                clickedExistingAnnotation = false
                return nil // 拦截事件，因为已经跳转到批注功能区域
            }
            
            // 再次检查点击位置是否在现有note注释上（双重检查，以防万一）
            print("🔍 handleMouseUp: 再次检查是否点击了现有note注释，point=\(point)")
            let hitAnnotation = findAnnotation(at: point, on: page, type: .text)
            
            if let existingAnnotation = hitAnnotation {
                // 如果到了这里，说明mouseDown时的检查可能没有生效
                // 跳转到批注功能区域
                print("📝 handleMouseUp: 检测到现有Note注释，跳转到批注功能区域: \(existingAnnotation.bounds)")
                DispatchQueue.main.async {
                    self.onEditRequested?(existingAnnotation)
                }
                return nil // 拦截事件
            } else {
                // 防止重复创建
                guard !isCreatingAnnotation else {
                    print("⚠️ 正在创建注释，忽略重复请求")
                    return nil
                }
                
                print("❌ handleMouseUp: 未找到现有注释，将创建新注释")
                isCreatingAnnotation = true
                
                // 创建新的Note注释
                let color = PDFAnnotationService.nsColor(from: selectedAnnotationColor)
                let annotation = PDFAnnotationService.createNote(
                    on: page,
                    at: point,
                    content: "",
                    color: color
                )
                // 刷新PDFView以显示注释
                DispatchQueue.main.async {
                    if let pdfView = self.pdfView {
                        // 保存当前缩放比例
                        let currentScale = pdfView.scaleFactor
                        
                        pdfView.setNeedsDisplay(pdfView.bounds)
                        pdfView.display()
                        
                        // 不调用go(to:)，避免页面位置重置
                        // 确保缩放比例不变
                        if pdfView.scaleFactor != currentScale {
                            pdfView.scaleFactor = currentScale
                        }
                        
                        // 创建note后，立即显示编辑界面
                        if let annotation = annotation {
                            print("✅ Note注释已创建: bounds=\(annotation.bounds)")
                            
                            // 将用户选择的颜色转换为 AnnotationColor
                            let annotationColor = AnnotationColor.from(self.selectedAnnotationColor)
                            print("📝 创建Note注释时使用的颜色: \(annotationColor)")
                            
                            // 立即通知注释已创建，触发同步（不等待保存）
                            DispatchQueue.main.async {
                                // 发送通知，让AnnotationModeView立即同步新创建的注释
                                // 在 userInfo 中传递颜色信息，避免从PDF注释推断颜色
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("PDFAnnotationCreated"),
                                    object: nil,
                                    userInfo: [
                                        "pdfAnnotation": annotation,
                                        "annotationColor": annotationColor
                                    ]
                                )
                            }
                            
                            // 将页面坐标转换为视图坐标，用于显示编辑界面
                            let viewPoint = pdfView.convert(point, from: page)
                            // 转换为窗口坐标
                            let windowPoint = pdfView.convert(viewPoint, to: nil)
                            
                            // 触发Note编辑请求回调（创建后立即编辑，跳转到批注功能区域）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.onEditRequested?(annotation)
                            }
                            
                            // 延迟一点再触发保存，确保注释已经完全添加到文档
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                print("📝 触发PDF保存回调...")
                                self.onAnnotationCreated?()
                            }
                            // Note创建后，立即恢复非注释模式（移除延迟，防止重复创建）
                            DispatchQueue.main.async {
                                self.isCreatingAnnotation = false // 清除创建标志
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("AnnotationCreatedResetTool"),
                                    object: nil
                                )
                            }
                        } else {
                            // 即使创建失败，也要清除创建标志
                            self.isCreatingAnnotation = false
                        }
                    }
                }
                
                return nil // 拦截事件
            }
            
        case .text:
            // Text工具：让PDFView自己处理创建和编辑
            // 不拦截事件，让PDFView在mouseUp时处理
            return event
            
        case .highlight, .underline, .strikeout:
            // 防止重复创建
            guard !isCreatingAnnotation else {
                print("⚠️ 正在创建注释，忽略重复请求")
                return nil
            }
            
            // 文本标注：检查是否有选中的文本
            if let selection = pdfView?.currentSelection as? PDFSelection,
               let selectionString = selection.string,
               !selectionString.isEmpty {
                isCreatingAnnotation = true
                let color = PDFAnnotationService.nsColor(from: selectedAnnotationColor)
                
                var createdAnnotation: PDFAnnotation? = nil
                switch selectedAnnotationTool {
                case .highlight:
                    createdAnnotation = PDFAnnotationService.createHighlight(
                        on: page,
                        selection: selection,
                        color: color
                    )
                    if let annotation = createdAnnotation {
                        print("AnnotationInteraction: Created highlight annotation: \(annotation.bounds)")
                    }
                case .underline:
                    createdAnnotation = PDFAnnotationService.createUnderline(
                        on: page,
                        selection: selection,
                        color: color
                    )
                    if let annotation = createdAnnotation {
                        print("AnnotationInteraction: Created underline annotation: \(annotation.bounds)")
                    }
                case .strikeout:
                    createdAnnotation = PDFAnnotationService.createStrikeout(
                        on: page,
                        selection: selection,
                        color: color
                    )
                    if let annotation = createdAnnotation {
                        print("AnnotationInteraction: Created strikeout annotation: \(annotation.bounds)")
                    }
                default:
                    break
                }
                
                // 刷新PDFView以显示注释
                DispatchQueue.main.async {
                    if let pdfView = self.pdfView {
                        // 保存当前缩放比例
                        let currentScale = pdfView.scaleFactor
                        
                        // 强制刷新PDFView
                        pdfView.setNeedsDisplay(pdfView.bounds)
                        pdfView.display()
                        
                        // 刷新当前页面
                        if let currentPage = pdfView.currentPage {
                            // 不调用go(to:)，避免页面位置重置
                            // 但需要确保页面刷新
                            pdfView.setNeedsDisplay(pdfView.bounds)
                            pdfView.display()
                        }
                        
                        // 确保缩放比例不变
                        if pdfView.scaleFactor != currentScale {
                            pdfView.scaleFactor = currentScale
                        }
                    }
                    
                    // 通知注释已创建，触发保存和同步
                    if let annotation = createdAnnotation {
                        print("✅ 文本标注注释已创建 (highlight/underline/strikeout)")
                        // 将用户选择的颜色转换为 AnnotationColor
                        let annotationColor = AnnotationColor.from(self.selectedAnnotationColor)
                        print("📝 创建注释时使用的颜色: \(annotationColor)")
                        // 立即通知注释已创建，触发同步（不等待保存）
                        DispatchQueue.main.async {
                            // 发送通知，让AnnotationModeView立即同步新创建的注释
                            // 在 userInfo 中传递颜色信息，避免从PDF注释推断颜色
                            NotificationCenter.default.post(
                                name: NSNotification.Name("PDFAnnotationCreated"),
                                object: nil,
                                userInfo: [
                                    "pdfAnnotation": annotation,
                                    "annotationColor": annotationColor
                                ]
                            )
                        }
                        // 延迟一点再触发保存，确保注释已经完全添加到文档
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("📝 触发PDF保存回调...")
                            self.onAnnotationCreated?()
                        }
                        // 文本注释创建后，立即恢复非注释模式（移除延迟，防止重复创建）
                        DispatchQueue.main.async {
                            self.isCreatingAnnotation = false // 清除创建标志
                            NotificationCenter.default.post(
                                name: NSNotification.Name("AnnotationCreatedResetTool"),
                                object: nil
                            )
                        }
                    } else {
                        print("❌ 文本标注注释创建失败")
                        // 即使创建失败，也要清除创建标志
                        self.isCreatingAnnotation = false
                    }
                }
                
                // 清除选择
                pdfView?.clearSelection()
                return nil // 拦截事件
            }
            return event
            
        default:
            return event
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    // MARK: - 辅助方法：查找点击位置的注释
    
    /// 查找点击位置的注释
    /// - Parameters:
    ///   - point: 点击位置（页面坐标）
    ///   - page: PDF页面
    ///   - type: 注释类型（可选，如果指定则只查找该类型的注释）
    /// - Returns: 找到的注释，如果没有则返回nil
    private func findAnnotation(at point: CGPoint, on page: PDFPage, type: PDFAnnotationSubtype? = nil) -> PDFAnnotation? {
        print("🔍 findAnnotation: 开始查找，point=\(point), type=\(type?.rawValue ?? "nil"), page annotations count=\(page.annotations.count)")
        
        // 遍历页面上的所有注释
        for (index, annotation) in page.annotations.enumerated() {
            let annotationTypeString = annotation.type ?? "nil"
            print("  [\(index)] 注释类型: '\(annotationTypeString)', bounds=\(annotation.bounds)")
            
            // 如果指定了类型，只检查匹配的类型
            // 注意：annotation.type 是 String?，需要与 PDFAnnotationSubtype 的 rawValue 比较
            if let requiredType = type {
                let requiredTypeString = requiredType.rawValue
                print("    比较: '\(annotationTypeString)' == '\(requiredTypeString)' ?")
                
                // PDFKit中，annotation.type 可能是 "/Text" 格式，而 rawValue 可能是 "Text"
                // 需要处理这两种情况
                let normalizedAnnotationType = annotationTypeString.hasPrefix("/") ? String(annotationTypeString.dropFirst()) : annotationTypeString
                let normalizedRequiredType = requiredTypeString.hasPrefix("/") ? String(requiredTypeString.dropFirst()) : requiredTypeString
                
                if normalizedAnnotationType != normalizedRequiredType && annotationTypeString != requiredTypeString {
                    print("    不匹配，跳过")
                    continue
                }
                print("    类型匹配！")
            }
            
            // 检查点击位置是否在注释的bounds内
            // 注意：bounds是页面坐标
            let bounds = annotation.bounds
            
            // 对于note注释，bounds可能很小（20x20），需要扩大点击区域以便于点击
            // 注意：annotation.type 是 String?，需要与 PDFAnnotationSubtype 的 rawValue 比较
            let hitTestBounds: CGRect
            let normalizedType = (annotation.type ?? "").hasPrefix("/") ? String((annotation.type ?? "").dropFirst()) : (annotation.type ?? "")
            
            if normalizedType == "Text" || normalizedType == PDFAnnotationSubtype.text.rawValue {
                // Note注释：扩大点击区域到24x24（因为图标现在是12x12），以图标中心为基准
                let expandedSize: CGFloat = 24
                hitTestBounds = CGRect(
                    x: bounds.midX - expandedSize / 2,
                    y: bounds.midY - expandedSize / 2,
                    width: expandedSize,
                    height: expandedSize
                )
                print("    Note注释，扩大点击区域: \(hitTestBounds)")
            } else if normalizedType == "FreeText" || normalizedType == PDFAnnotationSubtype.freeText.rawValue {
                // Text注释：使用原始bounds，但稍微扩大一点以便于点击
                let padding: CGFloat = 10
                hitTestBounds = bounds.insetBy(dx: -padding, dy: -padding)
                print("    Text注释，扩大点击区域: \(hitTestBounds)")
            } else {
                // 其他注释：使用原始bounds，稍微扩大一点
                let padding: CGFloat = 5
                hitTestBounds = bounds.insetBy(dx: -padding, dy: -padding)
                print("    其他注释，扩大点击区域: \(hitTestBounds)")
            }
            
            let contains = hitTestBounds.contains(point)
            print("    点击位置 \(point) 在 hitTestBounds 内: \(contains)")
            
            if contains {
                print("✅ 找到匹配的注释: type=\(annotationTypeString), bounds=\(bounds), hitTestBounds=\(hitTestBounds)")
                return annotation
            }
        }
        
        print("❌ 未找到匹配的注释")
        return nil
    }
    
    /// 在指定位置擦除自由画线注释（用于橡皮擦）
    /// - Parameters:
    ///   - point: 擦除位置（页面坐标）
    ///   - page: PDF页面
    private func eraseAnnotationAt(point: CGPoint, on page: PDFPage) {
        if let freehandAnnotation = findFreehandAnnotation(at: point, on: page) {
            // 检查是否已经擦除过（避免重复删除）
            if erasedAnnotations.contains(freehandAnnotation) {
                return
            }
            
            // 删除整条线
            page.removeAnnotation(freehandAnnotation)
            erasedAnnotations.insert(freehandAnnotation)
            print("✅ 橡皮擦：已删除自由画线注释")
            
            // 刷新PDFView（延迟刷新，避免频繁刷新影响性能）
            DispatchQueue.main.async { [weak self] in
                if let pdfView = self?.pdfView {
                    pdfView.setNeedsDisplay(pdfView.bounds)
                    pdfView.display()
                }
            }
        }
    }
    
    /// 查找点击位置的自由画线注释（用于橡皮擦）
    /// - Parameters:
    ///   - point: 点击位置（页面坐标）
    ///   - page: PDF页面
    /// - Returns: 找到的自由画线注释，如果没有则返回nil
    private func findFreehandAnnotation(at point: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        print("🔍 findFreehandAnnotation: 开始查找自由画线注释，point=\(point)")
        
        // 橡皮擦点击区域半径（与光标阴影半径一致）
        let eraserRadius: CGFloat = 10.0
        
        // 遍历页面上的所有注释，查找自由画线（Ink类型）
        for annotation in page.annotations {
            let annotationTypeString = annotation.type ?? ""
            let normalizedType = annotationTypeString.hasPrefix("/") ? String(annotationTypeString.dropFirst()) : annotationTypeString
            
            // 检查是否是自由画线注释（Ink类型）
            if normalizedType == "Ink" || normalizedType == PDFAnnotationSubtype.ink.rawValue {
                // 首先快速检查：点击位置是否在注释的bounds附近（优化性能）
                let bounds = annotation.bounds
                let quickCheckBounds = bounds.insetBy(dx: -eraserRadius * 2, dy: -eraserRadius * 2)
                if !quickCheckBounds.contains(point) {
                    continue // 快速跳过明显不在范围内的注释
                }
                
                // 精确检查：检查光标圆形区域是否与线条路径相交
                if isEraserCircleIntersectingWithAnnotation(annotation: annotation, center: point, radius: eraserRadius) {
                    print("✅ 找到自由画线注释（精确匹配）: bounds=\(bounds)")
                    return annotation
                }
            }
        }
        
        print("❌ 未找到自由画线注释")
        return nil
    }
    
    /// 检查橡皮擦圆形区域是否与自由画线注释的路径相交
    /// - Parameters:
    ///   - annotation: PDF注释
    ///   - center: 橡皮擦圆形中心点（页面坐标）
    ///   - radius: 橡皮擦圆形半径
    /// - Returns: 如果相交则返回true
    private func isEraserCircleIntersectingWithAnnotation(annotation: PDFAnnotation, center: CGPoint, radius: CGFloat) -> Bool {
        // 检查是否是 CustomInkAnnotation（我们自定义的类）
        guard let customInkAnnotation = annotation as? CustomInkAnnotation else {
            // 如果不是 CustomInkAnnotation，回退到 bounds 检查
            let bounds = annotation.bounds
            let expandedBounds = bounds.insetBy(dx: -radius, dy: -radius)
            return expandedBounds.contains(center)
        }
        
        // 获取路径点（相对于bounds的坐标）
        let inkPaths = customInkAnnotation.inkPaths
        let strokeWidth = customInkAnnotation.strokeWidth
        let annotationBounds = annotation.bounds
        
        // 计算实际的有效半径（考虑线条宽度）
        let effectiveRadius = radius + strokeWidth / 2.0
        
        // 遍历所有路径
        for path in inkPaths {
            guard path.count >= 2 else { continue }
            
            // 将路径点转换为页面坐标
            var previousPagePoint: CGPoint? = nil
            for relativePoint in path {
                let pagePoint = CGPoint(
                    x: annotationBounds.origin.x + relativePoint.x,
                    y: annotationBounds.origin.y + relativePoint.y
                )
                
                // 检查圆形中心是否在点附近（用于单点情况）
                let distanceToPoint = sqrt(
                    pow(center.x - pagePoint.x, 2) + pow(center.y - pagePoint.y, 2)
                )
                if distanceToPoint <= effectiveRadius {
                    return true
                }
                
                // 检查圆形是否与线段相交
                if let previousPoint = previousPagePoint {
                    if isCircleIntersectingLineSegment(
                        circleCenter: center,
                        circleRadius: effectiveRadius,
                        lineStart: previousPoint,
                        lineEnd: pagePoint
                    ) {
                        return true
                    }
                }
                
                previousPagePoint = pagePoint
            }
        }
        
        return false
    }
    
    /// 检查圆形是否与线段相交
    /// - Parameters:
    ///   - circleCenter: 圆心（页面坐标）
    ///   - circleRadius: 圆半径
    ///   - lineStart: 线段起点（页面坐标）
    ///   - lineEnd: 线段终点（页面坐标）
    /// - Returns: 如果相交则返回true
    private func isCircleIntersectingLineSegment(
        circleCenter: CGPoint,
        circleRadius: CGFloat,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> Bool {
        // 计算线段向量
        let lineVector = CGPoint(
            x: lineEnd.x - lineStart.x,
            y: lineEnd.y - lineStart.y
        )
        let lineLengthSquared = lineVector.x * lineVector.x + lineVector.y * lineVector.y
        
        // 如果线段长度为0，退化为点
        if lineLengthSquared < 0.0001 {
            let distance = sqrt(
                pow(circleCenter.x - lineStart.x, 2) + pow(circleCenter.y - lineStart.y, 2)
            )
            return distance <= circleRadius
        }
        
        // 计算从线段起点到圆心的向量
        let toCircleVector = CGPoint(
            x: circleCenter.x - lineStart.x,
            y: circleCenter.y - lineStart.y
        )
        
        // 计算投影参数 t（在线段上的位置，0-1之间）
        let t = max(0, min(1, (toCircleVector.x * lineVector.x + toCircleVector.y * lineVector.y) / lineLengthSquared))
        
        // 计算线段上距离圆心最近的点
        let closestPoint = CGPoint(
            x: lineStart.x + t * lineVector.x,
            y: lineStart.y + t * lineVector.y
        )
        
        // 计算圆心到最近点的距离
        let distance = sqrt(
            pow(circleCenter.x - closestPoint.x, 2) + pow(circleCenter.y - closestPoint.y, 2)
        )
        
        // 如果距离小于等于半径，则相交
        return distance <= circleRadius
    }
}

