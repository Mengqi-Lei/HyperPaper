//
// ColorPickerButton.swift
// HyperPaper
//
// 颜色选择器按钮：用于注释工具的颜色选择
//

import SwiftUI

struct ColorPickerButton: View {
    @Binding var selectedColor: Color
    @State private var showColorPicker: Bool = false
    
    // 预设颜色列表（参考Zotero风格）
    private let presetColors: [Color] = [
        .yellow,      // 黄色（高亮常用）
        .green,       // 绿色
        .blue,        // 蓝色
        .red,         // 红色
        .orange,      // 橙色
        .purple,      // 紫色
        .pink,        // 粉色
        .gray         // 灰色
    ]
    
    var body: some View {
        Menu {
            // 预设颜色
            ForEach(presetColors, id: \.self) { color in
                Button(action: {
                    selectedColor = color
                }) {
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                        Text(colorName(color))
                    }
                }
            }
            
            Divider()
            
            // 自定义颜色选择器
            Button(action: {
                showColorPicker = true
            }) {
                Label("自定义颜色", systemImage: "eyedropper")
            }
        } label: {
            GlassEffectContainer(spacing: 0) {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 28, height: 28) // 颜色选择按钮稍小一些
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showColorPicker) {
            ColorPicker("选择颜色", selection: $selectedColor)
                .padding()
        }
    }
    
    private func colorName(_ color: Color) -> String {
        // 简单的颜色名称映射
        if color == .yellow { return "黄色" }
        if color == .green { return "绿色" }
        if color == .blue { return "蓝色" }
        if color == .red { return "红色" }
        if color == .orange { return "橙色" }
        if color == .purple { return "紫色" }
        if color == .pink { return "粉色" }
        if color == .gray { return "灰色" }
        return "自定义"
    }
}

