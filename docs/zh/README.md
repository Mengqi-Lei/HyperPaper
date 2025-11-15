<div align="center">

# 🪄 HyperPaper

</div>

<div align="center">

**下一代智能 PDF 阅读与注释工具**

*让阅读论文变得简单、高效、智能*

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org) [![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://www.apple.com/macos) [![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[特性](#-核心特性) • [快速开始](#-快速开始) • [功能演示](#-功能演示) • [技术栈](#-技术栈) • [配置](#-配置) • [贡献](#-贡献)

**Language / 语言**: [🇬🇧 English](../README.md) | [🇨🇳 中文](README.md)

</div>

---

## ✨ 为什么选择 HyperPaper？

阅读学术论文时，你是否遇到过这些困扰？

- 📚 **公式难以理解** - 复杂的数学公式需要反复查阅资料
- 🌐 **语言障碍** - 外文论文理解困难，需要频繁切换翻译工具
- 📝 **注释混乱** - 多个工具间切换，注释难以统一管理
- 🔍 **理解困难** - 图表、表格的含义需要额外查询

**HyperPaper 为你解决所有这些问题！**

HyperPaper 是一个专为学术研究设计的智能 PDF 阅读器，集成了 AI 问答、OCR 识别、公式解析、智能翻译和强大的注释系统，让论文阅读变得前所未有的高效。

---

## 🚀 核心特性

### ✨ AI 驱动的智能问答
- **区域问答**：选中任意区域，直接翻译或提问，AI 为你解答
- **多模型支持**：支持 Qwen 系列等多种 AI 模型
- **上下文理解**：基于选中内容提供精准回答
- **Markdown 渲染**：支持 LaTeX 公式、代码块等丰富格式

### 📸 强大的 OCR 能力
- **本地 OCR**：基于 Pix2Text 的本地识别引擎，保护隐私
- **公式识别**：自动识别数学公式并转换为 LaTeX
- **图表提取**：智能提取图表中的文字和结构
- **实时进度**：OCR 处理过程可视化

### 🌍 智能翻译
- **多语言支持**：中文、英文、日文、韩文、法文、德文、西班牙文
- **自动检测**：智能识别源语言
- **目标语言选择**：在偏好设置中自定义翻译目标语言
- **静默更新**：翻译结果自动更新，无需手动刷新

### ✏️ 丰富的注释系统
- **文本标注**：高亮、下划线、删除线
- **自由画线**：手绘标注，随心所欲
- **笔记功能**：点击添加笔记，支持多行编辑
- **文字注释**：在 PDF 上直接添加文字说明
- **颜色自定义**：丰富的颜色选择，个性化标注
- **二次编辑**：所有注释支持编辑和删除

### 🎨 现代化 UI 设计
- **Liquid Glass 风格**：半透明液态玻璃效果，视觉优雅
- **悬浮工具栏**：不遮挡内容，操作便捷
- **流畅动画**：丝滑的交互体验
- **响应式布局**：适配不同屏幕尺寸

### 📊 公式与图表处理
- **公式识别**：三种处理模式（不处理公式、基于本地OCR+LLM API翻译、基于VLM API翻译）
- **LaTeX 渲染**：完美支持数学公式显示
- **图表理解**：AI 分析图表内容，提供解释

---

## 🎬 功能演示

### 🤖 AI 功能演示

观看 HyperPaper 的 AI 功能演示：

https://github.com/Mengqi-Lei/HyperPaper/releases/download/Demo-video-1080p/hyperpaper-AI.mp4

*演示内容：区域问答、OCR 识别、智能翻译、公式处理*

### ✏️ 批注功能演示

观看 HyperPaper 强大的批注系统：

https://github.com/Mengqi-Lei/HyperPaper/releases/download/Demo-video-1080p/hyperpaper-notes.mp4

*演示内容：文本批注、高亮、笔记、批注管理*

---

### 快速功能概览

#### 区域问答
```
1. 框选论文中的任意区域
2. 在右侧问答面板输入问题
3. AI 基于选中内容给出精准回答
```

#### OCR 识别
```
1. 框选包含公式或图表的区域
2. 自动触发 OCR 识别
3. 识别结果自动显示，支持翻译和解释
```

#### 智能注释
```
1. 选择注释工具（高亮/下划线/删除线/画线/笔记/文字）
2. 在 PDF 上进行标注
3. 所有注释自动保存，支持二次编辑
```

---

## 🛠️ 技术栈

### 前端
- **SwiftUI** - 现代化的 UI 框架
- **PDFKit** - PDF 渲染和交互
- **AppKit** - macOS 原生组件

### AI 服务
- **Qwen API** - 大语言模型服务
- **Pix2Text** - 本地 OCR 引擎
- **Vision API** - 公式和图表识别

### 核心功能
- **PDF 注释系统** - 完整的 PDF 注释支持
- **Markdown 渲染** - 支持 LaTeX 公式
- **多语言翻译** - 智能翻译引擎

---

## 📦 快速开始

### 系统要求
- macOS 26 或更高版本
- Xcode 14.0 或更高版本（开发环境）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/Mengqi-Lei/HyperPaper.git
   cd HyperPaper
   ```

2. **打开项目**
   ```bash
   open HyperPaper/HyperPaper.xcodeproj
   ```

3. **配置 API Key** ⚠️ **必需步骤**
   - 打开 `HyperPaper/HyperPaper/Models/APIConfig.swift`
   - 将 `YOUR_API_KEY_HERE` 替换为你的实际 API Key
   - 详细配置说明请查看 [API 配置指南](API_CONFIGURATION.md)
   - 获取 API Key: https://api.probex.top

4. **编译运行**
   - 在 Xcode 中选择目标设备
   - 按 `Cmd + R` 运行项目

### 首次使用

1. **打开 PDF**
   - 点击"选择PDF文件"按钮
   - 或使用菜单栏 `文件 > 打开`

2. **开始阅读**
   - 使用工具栏切换不同模式（阅读/批注）
   - 框选区域进行问答或 OCR
   - 使用注释工具进行标注

3. **配置偏好**
   - 打开偏好设置（`Cmd + ,`）
   - 选择 AI 模型
   - 设置公式处理模式
   - 选择翻译目标语言

---

## 🎯 使用场景

### 📖 学术论文阅读
- 快速理解复杂公式
- 翻译外文论文
- 记录阅读笔记
- 整理关键信息

### 📚 文献综述
- 批量处理多篇论文
- 统一管理注释
- 提取关键内容
- 生成阅读摘要

### 🔬 研究学习
- 深入理解图表含义
- 分析实验数据
- 对比不同观点
- 构建知识体系

---

## ⚙️ 配置

### API Key 配置（必需）

在使用 AI 功能前，需要配置 API Key：

1. 打开 `HyperPaper/HyperPaper/Models/APIConfig.swift`
2. 将 `YOUR_API_KEY_HERE` 替换为你的实际 API Key
3. 获取 API Key: https://api.probex.top

📖 **详细配置说明**：请查看 [API 配置指南](API_CONFIGURATION.md)

🚀 **快速开始**：请查看 [快速开始指南](QUICK_START.md)

### 偏好设置

HyperPaper 提供了丰富的自定义选项：

- **AI 模型选择**：根据需求选择不同的 AI 模型
- **公式处理模式**：
  - 不处理公式：直接提取文本，不进行公式识别
  - 基于本地OCR处理公式：使用本地 Pix2Text 进行 OCR 识别，支持公式转 LaTeX
  - 基于VLM API处理公式：使用 Vision API（如 Qwen-VL-Max）进行识别
- **翻译目标语言**：自定义翻译目标语言
- **注释颜色**：个性化标注颜色

---

## 🗺️ 路线图

### 已完成 ✅
- [x] PDF 阅读和区域选择
- [x] AI 问答功能
- [x] OCR 识别（本地 Pix2Text）
- [x] 智能翻译
- [x] 公式识别和渲染
- [x] 完整注释系统
- [x] Markdown-LaTeX 渲染
- [x] Liquid Glass UI 设计

### 计划中 🚧
- [ ] 注释导出功能
- [ ] 多文档管理
- [ ] 云端同步
- [ ] 插件系统
- [ ] 移动端支持
🔈 欢迎提交PR，一起完善HyperPaper！

---

## 🤝 贡献

我们欢迎所有形式的贡献！

### 如何贡献
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 贡献指南
请查看 [贡献指南](CONTRIBUTING.md) 了解详细的贡献指南。

---

## 📄 许可证

本项目采用 MIT 许可证。详情请查看 [LICENSE](LICENSE) 文件。

---

## 🙏 致谢

- [Qwen](https://github.com/QwenLM/Qwen) - 强大的大语言模型
- [Pix2Text](https://github.com/breezedeus/Pix2Text) - 优秀的 OCR 工具
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - 现代化的 UI 框架

---

## 📮 联系我们

- **GitHub Issues**: [提交问题或建议](https://github.com/Mengqi-Lei/HyperPaper/issues)
- **Pull Requests**: [贡献代码](https://github.com/Mengqi-Lei/HyperPaper/pulls)

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给我们一个 Star！⭐**

Made with ❤️ by the HyperPaper Team

</div>
