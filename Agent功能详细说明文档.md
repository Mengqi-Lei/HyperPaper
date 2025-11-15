# HyperPaper Agent 功能详细文档

**版本**: v1.0  
**最后更新**: 2025-01-XX  
**作者**: HyperPaper Team

---

## 📋 目录

1. [功能概述](#功能概述)
2. [架构设计](#架构设计)
3. [核心功能模块](#核心功能模块)
4. [工作流程](#工作流程)
5. [AI服务集成](#ai服务集成)
6. [配置说明](#配置说明)
   - [API Key 配置方法](#api-key-配置方法)
   - [环境变量设置](#环境变量设置)
   - [偏好设置说明](#偏好设置说明)
7. [技术实现细节](#技术实现细节)
8. [数据流](#数据流)
9. [错误处理](#错误处理)
10. [性能优化](#性能优化)
11. [未来规划](#未来规划)

---

## 功能概述

### 什么是 Agent 模式？

Agent 模式是 HyperPaper 的核心智能功能，它允许用户通过框选 PDF 文档中的任意区域，与 AI 进行交互，实现：

- **区域问答**：基于选中内容提问，获得精准回答
- **智能翻译**：自动识别语言并翻译为指定目标语言
- **OCR 识别**：识别包含公式、图表的区域，转换为可编辑文本
- **公式处理**：自动识别数学公式并转换为 LaTeX 格式
- **多区域支持**：支持跨页选择，统一处理多个区域

### 核心价值

1. **上下文理解**：AI 基于用户选中的具体内容回答问题，而非整篇文档
2. **多模态处理**：同时支持文本、图像、公式的识别和理解
3. **实时反馈**：OCR 进度可视化，翻译结果实时更新
4. **智能降级**：当 Vision API 失败时，自动降级到文本提取

---

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        MainView                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              ContentMode: .agent                         │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              QuestionAnswerViewWrapper                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ 文本显示区域  │  │ 翻译功能区域  │  │ 问答功能区域  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PDFReaderView                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │          AnnotationInteractionNSView                  │  │
│  │  - 区域选择                                            │  │
│  │  - 文本提取                                            │  │
│  │  - 图像提取                                            │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│PDFTextExtractor│ │PDFImageExtractor│ │Pix2TextService│
└──────────────┘  └──────────────┘  └──────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │QwenAPIService │
                    └──────────────┘
```

### 模块划分

#### 1. UI 层
- **QuestionAnswerViewWrapper**: Agent 模式的主视图
- **MarkdownLaTeXView**: Markdown 和 LaTeX 渲染组件

#### 2. 业务逻辑层
- **PDFReaderView**: PDF 渲染和交互处理
- **AnnotationInteractionNSView**: 区域选择和文本提取

#### 3. 服务层
- **QwenAPIService**: AI 服务封装（问答、翻译、Vision API）
- **Pix2TextService**: 本地 OCR 服务
- **PDFTextExtractor**: PDF 文本提取
- **PDFImageExtractor**: PDF 图像提取

---

## 核心功能模块

### 1. 区域选择与文本提取

#### 功能描述
用户可以通过拖拽在 PDF 上框选任意区域，系统自动提取该区域的文本内容。

#### 实现位置
- `PDFReaderView.swift` - `AnnotationInteractionNSView`
- `PDFTextExtractor.swift`

#### 工作流程

```
用户拖拽选择区域
    │
    ▼
AnnotationInteractionNSView.mouseDragged
    │
    ▼
创建 SelectionRegion (pageIndex, rect)
    │
    ▼
PDFTextExtractor.extractText
    │
    ▼
PDFPage.selection(for: rect)
    │
    ▼
更新 selectedText (通过 @Binding)
    │
    ▼
QuestionAnswerViewWrapper 显示文本
```

#### 关键代码

```swift
// PDFTextExtractor.swift
static func extractText(from document: PDFDocument, 
                       pageIndex: Int, 
                       rect: CGRect) -> String? {
    guard let page = document.page(at: pageIndex) else {
        return nil
    }
    
    guard let selection = page.selection(for: rect) else {
        return nil
    }
    
    return selection.string
}
```

#### 多区域支持

系统支持跨页选择多个区域，所有区域的文本会自动合并：

```swift
// 合并多个区域的文本
let combinedText = regions
    .compactMap { extractText(from: document, pageIndex: $0.pageIndex, rect: $0.rect) }
    .joined(separator: "\n\n")
```

---

### 2. OCR 识别功能

#### 功能描述
当用户选择的区域包含图像、公式或无法直接提取文本时，系统自动触发 OCR 识别。

#### 实现位置
- `PDFReaderView.swift` - `processSelectionWithOCR`
- `Pix2TextService.swift`
- `PDFImageExtractor.swift`

#### 工作流程

```
检测到选择区域
    │
    ▼
尝试文本提取
    │
    ├─ 成功 → 直接使用文本
    │
    └─ 失败/空文本 → 触发 OCR
        │
        ▼
检查公式处理模式 (FormulaProcessingMode)
    │
    ├─ .none → 跳过 OCR
    │
    ├─ .localOCR → 使用 Pix2Text
    │   │
    │   ├─ 提取图像 (PDFImageExtractor)
    │   │
    │   ├─ 保存临时文件
    │   │
    │   ├─ 调用 Python 脚本 (pix2text_ocr.py)
    │   │
    │   ├─ 解析进度 (从 stderr 读取 tqdm 输出)
    │   │
    │   └─ 返回 Markdown 格式结果 (含 LaTeX)
    │
    └─ .vlmAPI → 使用 Vision API
        │
        ├─ 提取图像 (PDFImageExtractor)
        │
        ├─ 转换为 Base64
        │
        └─ 调用 QwenAPIService.recognizeImage
```

#### OCR 进度管理

系统通过 `NotificationCenter` 实现 OCR 进度的实时更新：

```swift
// 发送进度更新通知
NotificationCenter.default.post(
    name: NSNotification.Name("OCRProgressUpdate"),
    object: nil,
    userInfo: ["progress": progress, "completed": false]
)

// 发送完成通知
NotificationCenter.default.post(
    name: NSNotification.Name("OCRCompleted"),
    object: nil,
    userInfo: ["completed": true]
)
```

#### Pix2Text 集成

Pix2Text 通过 Python 脚本调用，支持：
- 数学公式识别（转换为 LaTeX）
- 表格识别
- 混合布局识别
- 进度反馈（通过 stderr 输出）

**脚本路径查找策略**：
1. App Bundle 内的脚本
2. 项目目录中的脚本（开发时）
3. 环境变量或硬编码路径

**进度解析**：
- 从 stderr 读取 tqdm 输出
- 解析百分比或分数格式（如 "50%" 或 "1/2"）
- 模拟进度（如果无法解析真实进度）

---

### 3. 智能翻译功能

#### 功能描述
自动检测选中文本的语言，并翻译为指定的目标语言。

#### 实现位置
- `QuestionAnswerViewWrapper` - `triggerTranslation`
- `QwenAPIService.swift` - `translate`

#### 工作流程

```
selectedText 变化
    │
    ▼
检测变化类型
    │
    ├─ OCR 更新 → handleOCRUpdate
    │   │
    │   ├─ 保存旧翻译状态 (hadTranslationBeforeOCR)
    │   │
    │   ├─ 设置 pendingOCRTranslation = true
    │   │
    │   └─ 等待 OCRCompleted 通知
    │       │
    │       └─ 触发静默翻译（不显示"翻译中"）
    │
    └─ 正常更新 → handleNormalUpdate
        │
        └─ 立即触发翻译（显示"翻译中"）
            │
            ▼
triggerTranslationWithDebounce
    │
    ├─ 取消之前的翻译任务
    │
    ├─ 检测源语言
    │   │
    │   └─ 简单检测：检查是否包含中文字符
    │
    ├─ 获取目标语言 (TranslationTargetLanguage.current)
    │   │
    │   └─ 根据源语言和目标语言设置确定实际目标语言
    │
    └─ 调用 QwenAPIService.translate
        │
        └─ 更新 translatedText
```

#### 翻译版本管理

系统使用 `translationVersion` 来区分原始文本翻译和 OCR 结果翻译：

```swift
@State private var translationVersion: String = "original" // "original" 或 "ocr"
```

#### 静默更新机制

当 OCR 结果返回时，如果之前已有翻译结果，系统会静默更新（不显示"翻译中"状态），避免闪烁：

```swift
if hadTranslation {
    // 有旧翻译结果，静默更新
    self.isTranslating = false
} else {
    // 没有旧翻译结果，显示"翻译中"
    self.isTranslating = true
}
```

#### 防抖机制

翻译请求使用防抖机制，避免频繁调用 API：

```swift
// 取消之前的任务
translationTask?.cancel()

// 创建新任务（延迟 0.5 秒）
translationTask = Task {
    try? await Task.sleep(nanoseconds: 500_000_000)
    // 执行翻译
}
```

---

### 4. AI 问答功能

#### 功能描述
用户可以对选中的文本内容提问，AI 基于上下文给出精准回答。

#### 实现位置
- `QuestionAnswerViewWrapper` - `submitQuestion`
- `QwenAPIService.swift` - `askQuestion`

#### 工作流程

```
用户输入问题
    │
    ▼
点击"提问"按钮
    │
    ▼
submitQuestion()
    │
    ├─ 验证问题非空
    │
    ├─ 设置加载状态 (isLoading = true)
    │
    └─ 调用 QwenAPIService.askQuestion
        │
        ├─ 构建消息列表
        │   │
        │   ├─ System Message: 定义 AI 角色
        │   │   "你是一个专业的学术论文阅读助手..."
        │   │
        │   └─ User Message: 包含上下文和问题
        │       "论文内容：{selectedText}"
        │       "用户问题：{question}"
        │
        ├─ 发送 HTTP 请求
        │
        ├─ 解析响应
        │
        └─ 更新 answer
            │
            └─ MarkdownLaTeXView 渲染回答
```

#### 系统提示词设计

```swift
"""
你是一个专业的学术论文阅读助手。用户选中了一段论文内容，并提出了问题。

请基于选中的论文内容回答问题。如果问题涉及的内容在选中文本中找不到，请明确说明。
回答要准确、简洁、专业。
"""
```

#### 上下文处理

- **有上下文**：将选中文本和问题一起发送给 AI
- **无上下文**：仅发送问题（允许通用问答）

---

### 5. Vision API 集成

#### 功能描述
使用 Qwen-VL-Max 模型处理图像内容，支持识别、翻译、问答。

#### 实现位置
- `QwenAPIService.swift` - `processImageWithVision`
- `PDFReaderView.swift` - `processSelectionWithVision`

#### Vision API 消息格式

```swift
struct VisionMessage: Codable {
    let role: String
    let content: [ContentItem]
    
    enum ContentItem: Codable {
        case text(String)
        case imageURL(ImageURL)
        
        struct ImageURL: Codable {
            let url: String // data:image/png;base64,...
        }
    }
}
```

#### 支持的 Vision API 功能

1. **图像识别** (`recognizeImage`)
   - 识别图像中的文本和公式
   - 公式转换为 LaTeX 格式

2. **图像翻译** (`translateImage`)
   - 识别并翻译图像内容
   - 保持格式和结构

3. **图像问答** (`askQuestionAboutImage`)
   - 基于图像内容回答问题
   - 支持公式解释

#### 降级策略

当 Vision API 失败时，系统自动降级到文本提取：

```swift
catch {
    // Vision API 失败，降级到文本提取
    if let text = PDFTextExtractor.extractText(...) {
        // 使用文本提取结果
    }
}
```

---

## 工作流程

### 完整用户交互流程

```
1. 用户打开 PDF 文档
   │
   ▼
2. 切换到 Agent 模式
   │
   ▼
3. 启用框选模式（点击工具栏按钮）
   │
   ▼
4. 在 PDF 上拖拽选择区域
   │
   ├─ 文本区域
   │   │
   │   ├─ 直接提取文本
   │   │
   │   └─ 显示在"选中的论文内容"区域
   │       │
   │       └─ 自动触发翻译（如果开启）
   │
   └─ 图像/公式区域
       │
       ├─ 检测公式处理模式
       │
       ├─ 提取图像
       │
       ├─ 触发 OCR（本地或 Vision API）
       │
       ├─ 显示 OCR 进度
       │
       ├─ 显示识别结果（含 LaTeX）
       │
       └─ 自动触发翻译（如果开启）
           │
           └─ 静默更新（如果之前有翻译）
   │
   ▼
5. 用户可以在"问答功能"区域提问
   │
   ├─ 输入问题
   │
   ├─ 点击"提问"按钮
   │
   ├─ AI 基于选中内容回答
   │
   └─ 显示回答（支持 Markdown 和 LaTeX）
```

---

## AI 服务集成

### Qwen API 服务

#### 配置

```swift
struct APIConfig {
    static let apiKey = "sk-..."
    static let baseURL = "https://api.probex.top/v1/chat/completions"
    
    static var model: String {
        get { UserDefaults.standard.string(forKey: "selectedModel") ?? "Qwen2.5-14B-Instruct" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedModel") }
    }
}
```

#### 支持的模型

1. **Qwen2.5-14B-Instruct**（默认）
   - 快速响应
   - 适合大多数场景

2. **Qwen2.5-32B-Instruct**
   - 平衡性能
   - 更高质量回答

3. **deepseek-chat**
   - 高质量回答
   - 适合复杂问题

4. **Qwen3-235B-A22B**
   - 最强能力
   - 处理复杂任务

5. **Qwen-VL-Max**
   - 视觉模型
   - 支持图像输入

#### API 请求格式

**标准 Chat Completion**：

```json
{
  "model": "Qwen2.5-14B-Instruct",
  "messages": [
    {
      "role": "system",
      "content": "你是一个专业的学术论文阅读助手..."
    },
    {
      "role": "user",
      "content": "论文内容：...\n\n用户问题：..."
    }
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

**Vision API**：

```json
{
  "model": "Qwen-VL-Max",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "请识别这张图片中的内容..."
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,..."
          }
        }
      ]
    }
  ]
}
```

#### 错误处理

系统实现了完善的错误处理机制：

```swift
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}
```

**网络错误友好提示**：
- `NSURLErrorNotConnectedToInternet` → "请检查网络连接"
- `NSURLErrorTimedOut` → "请求超时，请稍后重试"
- `NSURLErrorCannotFindHost` → "无法连接到服务器"

#### 重试机制

系统支持多个备用 URL：

```swift
let urlStrings = [
    baseURL,
    "https://api.probex.top/v1/chat/completions",
    "https://api.probex.top/v1",
]
```

---

## 配置说明

### API Key 配置方法

#### 开发环境配置

API Key 目前硬编码在 `APIConfig.swift` 文件中：

```swift
// HyperPaper/HyperPaper/Models/APIConfig.swift
struct APIConfig {
    static let apiKey = "sk-..."  // 在这里修改你的 API Key
    static let baseURL = "https://api.probex.top/v1/chat/completions"
}
```

**配置步骤**：

1. 打开 `HyperPaper/HyperPaper/Models/APIConfig.swift`
2. 将 `apiKey` 的值替换为你的 API Key
3. 重新编译运行

**⚠️ 安全提示**：
- 不要将包含真实 API Key 的代码提交到公共仓库
- 建议使用环境变量或配置文件（未来版本将支持）

#### 生产环境配置（计划中）

未来版本将支持通过以下方式配置：

1. **环境变量**：
   ```bash
   export HYPERPAPER_API_KEY="sk-..."
   ```

2. **配置文件**：
   ```json
   {
     "apiKey": "sk-...",
     "baseURL": "https://api.probex.top/v1/chat/completions"
   }
   ```

3. **偏好设置界面**：
   - 在偏好设置中添加 API Key 输入框
   - 使用 Keychain 安全存储

---

### 环境变量设置

#### Python 环境配置（OCR 功能）

Pix2Text OCR 功能需要 Python 3 环境。系统会自动查找 Python 路径，查找顺序：

1. **App Bundle 内的 Python**（如果打包时包含）
   ```
   {Bundle}/Resources/Python3/python3
   ```

2. **系统 Python**
   ```bash
   /usr/bin/python3
   /usr/local/bin/python3
   /opt/homebrew/bin/python3  # Apple Silicon Mac
   ```

3. **通过 `which` 命令查找**
   ```bash
   which python3
   ```

**验证 Python 环境**：

```bash
# 检查 Python 版本
python3 --version

# 检查是否安装了 Pix2Text
python3 -c "import pix2text; print('Pix2Text installed')"
```

**安装 Pix2Text**（如果未安装）：

```bash
pip3 install pix2text
```

#### OCR 脚本路径

系统会按以下顺序查找 OCR 脚本：

1. **App Bundle 内的脚本**
   ```
   {Bundle}/Resources/Scripts/pix2text_ocr.py
   ```

2. **项目目录中的脚本**（开发时）
   ```
   {ProjectRoot}/Scripts/pix2text_ocr.py
   ```

3. **硬编码路径**（开发时）
   ```
   ~/Projects/HyperPaper/Scripts/pix2text_ocr.py
   /Volumes/T7Shield/Projects/HyperPaper/Scripts/pix2text_ocr.py
   ```

---

### 偏好设置说明

#### 打开偏好设置

1. **菜单栏方式**：
   - 点击菜单栏 `HyperPaper > 偏好设置...`
   - 或使用快捷键 `Cmd + ,`

2. **工具栏方式**：
   - 点击悬浮工具栏中的设置按钮

#### 偏好设置选项

偏好设置界面包含三个主要部分：

##### 1. 模型设置

**功能**：选择用于问答和翻译的 AI 模型

**可用模型**：

| 模型名称 | 描述 | 价格 | 适用场景 |
|---------|------|------|---------|
| Qwen2.5-14B-Instruct | 快速响应（推荐） | 输入 $0.30/M, 输出 $0.45/M | 日常使用，快速问答 |
| Qwen2.5-32B-Instruct | 平衡性能 | 输入 $0.50/M, 输出 $0.75/M | 需要更高质量回答 |
| DeepSeek Chat | 高质量回答 | 输入 $1.00/M, 输出 $1.50/M | 复杂问题处理 |
| Qwen3-235B-A22B | 最强能力（较慢） | 价格较高 | 最复杂任务 |
| Qwen-VL-Max | 视觉模型（公式识别） | 支持图像输入 | 公式和图表识别 |

**配置方法**：
- 在偏好设置界面点击选择模型
- 设置会自动保存到 `UserDefaults`，键名：`selectedModel`

**代码访问**：
```swift
// 读取当前模型
let currentModel = APIConfig.model

// 设置模型
APIConfig.model = "Qwen2.5-32B-Instruct"
```

##### 2. 公式处理模式

**功能**：选择如何处理包含公式的区域

**可用模式**：

| 模式 | 描述 | 适用场景 |
|------|------|---------|
| 不处理公式 | 直接提取文本，不进行公式识别 | 纯文本区域 |
| 基于本地OCR处理公式 | 使用本地 Pix2Text 进行 OCR 识别，支持公式转 LaTeX | 需要离线处理，保护隐私 |
| 基于VLM API处理公式 | 使用 Vision API（Qwen-VL-Max）进行识别 | 需要更高识别准确度 |

**配置方法**：
- 在偏好设置界面选择处理模式
- 设置自动保存到 `UserDefaults`，键名：`formulaProcessingMode`

**代码访问**：
```swift
// 读取当前模式
let currentMode = FormulaProcessingMode.current

// 设置模式
FormulaProcessingMode.current = .localOCR
```

**模式选择建议**：
- **不处理公式**：如果文档主要是纯文本，选择此模式可提高速度
- **本地OCR**：适合需要保护隐私的场景，但需要安装 Python 和 Pix2Text
- **VLM API**：适合需要高准确度的场景，但需要网络连接和 API 配额

##### 3. 翻译目标语言

**功能**：设置翻译的目标语言

**可用语言**：

| 语言 | 代码 | 说明 |
|------|------|------|
| 自动检测 | auto | 根据源语言自动选择目标语言（中文↔英文） |
| 中文 | chinese | 简体中文 |
| English | english | 英语 |
| 日本語 | japanese | 日语 |
| 한국어 | korean | 韩语 |
| Français | french | 法语 |
| Deutsch | german | 德语 |
| Español | spanish | 西班牙语 |

**自动检测逻辑**：
- 如果源语言是中文，目标语言是英文
- 如果源语言是英文，目标语言是中文

**配置方法**：
- 在偏好设置界面选择目标语言
- 设置自动保存到 `UserDefaults`，键名：`translationTargetLanguage`

**代码访问**：
```swift
// 读取当前目标语言
let currentLanguage = TranslationTargetLanguage.current

// 设置目标语言
TranslationTargetLanguage.current = .english

// 根据源语言获取实际目标语言
let targetLanguage = TranslationTargetLanguage.current.getTargetLanguage(sourceLanguage: "中文")
// 返回: "English"
```

#### 偏好设置存储位置

所有偏好设置都存储在 macOS 的 `UserDefaults` 中：

**存储位置**：
```
~/Library/Preferences/com.yourcompany.HyperPaper.plist
```

**存储的键值对**：

| 键名 | 类型 | 说明 |
|------|------|------|
| `selectedModel` | String | 选中的 AI 模型 |
| `formulaProcessingMode` | String | 公式处理模式 |
| `translationTargetLanguage` | String | 翻译目标语言 |

**手动修改（不推荐）**：

如果需要手动修改，可以使用 `defaults` 命令：

```bash
# 查看所有设置
defaults read com.yourcompany.HyperPaper

# 设置模型
defaults write com.yourcompany.HyperPaper selectedModel "Qwen2.5-32B-Instruct"

# 设置公式处理模式
defaults write com.yourcompany.HyperPaper formulaProcessingMode "基于本地OCR处理公式"

# 设置翻译目标语言
defaults write com.yourcompany.HyperPaper translationTargetLanguage "English"
```

**⚠️ 注意**：手动修改后需要重启应用才能生效。

#### 偏好设置同步

偏好设置的保存和读取都是同步的：

```swift
// 保存设置
UserDefaults.standard.set(value, forKey: key)
UserDefaults.standard.synchronize()  // 立即同步到磁盘

// 读取设置
let value = UserDefaults.standard.string(forKey: key)
```

#### 重置偏好设置

如果需要重置所有偏好设置：

1. **通过代码**：
   ```swift
   // 删除所有 HyperPaper 相关的 UserDefaults
   UserDefaults.standard.removePersistentDomain(forName: "com.yourcompany.HyperPaper")
   ```

2. **通过命令行**：
   ```bash
   defaults delete com.yourcompany.HyperPaper
   ```

3. **手动删除**：
   - 删除 `~/Library/Preferences/com.yourcompany.HyperPaper.plist`
   - 重启应用

---

## 技术实现细节

### 1. 坐标系统转换

PDF 使用左下角为原点的坐标系，而图像和视图使用左上角为原点。系统需要处理坐标转换：

```swift
// PDF 坐标系 → 图像坐标系
let imageY = pageHeight - pdfY - height

// 图像提取时的坐标转换
let cropRect = CGRect(
    x: region.rect.origin.x * scale,
    y: (pageHeight - region.rect.origin.y - region.rect.height) * scale,
    width: region.rect.width * scale,
    height: region.rect.height * scale
)
```

### 2. 图像提取与处理

#### 提取流程

1. **创建临时图像**（整个页面大小）
2. **绘制整个 PDF 页面**到临时图像
3. **裁剪目标区域**
4. **翻转图像**（PDF 坐标系 → 图像坐标系）
5. **添加白色背景**

#### 缩放处理

系统使用 2.0 倍缩放提高识别质量，同时限制最大尺寸避免内存问题：

```swift
let maxSize: CGFloat = 4096
let adjustedScale = min(scale, maxSize / max(region.rect.width, region.rect.height))
```

### 3. 状态管理

#### 关键状态变量

```swift
// OCR 相关
@State private var ocrProgress: Double = 0.0
@State private var isProcessingOCR: Bool = false
@State private var isOCRPending: Bool = false
@State private var lastOCRCompletionTime: Date?

// 翻译相关
@State private var isTranslating: Bool = false
@State private var translatedText: String = ""
@State private var translationVersion: String = "original"
@State private var hadTranslationBeforeOCR: Bool = false
@State private var pendingOCRTranslation: Bool = false

// 问答相关
@State private var question: String = ""
@State private var answer: String = ""
@State private var isLoading: Bool = false
```

#### 状态同步

系统使用 `NotificationCenter` 实现跨组件的状态同步：

- `OCRProgressUpdate`: OCR 进度更新
- `OCRCompleted`: OCR 完成通知

### 4. 异步处理

所有 AI 服务调用都使用 Swift 的 `async/await` 模式：

```swift
Task {
    do {
        let response = try await apiService.askQuestion(
            question: question,
            context: selectedText.isEmpty ? nil : selectedText
        )
        
        await MainActor.run {
            answer = response
            isLoading = false
        }
    } catch {
        await MainActor.run {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
```

---

## 数据流

### 文本提取数据流

```
PDFDocument
    │
    ▼
PDFPage.selection(for: rect)
    │
    ▼
PDFSelection.string
    │
    ▼
selectedText (@Binding)
    │
    ▼
QuestionAnswerViewWrapper
    │
    └─ MarkdownLaTeXView 渲染
```

### OCR 数据流

```
SelectionRegion
    │
    ▼
PDFImageExtractor.extractImage
    │
    ├─ 提取图像 (NSImage)
    │
    ├─ 保存临时文件
    │
    └─ Pix2TextService.recognizeImage
        │
        ├─ 调用 Python 脚本
        │
        ├─ 解析进度 (stderr)
        │
        └─ 返回 Markdown 结果
            │
            ▼
        selectedText 更新
            │
            └─ 触发翻译
```

### 翻译数据流

```
selectedText 变化
    │
    ▼
检测变化类型
    │
    ├─ OCR 更新 → 等待 OCRCompleted
    │
    └─ 正常更新 → 立即翻译
        │
        ▼
QwenAPIService.translate
    │
    ├─ 检测源语言
    │
    ├─ 获取目标语言
    │
    └─ 发送 API 请求
        │
        ▼
translatedText 更新
    │
    └─ MarkdownLaTeXView 渲染
```

### 问答数据流

```
用户输入问题
    │
    ▼
submitQuestion()
    │
    ▼
QwenAPIService.askQuestion
    │
    ├─ 构建消息列表
    │   ├─ System Message
    │   └─ User Message (含上下文)
    │
    └─ 发送 API 请求
        │
        ▼
answer 更新
    │
    └─ MarkdownLaTeXView 渲染
```

---

## 错误处理

### OCR 错误处理

```swift
enum Pix2TextError: Error {
    case pythonNotFound
    case scriptNotFound
    case processFailed(String)
    case invalidOutput
    case timeout
}
```

**处理策略**：
1. 检查 Python 环境
2. 检查脚本路径
3. 解析进程输出中的错误信息
4. 超时保护（60 秒）

### API 错误处理

```swift
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}
```

**处理策略**：
1. 尝试多个备用 URL
2. 解析 HTTP 状态码
3. 提取 API 返回的错误信息
4. 提供友好的错误提示

### 降级策略

当高级功能失败时，系统自动降级：

1. **Vision API 失败** → 降级到文本提取
2. **OCR 失败** → 显示错误，保留原始选择
3. **翻译失败** → 显示错误信息，保留原文

---

## 性能优化

### 1. 防抖机制

翻译请求使用防抖，避免频繁调用：

```swift
translationTask?.cancel()
translationTask = Task {
    try? await Task.sleep(nanoseconds: 500_000_000)
    // 执行翻译
}
```

### 2. 任务取消

支持取消正在进行的任务：

```swift
currentTranslationTask?.cancel()
```

### 3. 图像尺寸限制

限制最大图像尺寸，避免内存问题：

```swift
let maxSize: CGFloat = 4096
let adjustedScale = min(scale, maxSize / max(width, height))
```

### 4. 进度模拟

当无法解析真实进度时，使用模拟进度避免 UI 卡顿：

```swift
let simulatedProgressTimer = Timer.scheduledTimer(...) {
    let newProgress = min(currentProgress + 0.02, 1.0)
    progressCallback(newProgress)
}
```

### 5. 异步处理

所有耗时操作都在后台线程执行，UI 更新在主线程：

```swift
Task {
    // 后台处理
    let result = try await processData()
    
    await MainActor.run {
        // UI 更新
        self.result = result
    }
}
```

---

## 未来规划

### 短期优化

1. **缓存机制**
   - 缓存 OCR 结果，避免重复识别
   - 缓存翻译结果，提高响应速度

2. **批量处理**
   - 支持批量 OCR 识别
   - 批量翻译多个区域

3. **离线支持**
   - 本地模型支持（部分功能）
   - 离线 OCR 缓存

### 长期规划

1. **知识库集成**
   - 构建论文知识库
   - 支持跨文档问答

2. **多模态增强**
   - 支持视频内容识别
   - 支持音频转录

3. **协作功能**
   - 共享问答结果
   - 协作标注

---

## 附录

### 关键文件清单

- `HyperPaper/HyperPaper/Views/MainView.swift` - 主视图，模式切换
- `HyperPaper/HyperPaper/Views/QuestionAnswerView.swift` - 问答视图（旧版）
- `HyperPaper/HyperPaper/Views/MainView.swift` (QuestionAnswerViewWrapper) - 问答视图包装器
- `HyperPaper/HyperPaper/Services/QwenAPIService.swift` - AI 服务封装
- `HyperPaper/HyperPaper/Services/Pix2TextService.swift` - OCR 服务
- `HyperPaper/HyperPaper/Services/PDFTextExtractor.swift` - 文本提取
- `HyperPaper/HyperPaper/Services/PDFImageExtractor.swift` - 图像提取