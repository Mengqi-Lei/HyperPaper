# HyperPaper Agent Feature Detailed Documentation

**Language / 语言**: [🇨🇳 中文](Agent功能详细说明文档.md) | [🇬🇧 English](Agent_Feature_Documentation_EN.md)

**Version**: v1.0  
**Author**: Mengqi Lei

---

## 📋 Table of Contents

1. [Feature Overview](#feature-overview)
2. [Architecture Design](#architecture-design)
3. [Core Feature Modules](#core-feature-modules)
4. [Workflow](#workflow)
5. [AI Service Integration](#ai-service-integration)
6. [Configuration Guide](#configuration-guide)
   - [API Key Configuration](#api-key-configuration)
   - [Environment Variables](#environment-variables)
   - [Preferences Settings](#preferences-settings)
7. [Technical Implementation Details](#technical-implementation-details)
8. [Data Flow](#data-flow)
9. [Error Handling](#error-handling)
10. [Performance Optimization](#performance-optimization)
11. [Future Plans](#future-plans)

---

## Feature Overview

### What is Agent Mode?

Agent Mode is the core intelligent feature of HyperPaper, allowing users to interact with AI by selecting arbitrary regions in PDF documents, enabling:

- **Regional Q&A**: Ask questions based on selected content for precise answers
- **Intelligent Translation**: Automatically detect language and translate to specified target language
- **OCR Recognition**: Recognize regions containing formulas and charts, converting them to editable text
- **Formula Processing**: Automatically recognize mathematical formulas and convert them to LaTeX format
- **Multi-region Support**: Support cross-page selection, unified processing of multiple regions

### Core Value

1. **Context Understanding**: AI answers questions based on the specific content selected by users, not the entire document
2. **Multimodal Processing**: Simultaneously supports recognition and understanding of text, images, and formulas
3. **Real-time Feedback**: OCR progress visualization, translation results update in real-time
4. **Intelligent Degradation**: Automatically degrades to text extraction when Vision API fails

---

## Architecture Design

### Overall Architecture

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
│  │ Text Display │  │ Translation  │  │ Q&A Function │     │
│  │    Area      │  │    Area      │  │    Area      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PDFReaderView                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │          AnnotationInteractionNSView                  │  │
│  │  - Region Selection                                    │  │
│  │  - Text Extraction                                     │  │
│  │  - Image Extraction                                    │  │
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

### Module Division

#### 1. UI Layer
- **QuestionAnswerViewWrapper**: Main view for Agent mode
- **MarkdownLaTeXView**: Markdown and LaTeX rendering component

#### 2. Business Logic Layer
- **PDFReaderView**: PDF rendering and interaction handling
- **AnnotationInteractionNSView**: Region selection and text extraction

#### 3. Service Layer
- **QwenAPIService**: AI service encapsulation (Q&A, translation, Vision API)
- **Pix2TextService**: Local OCR service
- **PDFTextExtractor**: PDF text extraction
- **PDFImageExtractor**: PDF image extraction

---

## Core Feature Modules

### 1. Region Selection and Text Extraction

#### Feature Description
Users can drag to select arbitrary regions on PDF, and the system automatically extracts the text content of that region.

#### Implementation Location
- `PDFReaderView.swift` - `AnnotationInteractionNSView`
- `PDFTextExtractor.swift`

#### Workflow

```
User drags to select region
    │
    ▼
AnnotationInteractionNSView.mouseDragged
    │
    ▼
Create SelectionRegion (pageIndex, rect)
    │
    ▼
PDFTextExtractor.extractText
    │
    ▼
PDFPage.selection(for: rect)
    │
    ▼
Update selectedText (via @Binding)
    │
    ▼
QuestionAnswerViewWrapper displays text
```

#### Key Code

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

#### Multi-region Support

The system supports selecting multiple regions across pages, and all region texts are automatically merged:

```swift
// Merge texts from multiple regions
let combinedText = regions
    .compactMap { extractText(from: document, pageIndex: $0.pageIndex, rect: $0.rect) }
    .joined(separator: "\n\n")
```

---

### 2. OCR Recognition Feature

#### Feature Description
When the user-selected region contains images, formulas, or cannot directly extract text, the system automatically triggers OCR recognition.

#### Implementation Location
- `PDFReaderView.swift` - `processSelectionWithOCR`
- `Pix2TextService.swift`
- `PDFImageExtractor.swift`

#### Workflow

```
Selection region detected
    │
    ▼
Try text extraction
    │
    ├─ Success → Use text directly
    │
    └─ Failure/Empty text → Trigger OCR
        │
        ▼
Check formula processing mode (FormulaProcessingMode)
    │
    ├─ .none → Skip OCR
    │
    ├─ .localOCR → Use Pix2Text
    │   │
    │   ├─ Extract image (PDFImageExtractor)
    │   │
    │   ├─ Save temporary file
    │   │
    │   ├─ Call Python script (pix2text_ocr.py)
    │   │
    │   ├─ Parse progress (read tqdm output from stderr)
    │   │
    │   └─ Return Markdown format result (with LaTeX)
    │
    └─ .vlmAPI → Use Vision API
        │
        ├─ Extract image (PDFImageExtractor)
        │
        ├─ Convert to Base64
        │
        └─ Call QwenAPIService.recognizeImage
```

#### OCR Progress Management

The system implements real-time OCR progress updates through `NotificationCenter`:

```swift
// Send progress update notification
NotificationCenter.default.post(
    name: NSNotification.Name("OCRProgressUpdate"),
    object: nil,
    userInfo: ["progress": progress, "completed": false]
)

// Send completion notification
NotificationCenter.default.post(
    name: NSNotification.Name("OCRCompleted"),
    object: nil,
    userInfo: ["completed": true]
)
```

#### Pix2Text Integration

Pix2Text is called through Python scripts, supporting:
- Mathematical formula recognition (converted to LaTeX)
- Table recognition
- Mixed layout recognition
- Progress feedback (via stderr output)

**Script Path Lookup Strategy**:
1. Script in App Bundle
2. Script in project directory (during development)
3. Environment variables or hardcoded paths

**Progress Parsing**:
- Read tqdm output from stderr
- Parse percentage or fraction format (e.g., "50%" or "1/2")
- Simulate progress (if real progress cannot be parsed)

---

### 3. Intelligent Translation Feature

#### Feature Description
Automatically detect the language of selected text and translate to the specified target language.

#### Implementation Location
- `QuestionAnswerViewWrapper` - `triggerTranslation`
- `QwenAPIService.swift` - `translate`

#### Workflow

```
selectedText changes
    │
    ▼
Detect change type
    │
    ├─ OCR update → handleOCRUpdate
    │   │
    │   ├─ Save old translation state (hadTranslationBeforeOCR)
    │   │
    │   ├─ Set pendingOCRTranslation = true
    │   │
    │   └─ Wait for OCRCompleted notification
    │       │
    │       └─ Trigger silent translation (no "Translating..." display)
    │
    └─ Normal update → handleNormalUpdate
        │
        └─ Immediately trigger translation (show "Translating...")
            │
            ▼
triggerTranslationWithDebounce
    │
    ├─ Cancel previous translation task
    │
    ├─ Detect source language
    │   │
    │   └─ Simple detection: Check if contains Chinese characters
    │
    ├─ Get target language (TranslationTargetLanguage.current)
    │   │
    │   └─ Determine actual target language based on source language and target language settings
    │
    └─ Call QwenAPIService.translate
        │
        └─ Update translatedText
```

#### Translation Version Management

The system uses `translationVersion` to distinguish between original text translation and OCR result translation:

```swift
@State private var translationVersion: String = "original" // "original" or "ocr"
```

#### Silent Update Mechanism

When OCR results return, if there was a previous translation result, the system silently updates (without showing "Translating..." state) to avoid flickering:

```swift
if hadTranslation {
    // Has old translation result, silent update
    self.isTranslating = false
} else {
    // No old translation result, show "Translating..."
    self.isTranslating = true
}
```

#### Debounce Mechanism

Translation requests use debounce mechanism to avoid frequent API calls:

```swift
// Cancel previous task
translationTask?.cancel()

// Create new task (delay 0.5 seconds)
translationTask = Task {
    try? await Task.sleep(nanoseconds: 500_000_000)
    // Execute translation
}
```

---

### 4. AI Q&A Feature

#### Feature Description
Users can ask questions about selected text content, and AI provides precise answers based on context.

#### Implementation Location
- `QuestionAnswerViewWrapper` - `submitQuestion`
- `QwenAPIService.swift` - `askQuestion`

#### Workflow

```
User inputs question
    │
    ▼
Click "Ask" button
    │
    ▼
submitQuestion()
    │
    ├─ Validate question is not empty
    │
    ├─ Set loading state (isLoading = true)
    │
    └─ Call QwenAPIService.askQuestion
        │
        ├─ Build message list
        │   │
        │   ├─ System Message: Define AI role
        │   │   "You are a professional academic paper reading assistant..."
        │   │
        │   └─ User Message: Include context and question
        │       "Paper content: {selectedText}"
        │       "User question: {question}"
        │
        ├─ Send HTTP request
        │
        ├─ Parse response
        │
        └─ Update answer
            │
            └─ MarkdownLaTeXView renders answer
```

#### System Prompt Design

```swift
"""
You are a professional academic paper reading assistant. The user has selected a section of paper content and asked a question.

Please answer the question based on the selected paper content. If the question involves content not found in the selected text, please clearly state so.
Answers should be accurate, concise, and professional.
"""
```

#### Context Handling

- **With Context**: Send selected text and question together to AI
- **Without Context**: Only send question (allows general Q&A)

---

### 5. Vision API Integration

#### Feature Description
Use Qwen-VL-Max model to process image content, supporting recognition, translation, and Q&A.

#### Implementation Location
- `QwenAPIService.swift` - `processImageWithVision`
- `PDFReaderView.swift` - `processSelectionWithVision`

#### Vision API Message Format

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

#### Supported Vision API Features

1. **Image Recognition** (`recognizeImage`)
   - Recognize text and formulas in images
   - Convert formulas to LaTeX format

2. **Image Translation** (`translateImage`)
   - Recognize and translate image content
   - Preserve format and structure

3. **Image Q&A** (`askQuestionAboutImage`)
   - Answer questions based on image content
   - Support formula explanation

#### Degradation Strategy

When Vision API fails, the system automatically degrades to text extraction:

```swift
catch {
    // Vision API failed, degrade to text extraction
    if let text = PDFTextExtractor.extractText(...) {
        // Use text extraction result
    }
}
```

---

## Workflow

### Complete User Interaction Flow

```
1. User opens PDF document
   │
   ▼
2. Switch to Agent mode
   │
   ▼
3. Enable selection mode (click toolbar button)
   │
   ▼
4. Drag to select region on PDF
   │
   ├─ Text region
   │   │
   │   ├─ Directly extract text
   │   │
   │   └─ Display in "Selected Paper Content" area
   │       │
   │       └─ Automatically trigger translation (if enabled)
   │
   └─ Image/Formula region
       │
       ├─ Detect formula processing mode
       │
       ├─ Extract image
       │
       ├─ Trigger OCR (local or Vision API)
       │
       ├─ Display OCR progress
       │
       ├─ Display recognition result (with LaTeX)
       │
       └─ Automatically trigger translation (if enabled)
           │
           └─ Silent update (if previous translation existed)
   │
   ▼
5. User can ask questions in "Q&A Function" area
   │
   ├─ Input question
   │
   ├─ Click "Ask" button
   │
   ├─ AI answers based on selected content
   │
   └─ Display answer (supports Markdown and LaTeX)
```

---

## AI Service Integration

### Qwen API Service

#### Configuration

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

#### Supported Models

1. **Qwen2.5-14B-Instruct** (default)
   - Fast response
   - Suitable for most scenarios

2. **Qwen2.5-32B-Instruct**
   - Balanced performance
   - Higher quality answers

3. **deepseek-chat**
   - High quality answers
   - Suitable for complex questions

4. **Qwen3-235B-A22B**
   - Strongest capability
   - Handle complex tasks

5. **Qwen-VL-Max**
   - Vision model
   - Supports image input

#### API Request Format

**Standard Chat Completion**:

```json
{
  "model": "Qwen2.5-14B-Instruct",
  "messages": [
    {
      "role": "system",
      "content": "You are a professional academic paper reading assistant..."
    },
    {
      "role": "user",
      "content": "Paper content: ...\n\nUser question: ..."
    }
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

**Vision API**:

```json
{
  "model": "Qwen-VL-Max",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Please recognize the content in this image..."
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

#### Error Handling

The system implements comprehensive error handling:

```swift
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}
```

**Network Error Friendly Messages**:
- `NSURLErrorNotConnectedToInternet` → "Please check network connection"
- `NSURLErrorTimedOut` → "Request timeout, please try again later"
- `NSURLErrorCannotFindHost` → "Cannot connect to server"

#### Retry Mechanism

The system supports multiple fallback URLs:

```swift
let urlStrings = [
    baseURL,
    "https://api.probex.top/v1/chat/completions",
    "https://api.probex.top/v1",
]
```

---

## Configuration Guide

### API Key Configuration

#### Development Environment Configuration

API Key is currently hardcoded in the `APIConfig.swift` file:

```swift
// HyperPaper/HyperPaper/Models/APIConfig.swift
struct APIConfig {
    static let apiKey = "sk-..."  // Modify your API Key here
    static let baseURL = "https://api.probex.top/v1/chat/completions"
}
```

**Configuration Steps**:

1. Open `HyperPaper/HyperPaper/Models/APIConfig.swift`
2. Replace the `apiKey` value with your API Key
3. Rebuild and run

**⚠️ Security Tips**:
- Do not commit code containing real API Keys to public repositories
- Recommend using environment variables or configuration files (future versions will support)

#### Production Environment Configuration (Planned)

Future versions will support configuration through:

1. **Environment Variables**:
   ```bash
   export HYPERPAPER_API_KEY="sk-..."
   ```

2. **Configuration File**:
   ```json
   {
     "apiKey": "sk-...",
     "baseURL": "https://api.probex.top/v1/chat/completions"
   }
   ```

3. **Preferences Interface**:
   - Add API Key input field in preferences
   - Use Keychain for secure storage

---

### Environment Variables

#### Python Environment Configuration (OCR Feature)

Pix2Text OCR feature requires Python 3 environment. The system automatically searches for Python path in the following order:

1. **Python in App Bundle** (if included when packaging)
   ```
   {Bundle}/Resources/Python3/python3
   ```

2. **System Python**
   ```bash
   /usr/bin/python3
   /usr/local/bin/python3
   /opt/homebrew/bin/python3  # Apple Silicon Mac
   ```

3. **Find via `which` command**
   ```bash
   which python3
   ```

**Verify Python Environment**:

```bash
# Check Python version
python3 --version

# Check if Pix2Text is installed
python3 -c "import pix2text; print('Pix2Text installed')"
```

**Install Pix2Text** (if not installed):

```bash
pip3 install pix2text
```

#### OCR Script Path

The system searches for OCR script in the following order:

1. **Script in App Bundle**
   ```
   {Bundle}/Resources/Scripts/pix2text_ocr.py
   ```

2. **Script in project directory** (during development)
   ```
   {ProjectRoot}/Scripts/pix2text_ocr.py
   ```

3. **Hardcoded path** (during development)
   ```
   ~/Projects/HyperPaper/Scripts/pix2text_ocr.py
   /Volumes/T7Shield/Projects/HyperPaper/Scripts/pix2text_ocr.py
   ```

---

### Preferences Settings

#### Open Preferences

1. **Menu Bar Method**:
   - Click menu bar `HyperPaper > Preferences...`
   - Or use shortcut `Cmd + ,`

2. **Toolbar Method**:
   - Click settings button in floating toolbar

#### Preferences Options

The preferences interface contains three main sections:

##### 1. Model Settings

**Function**: Select AI model for Q&A and translation

**Available Models**:

| Model Name | Description | Price | Use Case |
|------------|-------------|-------|----------|
| Qwen2.5-14B-Instruct | Fast response (Recommended) | Input $0.30/M, Output $0.45/M | Daily use, quick Q&A |
| Qwen2.5-32B-Instruct | Balanced performance | Input $0.50/M, Output $0.75/M | Need higher quality answers |
| DeepSeek Chat | High quality answers | Input $1.00/M, Output $1.50/M | Complex question handling |
| Qwen3-235B-A22B | Strongest capability (slower) | Higher price | Most complex tasks |
| Qwen-VL-Max | Vision model (formula recognition) | Supports image input | Formula and chart recognition |

**Configuration Method**:
- Click to select model in preferences interface
- Settings are automatically saved to `UserDefaults`, key name: `selectedModel`

**Code Access**:
```swift
// Read current model
let currentModel = APIConfig.model

// Set model
APIConfig.model = "Qwen2.5-32B-Instruct"
```

##### 2. Formula Processing Mode

**Function**: Choose how to handle regions containing formulas

**Available Modes**:

| Mode | Description | Use Case |
|------|-------------|----------|
| No formula processing | Directly extract text, no formula recognition | Pure text regions |
| Local OCR-based formula processing | Use local Pix2Text for OCR recognition, supports formula to LaTeX conversion | Need offline processing, privacy protection |
| VLM API-based formula processing | Use Vision API (Qwen-VL-Max) for recognition | Need higher recognition accuracy |

**Configuration Method**:
- Select processing mode in preferences interface
- Settings are automatically saved to `UserDefaults`, key name: `formulaProcessingMode`

**Code Access**:
```swift
// Read current mode
let currentMode = FormulaProcessingMode.current

// Set mode
FormulaProcessingMode.current = .localOCR
```

**Mode Selection Recommendations**:
- **No formula processing**: If document is mainly plain text, selecting this mode improves speed
- **Local OCR**: Suitable for scenarios requiring privacy protection, but requires Python and Pix2Text installation
- **VLM API**: Suitable for scenarios requiring high accuracy, but requires network connection and API quota

##### 3. Translation Target Language

**Function**: Set translation target language

**Available Languages**:

| Language | Code | Description |
|----------|------|-------------|
| Auto detect | auto | Automatically select target language based on source language (Chinese ↔ English) |
| Chinese | chinese | Simplified Chinese |
| English | english | English |
| Japanese | japanese | Japanese |
| Korean | korean | Korean |
| French | french | French |
| German | german | German |
| Spanish | spanish | Spanish |

**Auto Detection Logic**:
- If source language is Chinese, target language is English
- If source language is English, target language is Chinese

**Configuration Method**:
- Select target language in preferences interface
- Settings are automatically saved to `UserDefaults`, key name: `translationTargetLanguage`

**Code Access**:
```swift
// Read current target language
let currentLanguage = TranslationTargetLanguage.current

// Set target language
TranslationTargetLanguage.current = .english

// Get actual target language based on source language
let targetLanguage = TranslationTargetLanguage.current.getTargetLanguage(sourceLanguage: "中文")
// Returns: "English"
```

#### Preferences Storage Location

All preferences are stored in macOS `UserDefaults`:

**Storage Location**:
```
~/Library/Preferences/com.yourcompany.HyperPaper.plist
```

**Stored Key-Value Pairs**:

| Key Name | Type | Description |
|----------|------|-------------|
| `selectedModel` | String | Selected AI model |
| `formulaProcessingMode` | String | Formula processing mode |
| `translationTargetLanguage` | String | Translation target language |

**Manual Modification (Not Recommended)**:

If manual modification is needed, you can use the `defaults` command:

```bash
# View all settings
defaults read com.yourcompany.HyperPaper

# Set model
defaults write com.yourcompany.HyperPaper selectedModel "Qwen2.5-32B-Instruct"

# Set formula processing mode
defaults write com.yourcompany.HyperPaper formulaProcessingMode "基于本地OCR处理公式"

# Set translation target language
defaults write com.yourcompany.HyperPaper translationTargetLanguage "English"
```

**⚠️ Note**: After manual modification, the application needs to be restarted to take effect.

#### Preferences Synchronization

Preference saving and reading are synchronous:

```swift
// Save settings
UserDefaults.standard.set(value, forKey: key)
UserDefaults.standard.synchronize()  // Immediately sync to disk

// Read settings
let value = UserDefaults.standard.string(forKey: key)
```

#### Reset Preferences

If you need to reset all preferences:

1. **Via Code**:
   ```swift
   // Delete all HyperPaper-related UserDefaults
   UserDefaults.standard.removePersistentDomain(forName: "com.yourcompany.HyperPaper")
   ```

2. **Via Command Line**:
   ```bash
   defaults delete com.yourcompany.HyperPaper
   ```

3. **Manual Deletion**:
   - Delete `~/Library/Preferences/com.yourcompany.HyperPaper.plist`
   - Restart application

---

## Technical Implementation Details

### 1. Coordinate System Conversion

PDF uses a coordinate system with origin at bottom-left, while images and views use top-left as origin. The system needs to handle coordinate conversion:

```swift
// PDF coordinate system → Image coordinate system
let imageY = pageHeight - pdfY - height

// Coordinate conversion during image extraction
let cropRect = CGRect(
    x: region.rect.origin.x * scale,
    y: (pageHeight - region.rect.origin.y - region.rect.height) * scale,
    width: region.rect.width * scale,
    height: region.rect.height * scale
)
```

### 2. Image Extraction and Processing

#### Extraction Process

1. **Create temporary image** (full page size)
2. **Draw entire PDF page** to temporary image
3. **Crop target region**
4. **Flip image** (PDF coordinate system → Image coordinate system)
5. **Add white background**

#### Scaling Processing

The system uses 2.0x scaling to improve recognition quality, while limiting maximum size to avoid memory issues:

```swift
let maxSize: CGFloat = 4096
let adjustedScale = min(scale, maxSize / max(region.rect.width, region.rect.height))
```

### 3. State Management

#### Key State Variables

```swift
// OCR related
@State private var ocrProgress: Double = 0.0
@State private var isProcessingOCR: Bool = false
@State private var isOCRPending: Bool = false
@State private var lastOCRCompletionTime: Date?

// Translation related
@State private var isTranslating: Bool = false
@State private var translatedText: String = ""
@State private var translationVersion: String = "original"
@State private var hadTranslationBeforeOCR: Bool = false
@State private var pendingOCRTranslation: Bool = false

// Q&A related
@State private var question: String = ""
@State private var answer: String = ""
@State private var isLoading: Bool = false
```

#### State Synchronization

The system uses `NotificationCenter` to implement cross-component state synchronization:

- `OCRProgressUpdate`: OCR progress update
- `OCRCompleted`: OCR completion notification

### 4. Asynchronous Processing

All AI service calls use Swift's `async/await` pattern:

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

## Data Flow

### Text Extraction Data Flow

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
    └─ MarkdownLaTeXView renders
```

### OCR Data Flow

```
SelectionRegion
    │
    ▼
PDFImageExtractor.extractImage
    │
    ├─ Extract image (NSImage)
    │
    ├─ Save temporary file
    │
    └─ Pix2TextService.recognizeImage
        │
        ├─ Call Python script
        │
        ├─ Parse progress (stderr)
        │
        └─ Return Markdown result
            │
            ▼
        selectedText updates
            │
            └─ Trigger translation
```

### Translation Data Flow

```
selectedText changes
    │
    ▼
Detect change type
    │
    ├─ OCR update → Wait for OCRCompleted
    │
    └─ Normal update → Immediately translate
        │
        ▼
QwenAPIService.translate
    │
    ├─ Detect source language
    │
    ├─ Get target language
    │
    └─ Send API request
        │
        ▼
translatedText updates
    │
    └─ MarkdownLaTeXView renders
```

### Q&A Data Flow

```
User inputs question
    │
    ▼
submitQuestion()
    │
    ▼
QwenAPIService.askQuestion
    │
    ├─ Build message list
    │   ├─ System Message
    │   └─ User Message (with context)
    │
    └─ Send API request
        │
        ▼
answer updates
    │
    └─ MarkdownLaTeXView renders
```

---

## Error Handling

### OCR Error Handling

```swift
enum Pix2TextError: Error {
    case pythonNotFound
    case scriptNotFound
    case processFailed(String)
    case invalidOutput
    case timeout
}
```

**Handling Strategy**:
1. Check Python environment
2. Check script path
3. Parse error information from process output
4. Timeout protection (60 seconds)

### API Error Handling

```swift
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}
```

**Handling Strategy**:
1. Try multiple fallback URLs
2. Parse HTTP status code
3. Extract error information from API response
4. Provide friendly error messages

### Degradation Strategy

When advanced features fail, the system automatically degrades:

1. **Vision API failure** → Degrade to text extraction
2. **OCR failure** → Display error, preserve original selection
3. **Translation failure** → Display error message, preserve original text

---

## Performance Optimization

### 1. Debounce Mechanism

Translation requests use debounce to avoid frequent calls:

```swift
translationTask?.cancel()
translationTask = Task {
    try? await Task.sleep(nanoseconds: 500_000_000)
    // Execute translation
}
```

### 2. Task Cancellation

Support canceling ongoing tasks:

```swift
currentTranslationTask?.cancel()
```

### 3. Image Size Limitation

Limit maximum image size to avoid memory issues:

```swift
let maxSize: CGFloat = 4096
let adjustedScale = min(scale, maxSize / max(width, height))
```

### 4. Progress Simulation

When real progress cannot be parsed, use simulated progress to avoid UI freezing:

```swift
let simulatedProgressTimer = Timer.scheduledTimer(...) {
    let newProgress = min(currentProgress + 0.02, 1.0)
    progressCallback(newProgress)
}
```

### 5. Asynchronous Processing

All time-consuming operations execute on background threads, UI updates on main thread:

```swift
Task {
    // Background processing
    let result = try await processData()
    
    await MainActor.run {
        // UI update
        self.result = result
    }
}
```

---

## Future Plans

### Short-term Optimization

1. **Caching Mechanism**
   - Cache OCR results to avoid duplicate recognition
   - Cache translation results to improve response speed

2. **Batch Processing**
   - Support batch OCR recognition
   - Batch translate multiple regions

3. **Offline Support**
   - Local model support (partial features)
   - Offline OCR cache

### Long-term Plans

1. **Knowledge Base Integration**
   - Build paper knowledge base
   - Support cross-document Q&A

2. **Multimodal Enhancement**
   - Support video content recognition
   - Support audio transcription

3. **Collaboration Features**
   - Share Q&A results
   - Collaborative annotation

---

## Appendix

### Key File List

- `HyperPaper/HyperPaper/Views/MainView.swift` - Main view, mode switching
- `HyperPaper/HyperPaper/Views/QuestionAnswerView.swift` - Q&A view (legacy)
- `HyperPaper/HyperPaper/Views/MainView.swift` (QuestionAnswerViewWrapper) - Q&A view wrapper
- `HyperPaper/HyperPaper/Services/QwenAPIService.swift` - AI service encapsulation
- `HyperPaper/HyperPaper/Services/Pix2TextService.swift` - OCR service
- `HyperPaper/HyperPaper/Services/PDFTextExtractor.swift` - Text extraction
- `HyperPaper/HyperPaper/Services/PDFImageExtractor.swift` - Image extraction
