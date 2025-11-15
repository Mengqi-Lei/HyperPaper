# 🚀 快速开始指南

**Language / 语言**: [🇨🇳 中文](QUICK_START.md) | [🇬🇧 English](QUICK_START_EN.md)

欢迎使用 HyperPaper！本指南将帮助你在 5 分钟内完成配置并开始使用。

## 📋 前置要求

- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本（用于编译）
- Python 3（用于 OCR 功能，可选）

## ⚡ 快速配置（3 步）

### 步骤 1: 克隆或下载项目

```bash
git clone https://github.com/Mengqi-Lei/HyperPaper.git
cd HyperPaper
```

或者直接下载 ZIP 文件并解压。

### 步骤 2: 配置 API Key ⚠️ **必需**

1. 获取 API Key：
   - 访问 https://api.probex.top
   - 注册账号并创建 API Key

2. 配置 API Key：
   - 打开 `HyperPaper/HyperPaper/Models/APIConfig.swift`
   - 找到这一行：
     ```swift
     static let apiKey = "YOUR_API_KEY_HERE"
     ```
   - 替换为你的实际 API Key：
     ```swift
     static let apiKey = "sk-你的实际API密钥"
     ```

3. 保存文件

> 📖 详细配置说明请查看 [API_CONFIGURATION.md](API_CONFIGURATION.md)

### 步骤 3: 编译运行

1. 打开项目：
   ```bash
   open HyperPaper/HyperPaper.xcodeproj
   ```

2. 在 Xcode 中：
   - 选择目标设备（你的 Mac）
   - 按 `Cmd + R` 运行
   - 等待编译完成

## 🎯 首次使用

### 1. 打开 PDF

- 点击"选择PDF文件"按钮
- 或使用菜单栏 `文件 > 打开`
- 选择任意 PDF 文件

### 2. 开始使用

#### AI 问答功能
1. 在 PDF 上框选任意区域
2. 在右侧问答面板输入问题
3. AI 会基于选中内容回答

#### OCR 识别功能
1. 框选包含公式或图表的区域
2. 系统自动触发 OCR 识别
3. 识别结果自动显示，支持翻译

#### 注释功能
1. 使用工具栏选择注释工具（高亮/下划线/删除线/画线/笔记/文字）
2. 在 PDF 上进行标注
3. 所有注释自动保存

### 3. 配置偏好设置

打开偏好设置（`Cmd + ,` 或菜单栏 `HyperPaper > 偏好设置...`）：

- **AI 模型**：选择适合的模型（推荐 Qwen2.5-14B-Instruct）
- **公式处理模式**：选择如何处理公式
- **翻译目标语言**：设置翻译目标语言

## 🔧 可选配置

### Python 环境（OCR 功能）

如果你需要使用本地 OCR 功能：

1. 检查 Python 3：
   ```bash
   python3 --version
   ```

2. 安装 Pix2Text：
   ```bash
   pip3 install pix2text
   ```

3. 在偏好设置中选择"基于本地OCR处理公式"模式

> 如果不配置 Python，仍可使用 VLM API 模式进行 OCR（需要网络连接）

## ❓ 常见问题

### Q: 编译错误怎么办？

A: 
- 确保 Xcode 版本 >= 14.0
- 确保 macOS 版本 >= 12.0
- 尝试清理构建：`Product > Clean Build Folder` (Shift + Cmd + K)

### Q: API Key 配置后仍然报错？

A: 
- 检查 API Key 是否正确（没有多余空格）
- 检查网络连接
- 查看 Xcode 控制台的错误信息

### Q: OCR 功能不工作？

A: 
- 如果使用本地 OCR，确保已安装 Python 和 Pix2Text
- 如果使用 VLM API，确保网络连接正常且 API Key 有效
- 检查偏好设置中的公式处理模式

### Q: 如何更新项目？

A: 
```bash
git pull origin main
```

## 📚 更多资源

- [完整 README](README.md) - 项目详细介绍
- [API 配置指南](API_CONFIGURATION.md) - 详细的 API 配置说明
- [Agent 功能说明](Agent功能详细说明文档.md) - Agent 功能的完整文档
- [贡献指南](CONTRIBUTING.md) - 如何参与项目贡献

## 🎉 开始使用

现在你已经完成了配置，可以开始使用 HyperPaper 了！

如果遇到任何问题，请在 [GitHub Issues](https://github.com/Mengqi-Lei/HyperPaper/issues) 中提问。

---

**祝你使用愉快！** 🚀

