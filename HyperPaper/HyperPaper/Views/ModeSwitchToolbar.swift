//
// ModeSwitchToolbar.swift
// HyperPaper
//
// 模式切换工具栏：悬浮在功能区域上方，参考FloatingToolbar设计
//

import SwiftUI

// MARK: - 模式切换工具栏
struct ModeSwitchToolbar: View {
    @Binding var currentMode: ContentMode
    var onCollapse: () -> Void // 折叠回调
    
    var body: some View {
        HStack(spacing: 8) {
            // Agent模式按钮
            GlassEffectContainer(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentMode = .agent
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Agent")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(
                    color: currentMode == .agent ? Color(red: 0.5, green: 0.2, blue: 0.8) : .gray,
                    isProminent: currentMode == .agent,
                    isCapsule: true
                ))
                .glassEffect()
            }
            
            // 批注模式按钮
            GlassEffectContainer(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentMode = .annotation
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                        Text("批注")
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(
                    color: currentMode == .annotation ? Color(red: 0.5, green: 0.2, blue: 0.8) : .gray,
                    isProminent: currentMode == .annotation,
                    isCapsule: true
                ))
                .glassEffect()
            }
            
            // 折叠按钮（圆形）
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onCollapse()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        ZStack {
                            // 基础玻璃材质
                            Circle()
                                .fill(.thinMaterial)
                            
                            // 蓝色渐变背景（鲜艳的蓝色）
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.5, blue: 1.0), // 鲜艳的蓝色
                                            Color(red: 0.0, green: 0.4, blue: 0.9)
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
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                    .shadow(color: Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.4), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .help("折叠问答面板")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackground.allowsHitTesting(false)) // 背景不拦截事件
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .shadow(color: .white.opacity(0.1), radius: 4, y: -2)
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Liquid Glass背景效果（与FloatingToolbar一致）
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

// MARK: - Glass Effect Container（如果不存在则创建）
// 注意：这个容器只是一个简单的布局容器，不添加额外的背景层
// 按钮的视觉样式由LiquidGlassButtonStyle提供
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}

// MARK: - Glass Effect Modifier
struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func glassEffect() -> some View {
        modifier(GlassEffectModifier())
    }
}

