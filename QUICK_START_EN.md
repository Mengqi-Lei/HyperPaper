# 🚀 Quick Start Guide

**Language / 语言**: [🇨🇳 中文](QUICK_START.md) | [🇬🇧 English](QUICK_START_EN.md)

Welcome to HyperPaper! This guide will help you complete configuration and start using it in 5 minutes.

## 📋 Prerequisites

- macOS 12.0 or higher
- Xcode 14.0 or higher (for compilation)
- Python 3 (for OCR features, optional)

## ⚡ Quick Configuration (3 Steps)

### Step 1: Clone or Download Project

```bash
git clone https://github.com/Mengqi-Lei/HyperPaper.git
cd HyperPaper
```

Or directly download the ZIP file and extract it.

### Step 2: Configure API Key ⚠️ **Required**

1. Get API Key:
   - Visit https://api.probex.top
   - Register an account and create an API Key

2. Configure API Key:
   - Open `HyperPaper/HyperPaper/Models/APIConfig.swift`
   - Find this line:
     ```swift
     static let apiKey = "YOUR_API_KEY_HERE"
     ```
   - Replace with your actual API Key:
     ```swift
     static let apiKey = "sk-your-actual-api-key"
     ```

3. Save the file

> 📖 For detailed configuration instructions, see [API_CONFIGURATION_EN.md](API_CONFIGURATION_EN.md)

### Step 3: Build and Run

1. Open the project:
   ```bash
   open HyperPaper/HyperPaper.xcodeproj
   ```

2. In Xcode:
   - Select target device (your Mac)
   - Press `Cmd + R` to run
   - Wait for compilation to complete

## 🎯 First Use

### 1. Open PDF

- Click "Select PDF File" button
- Or use menu bar `File > Open`
- Select any PDF file

### 2. Start Using

#### AI Q&A Feature
1. Select any area on the PDF
2. Enter questions in the right-side Q&A panel
3. AI will answer based on selected content

#### OCR Recognition Feature
1. Select areas containing formulas or charts
2. System automatically triggers OCR recognition
3. Recognition results are automatically displayed, supporting translation

#### Annotation Feature
1. Use toolbar to select annotation tools (highlight/underline/strikethrough/draw/note/text)
2. Annotate on PDF
3. All annotations are automatically saved

### 3. Configure Preferences

Open preferences (`Cmd + ,` or menu bar `HyperPaper > Preferences...`):

- **AI Model**: Choose appropriate model (recommended: Qwen2.5-14B-Instruct)
- **Formula Processing Mode**: Choose how to process formulas
- **Translation Target Language**: Set translation target language

## 🔧 Optional Configuration

### Python Environment (OCR Feature)

If you need to use local OCR features:

1. Check Python 3:
   ```bash
   python3 --version
   ```

2. Install Pix2Text:
   ```bash
   pip3 install pix2text
   ```

3. Select "Local OCR-based formula processing" mode in preferences

> If Python is not configured, you can still use VLM API mode for OCR (requires network connection)

## ❓ Frequently Asked Questions

### Q: What if there's a compilation error?

A: 
- Ensure Xcode version >= 14.0
- Ensure macOS version >= 12.0
- Try cleaning build: `Product > Clean Build Folder` (Shift + Cmd + K)

### Q: Still getting errors after configuring API Key?

A: 
- Check if API Key is correct (no extra spaces)
- Check network connection
- Check error messages in Xcode console

### Q: OCR feature not working?

A: 
- If using local OCR, ensure Python and Pix2Text are installed
- If using VLM API, ensure network connection is normal and API Key is valid
- Check formula processing mode in preferences

### Q: How to update the project?

A: 
```bash
git pull origin main
```

## 📚 More Resources

- [Complete README](README_EN.md) - Detailed project introduction
- [API Configuration Guide](API_CONFIGURATION_EN.md) - Detailed API configuration instructions
- [Agent Feature Documentation](Agent_Feature_Documentation_EN.md) - Complete Agent feature documentation
- [Contributing Guide](CONTRIBUTING_EN.md) - How to contribute to the project

## 🎉 Start Using

You've completed the configuration and can start using HyperPaper!

If you encounter any issues, please ask in [GitHub Issues](https://github.com/Mengqi-Lei/HyperPaper/issues).

---

**Enjoy using it!** 🚀

