//
//  TextAnnotationOverlay.swift
//  HyperPaper
//
//  文本注释输入覆盖层（参考 Apple 预览应用的实现方式）
//

import SwiftUI
import PDFKit
import AppKit

struct TextAnnotationOverlay: View {
    @Binding var isPresented: Bool
    let initialPosition: CGPoint // PDFView 坐标系的位置（视图坐标）
    let page: PDFPage
    let pdfView: PDFView?
    let color: Color
    let existingAnnotation: PDFAnnotation? // 现有注释（用于编辑模式）
    let onSave: (String, CGRect) -> Void // 保存文本和最终bounds
    let onDelete: (() -> Void)? // 删除回调（仅在编辑模式时提供）
    let onCancel: () -> Void
    
    @State private var text: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    init(
        isPresented: Binding<Bool>,
        initialPosition: CGPoint,
        page: PDFPage,
        pdfView: PDFView?,
        color: Color,
        existingAnnotation: PDFAnnotation? = nil,
        onSave: @escaping (String, CGRect) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.initialPosition = initialPosition
        self.page = page
        self.pdfView = pdfView
        self.color = color
        self.existingAnnotation = existingAnnotation
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        
        // 如果有现有注释，初始化文本内容
        let initialText = existingAnnotation?.contents ?? ""
        self._text = State(initialValue: initialText)
    }
    
