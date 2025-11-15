//
//  MarkdownLaTeXView.swift
//  HyperPaper
//
//  Markdown 和 LaTeX 渲染组件
//  使用 WKWebView + MathJax 实现
//  重构版本：采用MathJax方案，自动处理原始文本，无需手动清理
//

import SwiftUI
import WebKit

/// Markdown 和 LaTeX 渲染视图
/// 
/// 支持：
/// - Markdown 语法（标题、列表、粗体、斜体等）
/// - LaTeX 数学公式（行内公式 `$...$` 和块级公式 `$$...$$`）
/// - 文本选择（用于复制）
/// - 深色/浅色模式自适应
/// 
/// **关键优势**：
/// - MathJax会自动删除原始LaTeX标记，无需手动清理
/// - 更完整的LaTeX支持
/// - 更灵活的配置选项
struct MarkdownLaTeXView: NSViewRepresentable {
    /// 要渲染的内容（Markdown + LaTeX）
    let content: String
    
    /// 是否启用文本选择
    var isTextSelectable: Bool = true
    
    /// 自定义样式（可选）
    var customStyle: String = ""
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.isElementFullscreenEnabled = false
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // 配置 WebView
        webView.setValue(false, forKey: "drawsBackground") // 透明背景
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(true, forKey: "allowsLinkPreview") // 允许链接预览
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // 生成 HTML 并加载
        let html = generateHTML(from: content)
        
        // 每次更新都重新加载 HTML
        DispatchQueue.main.async {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadError: ((Error) -> Void)?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 页面加载完成后，等待MathJax加载并触发typeset
            // MathJax 3.x使用typesetPromise，需要等待脚本加载完成
            webView.evaluateJavaScript("""
                (function() {
                    function checkAndTypeset() {
                        if (window.MathJax && window.MathJax.typesetPromise) {
                            console.log('✅ MathJax已加载，开始typeset...');
                            MathJax.typesetPromise().then(() => {
                                console.log('✅ MathJax typeset完成');
                            }).catch((err) => {
                                console.error('❌ MathJax typeset失败:', err);
                            });
                            return true;
                        }
                        return false;
                    }
                    
                    // 立即检查
                    if (!checkAndTypeset()) {
                        // 如果还没加载，等待一段时间后重试
                        setTimeout(function() {
                            if (!checkAndTypeset()) {
                                console.warn('⚠️ MathJax未能在预期时间内加载');
                            }
                        }, 500);
                    }
                })();
            """) { result, error in
                // MathJax typeset完成
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadError?(error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadError?(error)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 阻止外部链接导航
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
    
    /// 生成包含 MathJax 和 Markdown 的 HTML
    private func generateHTML(from content: String) -> String {
        // 检测并转换 Markdown 为 HTML
        let htmlContent = convertMarkdownToHTML(content)
        
        // 获取当前外观模式
        let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
        
        // 预先计算颜色值，避免在原始字符串中直接使用三元运算符
        let bodyColor = isDarkMode ? "#E5E5E5" : "#1D1D1F"
        let blockquoteBorderColor = isDarkMode ? "rgba(255, 255, 255, 0.3)" : "rgba(0, 0, 0, 0.2)"
        let blockquoteTextColor = isDarkMode ? "rgba(255, 255, 255, 0.7)" : "rgba(0, 0, 0, 0.6)"
        let codeBackground = isDarkMode ? "rgba(255, 255, 255, 0.1)" : "rgba(0, 0, 0, 0.05)"
        let preBackground = isDarkMode ? "rgba(255, 255, 255, 0.05)" : "rgba(0, 0, 0, 0.03)"
        let linkColor = isDarkMode ? "#5AC8FA" : "#007AFF"
        let selectionBackground = isDarkMode ? "rgba(90, 200, 250, 0.3)" : "rgba(0, 122, 255, 0.2)"
        
        // 使用原始字符串（raw string）避免JavaScript配置的转义问题
        return #"""
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Markdown LaTeX Renderer</title>
            
            <!-- MathJax 3.2.2 Configuration -->
            <script>
                window.MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\(', '\\)']],
                        displayMath: [['$$', '$$'], ['\\[', '\\]']],
                        processEscapes: true,
                        processEnvironments: true
                    },
                    options: {
                        skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
                        ignoreHtmlClass: 'tex2jax_ignore',
                        processHtmlClass: 'tex2jax_process'
                    }
                };
            </script>
            
            <!-- MathJax 3.2.2 Script -->
            <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js" id="MathJax-script" async></script>
            
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    overflow: visible;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Helvetica Neue", Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 16px;
                    background: transparent;
                    color: \#(bodyColor);
                    overflow-wrap: break-word;
                    word-wrap: break-word;
                    min-height: fit-content;
                }
                
                #content {
                    width: 100%;
                    min-height: fit-content;
                }
                
