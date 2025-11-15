<div align="center">

# 🪄 HyperPaper

</div>

<div align="center">

**Next-Generation Intelligent PDF Reader and Annotation Tool**

*Making paper reading simple, efficient, and intelligent*

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org) [![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://www.apple.com/macos) [![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Features](#-core-features) • [Quick Start](#-quick-start) • [Demo](#-demo) • [Tech Stack](#-tech-stack) • [Configuration](#-configuration) • [Contributing](#-contributing)

**Language / 语言**: [🇬🇧 English](../README.md) | [🇨🇳 中文](zh/README.md)

</div>

---

## ✨ Why Choose HyperPaper?

When reading academic papers, have you ever encountered these problems?

- 📚 **Complex Formulas** - Complex mathematical formulas require constant reference to materials
- 🌐 **Language Barriers** - Foreign papers are difficult to understand, requiring frequent switching of translation tools
- 📝 **Chaotic Annotations** - Switching between multiple tools makes annotations difficult to manage uniformly
- 🔍 **Understanding Difficulties** - The meaning of charts and tables requires additional queries

**HyperPaper solves all these problems for you!**

HyperPaper is an intelligent PDF reader designed specifically for academic research, integrating AI Q&A, OCR recognition, formula parsing, intelligent translation, and a powerful annotation system, making paper reading unprecedentedly efficient.

---

## 🚀 Core Features

### ✨ AI-Powered Intelligent Q&A
- **Regional Q&A**: Select any area, directly translate or ask questions, AI answers for you
- **Multi-Model Support**: Supports Qwen series and other AI models
- **Context Understanding**: Provides accurate answers based on selected content
- **Markdown Rendering**: Supports LaTeX formulas, code blocks, and rich formats

### 📸 Powerful OCR Capabilities
- **Local OCR**: Local recognition engine based on Pix2Text, protecting privacy
- **Formula Recognition**: Automatically recognizes mathematical formulas and converts them to LaTeX
- **Chart Extraction**: Intelligently extracts text and structure from charts
- **Real-time Progress**: OCR processing progress is visualized

### 🌍 Intelligent Translation
- **Multi-language Support**: Chinese, English, Japanese, Korean, French, German, Spanish
- **Auto Detection**: Intelligently recognizes source language
- **Target Language Selection**: Customize translation target language in preferences
- **Silent Updates**: Translation results are automatically updated without manual refresh

### ✏️ Rich Annotation System
- **Text Annotation**: Highlight, underline, strikethrough
- **Free Drawing**: Hand-drawn annotations, as you wish
- **Note Function**: Click to add notes, supports multi-line editing
- **Text Comments**: Add text descriptions directly on PDF
- **Color Customization**: Rich color selection, personalized annotations
- **Secondary Editing**: All annotations support editing and deletion

### 🎨 Modern UI Design
- **Liquid Glass Style**: Semi-transparent liquid glass effect, visually elegant
- **Floating Toolbar**: Doesn't block content, convenient operation
- **Smooth Animation**: Silky smooth interaction experience
- **Responsive Layout**: Adapts to different screen sizes

### 📊 Formula and Chart Processing
- **Formula Recognition**: Three processing modes (no formula processing, local OCR + LLM API translation, VLM API translation)
- **LaTeX Rendering**: Perfect support for mathematical formula display
- **Chart Understanding**: AI analyzes chart content and provides explanations

---

## 🎬 Demo

### Regional Q&A
```
1. Select any area in the paper
2. Enter questions in the right-side Q&A panel
3. AI provides accurate answers based on selected content
```

### OCR Recognition
```
1. Select areas containing formulas or charts
2. Automatically triggers OCR recognition
3. Recognition results are automatically displayed, supporting translation and explanation
```

### Intelligent Annotation
```
1. Select annotation tools (highlight/underline/strikethrough/draw/note/text)
2. Annotate on PDF
3. All annotations are automatically saved, supporting secondary editing
```

---

## 🛠️ Tech Stack

### Frontend
- **SwiftUI** - Modern UI framework
- **PDFKit** - PDF rendering and interaction
- **AppKit** - macOS native components

### AI Services
- **Qwen API** - Large language model service
- **Pix2Text** - Local OCR engine
- **Vision API** - Formula and chart recognition

### Core Features
- **PDF Annotation System** - Complete PDF annotation support
- **Markdown Rendering** - Supports LaTeX formulas
- **Multi-language Translation** - Intelligent translation engine

---

## 📦 Quick Start

### System Requirements
- macOS 12.0 or higher
- Xcode 14.0 or higher (development environment)

### Installation Steps

1. **Clone Repository**
   ```bash
   git clone https://github.com/Mengqi-Lei/HyperPaper.git
   cd HyperPaper
   ```

2. **Open Project**
   ```bash
   open HyperPaper/HyperPaper.xcodeproj
   ```

3. **Configure API Key** ⚠️ **Required Step**
   - Open `HyperPaper/HyperPaper/Models/APIConfig.swift`
   - Replace `YOUR_API_KEY_HERE` with your actual API Key
   - For detailed configuration instructions, see [API Configuration Guide](API_CONFIGURATION.md)
   - Get API Key: https://api.probex.top

4. **Build and Run**
   - Select target device in Xcode
   - Press `Cmd + R` to run the project

### First Use

1. **Open PDF**
   - Click "Select PDF File" button
   - Or use menu bar `File > Open`

2. **Start Reading**
   - Use toolbar to switch between different modes (reading/annotation)
   - Select areas for Q&A or OCR
   - Use annotation tools for marking

3. **Configure Preferences**
   - Open preferences (`Cmd + ,`)
   - Select AI model
   - Set formula processing mode
   - Choose translation target language

---

## 🎯 Use Cases

### 📖 Academic Paper Reading
- Quickly understand complex formulas
- Translate foreign papers
- Record reading notes
- Organize key information

### 📚 Literature Review
- Batch process multiple papers
- Unified annotation management
- Extract key content
- Generate reading summaries

### 🔬 Research and Learning
- Deeply understand chart meanings
- Analyze experimental data
- Compare different viewpoints
- Build knowledge systems

---

## ⚙️ Configuration

### API Key Configuration (Required)

Before using AI features, you need to configure API Key:

1. Open `HyperPaper/HyperPaper/Models/APIConfig.swift`
2. Replace `YOUR_API_KEY_HERE` with your actual API Key
3. Get API Key: https://api.probex.top

📖 **Detailed Configuration Guide**: See [API Configuration Guide](API_CONFIGURATION.md)

🚀 **Quick Start**: See [Quick Start Guide](QUICK_START.md)

### Preferences

HyperPaper provides rich customization options:

- **AI Model Selection**: Choose different AI models according to needs
- **Formula Processing Mode**:
  - No formula processing: Directly extract text without formula recognition
  - Local OCR-based formula processing: Use local Pix2Text for OCR recognition, supports formula to LaTeX conversion
  - VLM API-based formula processing: Use Vision API (such as Qwen-VL-Max) for recognition
- **Translation Target Language**: Customize translation target language
- **Annotation Colors**: Personalized annotation colors

---

## 🗺️ Roadmap

### Completed ✅
- [x] PDF reading and region selection
- [x] AI Q&A functionality
- [x] OCR recognition (local Pix2Text)
- [x] Intelligent translation
- [x] Formula recognition and rendering
- [x] Complete annotation system
- [x] Markdown-LaTeX rendering
- [x] Liquid Glass UI design

### Planned 🚧
- [ ] Annotation export functionality
- [ ] Multi-document management
- [ ] Cloud synchronization
- [ ] Plugin system
- [ ] Mobile support

🔈 Welcome to submit PRs and improve HyperPaper together!

---

## 🤝 Contributing

We welcome all forms of contributions!

### How to Contribute
1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Contributing Guidelines
Please see [Contributing Guide](CONTRIBUTING.md) for detailed contributing guidelines.

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Qwen](https://github.com/QwenLM/Qwen) - Powerful large language model
- [Pix2Text](https://github.com/breezedeus/Pix2Text) - Excellent OCR tool
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Modern UI framework

---

## 📮 Contact Us

- **GitHub Issues**: [Submit issues or suggestions](https://github.com/Mengqi-Lei/HyperPaper/issues)
- **Pull Requests**: [Contribute code](https://github.com/Mengqi-Lei/HyperPaper/pulls)

---

<div align="center">

**⭐ If this project helps you, please give us a Star! ⭐**

Made with ❤️ by the HyperPaper Team

</div>

