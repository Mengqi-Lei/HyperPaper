//
//  NoteEditorView.swift
//  HyperPaper
//
//  Note注释编辑/展示视图
//

import SwiftUI
import PDFKit

struct NoteEditorView: View {
    @Binding var isPresented: Bool
    @Binding var content: String
    let color: Color
    let isEditable: Bool
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editingContent: String
    @State private var isEditing: Bool
    
    init(
        isPresented: Binding<Bool>,
        content: Binding<String>,
        color: Color,
        isEditable: Bool = true,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self._content = content
        self.color = color
        self.isEditable = isEditable
        self.onSave = onSave
        self.onCancel = onCancel
        
        // 初始化编辑内容
        let initialContent = content.wrappedValue
        self._editingContent = State(initialValue: initialContent)
        // 如果内容为空，默认进入编辑模式；如果isEditable为true，也进入编辑模式
        self._isEditing = State(initialValue: initialContent.isEmpty || isEditable)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            if isEditing {
                // 编辑模式
                TextEditor(text: $editingContent)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(minHeight: 100, maxHeight: 200)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
            } else {
                // 展示模式
                ScrollView {
                    Text(content.isEmpty ? "（空）" : content)
                        .font(.system(size: 14))
                        .foregroundColor(content.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(minHeight: 60, maxHeight: 200)
            }
            
            Divider()
                .padding(.horizontal, 12)
            
            // 底部按钮区域
            HStack(spacing: 12) {
                if isEditing {
                    // 编辑模式：取消和确认按钮
                    Button("取消") {
                        editingContent = content
                        isEditing = false
                        if content.isEmpty {
                            // 如果内容为空，取消时关闭编辑界面
                            onCancel()
                        }
                    }
                    .buttonStyle(LiquidGlassButtonStyle(
                        color: .gray,
                        isProminent: false,
                        isCapsule: true
                    ))
                    
                    Spacer()
                    
                    Button("确认") {
                        content = editingContent
                        isEditing = false
                        onSave(editingContent)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(
                        color: color,
                        isProminent: true,
                        isCapsule: true
                    ))
                } else {
                    // 展示模式：编辑按钮
                    Spacer()
                    
                    Button(action: {
                        isEditing = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("编辑")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.6),
                                    color.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