    // 文本输入框的尺寸
    private let minWidth: CGFloat = 50
    private let minHeight: CGFloat = 30
    private let maxWidth: CGFloat = 210 // 宽度减半：从 400 改为 200
    private let padding: CGFloat = 8
    private let fixedEditorHeight: CGFloat = 60 // TextEditor 的固定高度（较小，内部可滚动）
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明背景，点击可关闭
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onCancel()
                    }
                
                // 文本输入视图
                textInputView(geometry: geometry)
            }
        }
    }
    
    // MARK: - 子视图构建器
    
    @ViewBuilder
    private func textInputView(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 文本输入框
            textFieldView
            
                    // 按钮栏
                    buttonBarView(isEditing: existingAnnotation != nil)
        }
        .frame(width: maxWidth) // 使用 maxWidth 而不是 minWidth
        .position(calculatedPosition(geometry: geometry))
    }
    
    @ViewBuilder
    private var textFieldView: some View {
        ZStack(alignment: .topLeading) {
            // 背景和边框
            textFieldBackground
            textFieldBorder
            
            // 占位符（当文本为空时显示）
            if text.isEmpty {
                Text("输入文本...")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary.opacity(0.6))
                    .padding(.horizontal, padding + 4) // TextEditor 内部有额外的 padding
                    .padding(.vertical, padding + 4)
                    .allowsHitTesting(false) // 不拦截点击事件
            }
            
            // TextEditor 支持真正的多行输入和换行
            // 固定高度，内部可以滚动
            TextEditor(text: $text)
                .font(.system(size: 12))
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden) // 隐藏默认背景
                .frame(width: maxWidth - padding * 2, height: fixedEditorHeight)
                .padding(padding)
                .focused($isTextFieldFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
        }
        .frame(width: maxWidth, height: fixedEditorHeight + padding * 2)
    }
    
    @ViewBuilder
    private func buttonBarView(isEditing: Bool) -> some View {
        HStack(spacing: 8) {
            // 编辑模式时显示删除按钮
            if isEditing, let onDelete = onDelete {
                deleteButton(onDelete: onDelete)
            }
            
            Spacer()
            
            cancelButton
            saveButton
        }
        .padding(.top, 6)
    }
    
    @ViewBuilder
    private func deleteButton(onDelete: @escaping () -> Void) -> some View {
        Button(action: {
            onDelete()
        }) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundColor(.red)
        }
        .buttonStyle(LiquidGlassButtonStyle(
            color: .red,
            isProminent: false,
            isCapsule: true
        ))
    }
    
    @ViewBuilder
    private var cancelButton: some View {
        Button(action: {
            onCancel()
        }) {
            Text("取消")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(LiquidGlassButtonStyle(
            color: .gray,
            isProminent: false,
            isCapsule: true
        ))
    }
    
    @ViewBuilder
    private var saveButton: some View {
        Button(action: {
            saveText()
        }) {
            Text("保存")
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(LiquidGlassButtonStyle(
            color: Color(NSColor(color)),
            isProminent: true,
            isCapsule: true
        ))
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    // MARK: - 计算属性
    
    private var textColor: Color {
        Color(NSColor(color))
    }
    
    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private var textFieldBorder: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color(NSColor(color)).opacity(0.5), lineWidth: 1)
    }
    
    
    private func calculatedPosition(geometry: GeometryProxy) -> CGPoint {
        // initialPosition 是窗口坐标（NSWindow 坐标系，原点在左下角）
        // 需要转换为相对于 SwiftUI 视图的坐标（视图坐标系，原点在左上角）
        
        var x = initialPosition.x
        var y = initialPosition.y
        
        // 如果提供了 pdfView 和 window，转换坐标
        if let pdfView = pdfView, let window = pdfView.window {
            // 窗口坐标系统：原点在左下角，Y向上
            // 视图坐标系统：原点在左上角，Y向下
            // 需要转换 Y 坐标
            let windowHeight = window.contentView?.bounds.height ?? window.frame.height
            let windowY = windowHeight - initialPosition.y // 转换为窗口坐标系（左上角原点）
            
            // 将窗口坐标转换为 PDFView 的视图坐标
            let windowPoint = NSPoint(x: initialPosition.x, y: windowY)
            let viewPoint = pdfView.convert(windowPoint, from: nil)
            
            x = viewPoint.x
            y = viewPoint.y
            
            Swift.print("✅ TextAnnotationOverlay.calculatedPosition: 使用坐标转换")
            Swift.print("  - initialPosition (窗口坐标，左下角原点): \(initialPosition)")
            Swift.print("  - windowHeight: \(windowHeight)")
            Swift.print("  - windowY (转换后，左上角原点): \(windowY)")
            Swift.print("  - viewPoint (PDFView坐标): \(viewPoint)")
        } else {
            Swift.print("✅ TextAnnotationOverlay.calculatedPosition: 直接使用坐标")
            Swift.print("  - initialPosition: \(initialPosition)")
        }
        
        // 边界检查：确保编辑框完全在可见区域内
        // 计算编辑框的总尺寸（包括按钮栏）
        let totalWidth = maxWidth
        let buttonBarHeight: CGFloat = 40 // 按钮栏的高度（包括 padding）
        let totalHeight = fixedEditorHeight + padding * 2 + buttonBarHeight
        
        // X 轴边界检查：确保编辑框不会超出左右边界
        let halfWidth = totalWidth / 2
        x = min(max(x, halfWidth + padding), geometry.size.width - halfWidth - padding)
        
        // Y 轴边界检查：确保编辑框不会超出上下边界
        let halfHeight = totalHeight / 2
        y = min(max(y, halfHeight + padding), geometry.size.height - halfHeight - padding)
        
        Swift.print("  - geometry.size: \(geometry.size)")
        Swift.print("  - calculated: (\(x), \(y))")
        
        return CGPoint(x: x, y: y)
    }
    
    private func saveText() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let pdfView = pdfView else {
            onCancel()
            return
        }
        
        // 计算文本的实际大小
        let font = NSFont.systemFont(ofSize: 10)
        
        // 创建段落样式，确保行间距正确
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2.0 // 添加行间距
        paragraphStyle.lineHeightMultiple = 1.0
        paragraphStyle.lineBreakMode = .byWordWrapping // 按单词换行
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        // 确保换行符被正确处理（\n 转换为换行）
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // 计算多行文本的大小
        let maxWidth = self.maxWidth - padding * 2
        
        // 使用 NSTextStorage 和 NSLayoutManager 来更准确地计算文本高度
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
        let textWidth = max(ceil(usedRect.width), minWidth - padding * 2)
        
        Swift.print("✅ TextAnnotationOverlay.saveText: 使用 NSLayoutManager 计算文本大小")
        Swift.print("  - usedRect: \(usedRect)")
        Swift.print("  - lineHeight: \(lineHeight)")
        Swift.print("  - topPadding: \(topPadding)")
        Swift.print("  - bottomPadding: \(bottomPadding)")
        Swift.print("  - textHeight (最终): \(textHeight)")
        
        // 将视图坐标转换为页面坐标
        let viewPoint = initialPosition
        let pagePoint = pdfView.convert(viewPoint, to: page)
        
        // 计算文本的bounds（考虑基线）
        // PDF坐标系：原点在左下角，y轴向上
        // 文本的baseline在bounds的底部
        // 如果是编辑模式，使用现有注释的bounds；否则从点击位置开始
        let bounds: CGRect
        if let existingAnnotation = existingAnnotation {
            // 编辑模式：保持原有位置，只更新高度
            let existingBounds = existingAnnotation.bounds
            bounds = CGRect(
                x: existingBounds.origin.x,
                y: existingBounds.origin.y,
                width: max(existingBounds.width, textWidth),
                height: textHeight
            )
        } else {
            // 新建模式：从点击位置开始，向下（y减小）扩展
            bounds = CGRect(
                x: pagePoint.x,
                y: pagePoint.y - textHeight, // 向下扩展
                width: textWidth,
                height: textHeight
            )
        }
        
        Swift.print("  - textWidth: \(textWidth)")
        Swift.print("  - bounds: \(bounds)")
        
        // 保存
        onSave(text, bounds)
    }
}

