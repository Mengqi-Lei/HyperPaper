//
//  MarkdownLaTeXViewTestView.swift
//  HyperPaper
//
//  MarkdownLaTeXView 独立测试视图
//  用于测试和验证 Markdown 和 LaTeX 渲染功能
//

import SwiftUI

struct MarkdownLaTeXViewTestView: View {
    @State private var testContent: String = """
# Markdown 和 LaTeX 测试

这是一个**粗体文本**，这是一个*斜体文本*。

## 数学公式测试

### 行内公式
质能方程: $E = mc^2$

### 块级公式
$$
\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
$$

$$
C_{ij} = \\rho\\Big( \\mathbf{F}_{i,:} , \\mathbf{S}_{j,:} \\Big)
$$

### 复杂公式
$$
X^{(l+1)} = \\sigma\\Bigl( D_{v}^{-\\frac{1}{2}} H D_{e}^{-1} H^{\\top} D_{v}^{-\\frac{1}{2}} X^{l} \\, \\Theta^{(l)} \\Bigr)
$$

## 代码测试

行内代码: `let x = 10`

代码块:
```
func hello() {
    print("Hello, World!")
}
```

## 列表测试

1. 第一项
2. 第二项
3. 第三项

- 无序列表项1
- 无序列表项2

## 链接测试

[这是一个链接](https://example.com)

## 混合内容

这是一段包含**粗体**、*斜体*和行内公式 $x^2 + y^2 = r^2$ 的文本。

然后是一个块级公式：

$$
\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
$$

这是公式后的文本。
"""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MarkdownLaTeXView 测试")
                .font(.largeTitle)
                .padding()
            
            // 输入区域
            VStack(alignment: .leading, spacing: 8) {
                Text("测试内容（可编辑）:")
                    .font(.headline)
                
                TextEditor(text: $testContent)
                    .frame(height: 200)
                    .border(Color.gray.opacity(0.3), width: 1)
            }
            .padding()
            
            Divider()
            
            // 渲染区域
            VStack(alignment: .leading, spacing: 8) {
                Text("渲染结果:")
                    .font(.headline)
                
                ScrollView {
                    MarkdownLaTeXView(content: testContent)
                        .frame(maxWidth: .infinity, minHeight: 400, alignment: .topLeading)
                        .padding()
                }
                .frame(height: 400)
                .border(Color.gray.opacity(0.3), width: 1)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    MarkdownLaTeXViewTestView()
}

