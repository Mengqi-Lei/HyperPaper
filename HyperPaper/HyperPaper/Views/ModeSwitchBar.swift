//
// ModeSwitchBar.swift
// HyperPaper
//
// 模式切换栏：Agent模式 / 批注模式
//

import SwiftUI

// MARK: - 内容模式枚举
enum ContentMode: String, CaseIterable {
    case agent = "agent"           // Agent模式（问答功能）
    case annotation = "annotation" // 批注模式
    
    var displayName: String {
        switch self {
        case .agent: return "Agent模式"
        case .annotation: return "批注模式"
        }
    }
    
    var systemImage: String {
        switch self {
        case .agent: return "sparkles"
        case .annotation: return "note.text"
        }
    }
}

// MARK: - 模式切换栏组件
struct ModeSwitchBar: View {
    @Binding var currentMode: ContentMode
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ContentMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 12, weight: currentMode == mode ? .semibold : .medium))
                            .symbolVariant(currentMode == mode ? .fill : .none)
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: currentMode == mode ? .semibold : .medium))
                    }
                    .foregroundColor(currentMode == mode ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if currentMode == mode {
                                // 选中状态：深紫色背景，带渐变和光泽
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.5, green: 0.2, blue: 0.8),
                                                    Color(red: 0.45, green: 0.15, blue: 0.75)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    // 光泽效果
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .center
                                            )
                                        )
                                }
                            } else {
                                // 未选中状态：透明，悬停时显示背景
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clear)
                            }
                        }
                    )
                    .contentShape(Rectangle()) // 让整个区域可点击
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            ZStack {
                // Liquid Glass 背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                
                // 微妙的渐变层
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 边框
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // 细描边
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .shadow(color: .white.opacity(0.1), radius: 2, y: -1)
    }
}

// MARK: - 预览
#Preview {
    ModeSwitchBar(currentMode: .constant(.agent))
        .padding()
        .frame(width: 300)
}

