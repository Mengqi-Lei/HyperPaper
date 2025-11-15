//
// ScrollWheelHandler.swift
// HyperPaper
//
// 滚轮事件处理器（SwiftUI层面）
//

import SwiftUI
import AppKit
import PDFKit

struct ScrollWheelHandler: NSViewRepresentable {
    @Binding var pdfView: PDFView?
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelView()
        view.pdfView = pdfView
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView as? ScrollWheelView {
            scrollView.pdfView = pdfView
        }
    }
}

class ScrollWheelView: NSView {
    weak var pdfView: PDFView?
    private var eventMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // 透明背景
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // 不拦截鼠标事件，让事件穿透
        // 只通过全局事件监听器处理缩放
        
        // 设置全局事件监听
        setupGlobalEventMonitor()
    }
    
    private func setupGlobalEventMonitor() {
        // 使用全局事件监听，捕获所有滚轮事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            guard let self = self, let pdfView = self.pdfView else { return event }
            
            // 检查鼠标是否在PDFView范围内
            if pdfView.window != nil {
                let mouseLocation = event.locationInWindow
                let viewLocation = pdfView.convert(mouseLocation, from: nil)
                
                // 只在鼠标在PDFView范围内时处理
                guard pdfView.bounds.contains(viewLocation) else {
                    return event
                }
            }
            
            // 检查是否有Cmd或Ctrl修饰键
            let hasModifier = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
            
            if hasModifier {
                // Cmd/Ctrl + 滚轮：缩放
                let deltaY = event.scrollingDeltaY
                
                // 计算缩放增量
                let magnification: CGFloat = deltaY > 0 ? 1.05 : 0.95
                
                // 获取当前缩放比例
                let currentScale = pdfView.scaleFactor
                
                // 计算新的缩放比例
                let newScale = currentScale * magnification
                
                // 限制在缩放范围内
                let clampedScale = max(pdfView.minScaleFactor, min(pdfView.maxScaleFactor, newScale))
                
                // 使用KVC设置缩放比例
                pdfView.setValue(clampedScale, forKey: "scaleFactor")
                
                // 阻止事件继续传播（因为我们已经处理了）
                return nil
            }
            
            // 普通滚轮：让事件继续传播到PDFView（允许滚动）
            // 注意：即使是在选择模式下，也应该允许滚动
            return event
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        // 不处理普通滚轮事件，让事件穿透到PDFView
        // 缩放由全局事件监听器处理
        // 如果全局监听器没有处理（没有修饰键），事件会继续传播到PDFView
        super.scrollWheel(with: event)
    }
    
    // 让事件穿透到PDFView
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 返回nil，让事件穿透到下层视图
        return nil
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

