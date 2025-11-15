//
//  NoteEditorOverlay.swift
//  HyperPaper
//
//  Note编辑界面覆盖层
//

import SwiftUI
import PDFKit

struct NoteEditorOverlay: View {
    @Binding var isPresented: Bool
    let annotation: PDFAnnotation?
    let position: CGPoint
    let color: Color
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var content: String
    @State private var isEditable: Bool
    
    init(
        isPresented: Binding<Bool>,
        annotation: PDFAnnotation?,
        position: CGPoint,
        color: Color,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.annotation = annotation
        self.position = position
        self.color = color
        self.onSave = onSave
        self.onCancel = onCancel
        
        // 初始化内容
        let initialContent = annotation?.contents ?? ""
        self._content = State(initialValue: initialContent)
        // 如果内容为空，默认可编辑；否则只展示，需要点击编辑按钮
        self._isEditable = State(initialValue: initialContent.isEmpty)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明背景，点击可关闭
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onCancel()
                    }
                
                // Note编辑视图
                NoteEditorView(
                    isPresented: $isPresented,
                    content: $content,
                    color: color,
                    isEditable: isEditable,
                    onSave: { newContent in
                        onSave(newContent)
                    },
                    onCancel: {
                        onCancel()
                    }
                )
                .position(
                    x: min(max(position.x, 150), geometry.size.width - 150),
                    y: min(max(position.y, 200), geometry.size.height - 200)
                )
            }
        }
    }
}

