//
// FloatingToolbar.swift
// HyperPaper
//
// 悬浮工具栏：Liquid Glass半透明按钮组
//

import SwiftUI
import PDFKit

struct FloatingToolbar: View {
    // MARK: - 状态绑定
    @Binding var pdfDocument: PDFDocument?
    @Binding var isSelectionMode: Bool
    @Binding var selectedText: String
    @Binding var showFilePicker: Bool
    @Binding var showPreferences: Bool
    @Binding var contentMode: ContentMode // 内容模式（Agent/批注）
    @Binding var selectedAnnotationTool: AnnotationTool // 选中的注释工具
    @Binding var selectedAnnotationColor: Color // 选中的注释颜色
    
    // MARK: - 回调
    var onClearSelection: () -> Void
    
    // MARK: - 动画命名空间（用于matchedGeometryEffect）
    @Namespace private var buttonAnimation
    
    // MARK: - 内部状态：控制清除图标的位置（避免重影）
    @State private var clearIconInButton: Bool = false
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 12) {
            // 左侧按钮组
            leftButtonGroup
                .fixedSize()
            
            Spacer()
            
            // 右侧按钮组
            rightButtonGroup
                .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackground.allowsHitTesting(false)) // 背景不拦截事件，让事件穿透
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .shadow(color: .white.opacity(0.1), radius: 4, y: -2)
        .padding(.top, 16)
        .padding(.horizontal, 16)
        // 只在按钮区域拦截事件，padding和阴影区域让事件穿透到PDF
    }
    
    // MARK: - 左侧按钮组
    private var leftButtonGroup: some View {
        HStack(spacing: 12) {
            // 打开文件按钮容器
            GlassEffectContainer(spacing: 0) {
                Button(action: {
                    showFilePicker = true
                }) {
                    Label("打开", systemImage: "folder")
                }
                .buttonStyle(LiquidGlassButtonStyle(
                    color: .gray,
                    isProminent: false,
                    isCapsule: true
                ))
                .glassEffect()
                .fixedSize()
            }
            
            if pdfDocument != nil {
                // 框选模式按钮容器（使用GlassEffectContainer实现分离/合并效果）
                let showClearButton = isSelectionMode && !selectedText.isEmpty
                
                GlassEffectContainer(spacing: showClearButton ? 12 : 0) {
                    HStack(spacing: showClearButton ? 12 : 0) {
                        // 框选模式按钮（主要按钮）
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isSelectionMode.toggle()
                                // 退出框选模式时，重置清除图标位置
                                if !isSelectionMode {
                                    clearIconInButton = false
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isSelectionMode ? "hand.draw.fill" : "hand.draw")
                                Text(isSelectionMode ? "退出框选" : "框选")
                                
                                // 清除图标：只在未分离时显示在按钮内部
                                if clearIconInButton && !showClearButton {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .opacity(0.7)
                                        .matchedGeometryEffect(id: "clearIcon", in: buttonAnimation)
                                }
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle(
                            color: isSelectionMode ? Color(red: 0.5, green: 0.2, blue: 0.8) : .gray,
                            isProminent: isSelectionMode,
                            isCapsule: true
                        ))
                        .glassEffect()
                        .fixedSize()
                        .onChange(of: isSelectionMode) { oldValue, newValue in
                            // 进入框选模式时，先显示清除图标在按钮内部
                            if newValue && !oldValue {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                                    clearIconInButton = true
                                }
                            }
                        }
                        .onChange(of: selectedText) { oldValue, newValue in
                            // 有选择时，延迟后让图标分离
                            if !newValue.isEmpty && oldValue.isEmpty && isSelectionMode {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        clearIconInButton = false
                                    }
                                }
                            } else if newValue.isEmpty {
                                // 清除选择后，图标回到按钮内部
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    clearIconInButton = true
                                }
                            }
                        }
                        
                        // 清除选择按钮（在框选模式且有选择时显示并分离）
                        if showClearButton {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    onClearSelection()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .matchedGeometryEffect(id: "clearIcon", in: buttonAnimation)
                                    Text("清除选择")
                                }
                            }
                            .buttonStyle(LiquidGlassButtonStyle(
                                color: .gray,
                                isProminent: false,
                                isCapsule: true
                            ))
                            .glassEffect()
                            .fixedSize()
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .leading)),
                                removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .leading))
                            ))
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelectionMode)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedText.isEmpty)
            }
        }
    }
    
    // MARK: - 右侧按钮组
    private var rightButtonGroup: some View {
        HStack(spacing: 12) {
            if pdfDocument != nil {
                // 注释工具组（仅在批注模式下显示）
                if contentMode == .annotation {
                    annotationToolGroup
                }
                
                // 偏好设置按钮容器
                GlassEffectContainer(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPreferences = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("偏好")
                        }
                    }
                    .buttonStyle(LiquidGlassButtonStyle(
                        color: .gray,
                        isProminent: false,
                        isCapsule: true
                    ))
                    .glassEffect()
                    .fixedSize()
                }
            }
        }
    }
    
    // MARK: - 注释工具组
    private var annotationToolGroup: some View {
        HStack(spacing: 8) {
            // 自由画线工具（圆形）
            annotationToolButton(
                tool: .freehand,
                systemImage: AnnotationTool.freehand.systemImage
            )
            
            // 橡皮擦工具（圆形）
            annotationToolButton(
                tool: .eraser,
                systemImage: AnnotationTool.eraser.systemImage
            )
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .frame(height: 36) // 与其他按钮高度一致（圆形按钮：8+20+8=36）
            
            // 文本标注类工具（高亮、下划线、删除线）- 圆形
            ForEach([AnnotationTool.highlight, .underline, .strikeout], id: \.self) { tool in
                annotationToolButton(
                    tool: tool,
                    systemImage: tool.systemImage
                )
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .frame(height: 36)
            
            // Note工具（圆形）
            annotationToolButton(
                tool: .note,
                systemImage: AnnotationTool.note.systemImage
            )
            
            // 添加文字工具（圆形）
            annotationToolButton(
                tool: .text,
                systemImage: AnnotationTool.text.systemImage
            )
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .frame(height: 36)
            
            // 颜色选择器
            ColorPickerButton(selectedColor: $selectedAnnotationColor)
                .fixedSize()
        }
        .fixedSize()
    }
    
    // MARK: - 注释工具按钮（圆形液态玻璃）
    private func annotationToolButton(tool: AnnotationTool, systemImage: String) -> some View {
        GlassEffectContainer(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if selectedAnnotationTool == tool {
                        selectedAnnotationTool = .none
                    } else {
                        selectedAnnotationTool = tool
                    }
                }
            }) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(CircularLiquidGlassButtonStyle(
                color: selectedAnnotationTool == tool ? Color(red: 0.5, green: 0.2, blue: 0.8) : .gray,
                isProminent: selectedAnnotationTool == tool
            ))
            .glassEffect()
        }
    }
    
    // MARK: - Liquid Glass背景效果
    private var toolbarBackground: some View {
        ZStack {
            // 基础Material层（超薄，高透明）
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
            
            // 微妙的渐变层（增强玻璃质感，降低不透明度提高通透感）
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 顶部高光（增强反光感）
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            
            // 高光边框（增强玻璃边缘反光效果）
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            
            // 内边框高光（增强通透感和反光感）
            RoundedRectangle(cornerRadius: 19)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