                /* Markdown 样式 */
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 1em;
                    margin-bottom: 0.5em;
                    font-weight: 600;
                    line-height: 1.25;
                }
                
                h1 { font-size: 1.75em; }
                h2 { font-size: 1.5em; }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1.1em; }
                h5 { font-size: 1em; }
                h6 { font-size: 0.9em; }
                
                p {
                    margin: 0.5em 0;
                }
                
                ul, ol {
                    margin: 0.5em 0;
                    padding-left: 2em;
                }
                
                li {
                    margin: 0.25em 0;
                }
                
                blockquote {
                    margin: 0.5em 0;
                    padding-left: 1em;
                    border-left: 3px solid \#(blockquoteBorderColor);
                    color: \#(blockquoteTextColor);
                }
                
                code {
                    font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace;
                    font-size: 0.9em;
                    padding: 0.2em 0.4em;
                    background: \#(codeBackground);
                    border-radius: 3px;
                }
                
                pre {
                    margin: 0.5em 0;
                    padding: 1em;
                    background: \#(preBackground);
                    border-radius: 6px;
                    overflow-x: auto;
                }
                
                pre code {
                    padding: 0;
                    background: transparent;
                }
                
                strong {
                    font-weight: 600;
                }
                
                em {
                    font-style: italic;
                }
                
                a {
                    color: \#(linkColor);
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                /* MathJax 样式调整 */
                .MathJax {
                    font-size: 1.1em;
                }
                
                .MathJax_SVG {
                    display: inline-block;
                }
                
                .MathJax_SVG_Display {
                    margin: 1em 0;
                    overflow-x: auto;
                    overflow-y: hidden;
                }
                
                /* 文本选择 */
                ::selection {
                    background: \#(selectionBackground);
                }
                
                /* 自定义样式 */
                \#(customStyle)
            </style>
        </head>
        <body>
            <div id="content" class="tex2jax_process">
                \#(htmlContent)
            </div>
        </body>
        </html>
        """#
    }
    
    /// 转义 HTML 特殊字符
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    /// 将 Markdown 转换为 HTML
    /// 
    /// 这是一个简化的 Markdown 解析器，支持基本语法
    /// 关键：在转换过程中保护LaTeX公式，确保MathJax能正确识别
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // 如果内容为空，返回占位文本
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "<p style='color: #999; font-style: italic;'>内容为空</p>"
        }
        
        var html = markdown
        
        // 第一步：保护 LaTeX 公式，避免被 Markdown 解析影响
        var latexBlocks: [String] = []
        // 匹配 LaTeX 公式：$$...$$, $...$, \[...\], \(...\)
        let latexPattern = #"\$\$[\s\S]*?\$\$|\$[^\$]+\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\)"#
        let regex = try! NSRegularExpression(pattern: latexPattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        // 从后往前替换，避免索引偏移
        var processedMatches: [(range: Range<String.Index>, latex: String)] = []
        for match in matches.reversed() {
            if let range = Range(match.range, in: html) {
                let latex = String(html[range])
                processedMatches.append((range: range, latex: latex))
            }
        }
        
        // 替换 LaTeX 为占位符
        for (index, matchInfo) in processedMatches.enumerated() {
            let placeholder = "LATEXPLACEHOLDER\(index)LATEXPLACEHOLDER"
            latexBlocks.append(matchInfo.latex)
            html.replaceSubrange(matchInfo.range, with: placeholder)
        }
        
        // 第二步：Markdown 转换
        let regexOptions: String.CompareOptions = .regularExpression
        
        // 标题（使用多行模式）
        html = html.replacingOccurrences(of: #"(?m)^### (.*?)$"#, with: "<h3>$1</h3>", options: regexOptions)
        html = html.replacingOccurrences(of: #"(?m)^## (.*?)$"#, with: "<h2>$1</h2>", options: regexOptions)
        html = html.replacingOccurrences(of: #"(?m)^# (.*?)$"#, with: "<h1>$1</h1>", options: regexOptions)
        
        // 粗体
        html = html.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "<strong>$1</strong>", options: regexOptions)
        html = html.replacingOccurrences(of: #"__(.*?)__"#, with: "<strong>$1</strong>", options: regexOptions)
        
        // 斜体
        html = html.replacingOccurrences(of: #"\*(.*?)\*"#, with: "<em>$1</em>", options: regexOptions)
        html = html.replacingOccurrences(of: #"_(.*?)_"#, with: "<em>$1</em>", options: regexOptions)
        
        // 代码块
        html = html.replacingOccurrences(of: #"```([\s\S]*?)```"#, with: "<pre><code>$1</code></pre>", options: regexOptions)
        
        // 行内代码
        html = html.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: regexOptions)
        
        // 链接
        html = html.replacingOccurrences(of: #"\[([^\]]+)\]\(([^\)]+)\)"#, with: "<a href=\"$2\">$1</a>", options: regexOptions)
        
        // 第三步：恢复 LaTeX 公式（从后往前恢复，避免索引问题）
        for (index, latex) in latexBlocks.enumerated().reversed() {
            let placeholder = "LATEXPLACEHOLDER\(index)LATEXPLACEHOLDER"
            // LaTeX 公式直接插入，不需要转义（MathJax 会处理）
            html = html.replacingOccurrences(of: placeholder, with: latex, options: [])
        }
        
        // 第四步：转换换行，但需要再次保护LaTeX公式
        // 方法：再次匹配LaTeX公式，保护它们，转换换行，然后恢复
        var finalLatexBlocks: [String] = []
        let finalLatexPattern = #"\$\$[\s\S]*?\$\$|\$[^\$]+\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\)"#
        let finalRegex = try! NSRegularExpression(pattern: finalLatexPattern, options: [])
        let finalMatches = finalRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        var finalProcessedMatches: [(range: Range<String.Index>, latex: String)] = []
        for match in finalMatches.reversed() {
            if let range = Range(match.range, in: html) {
                let latex = String(html[range])
                finalProcessedMatches.append((range: range, latex: latex))
            }
        }
        
        // 替换 LaTeX 为占位符
        for (index, matchInfo) in finalProcessedMatches.enumerated() {
            let placeholder = "FINALATEXPLACEHOLDER\(index)FINALATEXPLACEHOLDER"
            finalLatexBlocks.append(matchInfo.latex)
            html.replaceSubrange(matchInfo.range, with: placeholder)
        }
        
        // 转换换行
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        // 恢复 LaTeX 公式
        for (index, latex) in finalLatexBlocks.enumerated().reversed() {
            let placeholder = "FINALATEXPLACEHOLDER\(index)FINALATEXPLACEHOLDER"
            html = html.replacingOccurrences(of: placeholder, with: latex, options: [])
        }
        
        return html
    }
}
