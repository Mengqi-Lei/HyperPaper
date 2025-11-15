# 🔑 API Configuration Guide

**Language / 语言**: [🇨🇳 中文](API_CONFIGURATION.md) | [🇬🇧 English](API_CONFIGURATION_EN.md)

Before using HyperPaper, you need to configure an API Key to use AI Q&A and translation features.

## 📋 Configuration Steps

### 1. Get API Key

1. Visit [ProbeX API](https://api.probex.top)
2. Register an account and log in
3. Create an API Key in the console
4. Copy your API Key (format similar to: `sk-...`)

### 2. Configure API Key

#### Method 1: Direct Code Modification (Recommended)

1. Open the project file:
   ```
   HyperPaper/HyperPaper/Models/APIConfig.swift
   ```

2. Find the following code:
   ```swift
   static let apiKey = "YOUR_API_KEY_HERE"
   ```

3. Replace `YOUR_API_KEY_HERE` with your actual API Key:
   ```swift
   static let apiKey = "sk-your-actual-api-key"
   ```

4. Save the file and rebuild

#### Method 2: Environment Variables (Planned)

Future versions will support configuration via environment variables:

```bash
export HYPERPAPER_API_KEY="sk-your-api-key"
```

#### Method 3: Preferences Interface (Planned)

Future versions will add an API Key configuration interface in preferences, using Keychain for secure storage.

## ⚠️ Security Tips

- **Do not commit code containing real API Keys to public repositories**
- API Keys have access permissions, please keep them safe

## 🔍 Verify Configuration

After configuration, you can verify in the following ways:

1. **Run the Application**: Open HyperPaper
2. **Open PDF**: Select any PDF file
3. **Test Features**:
   - Select a text area
   - Enter questions in the right-side Q&A panel
   - If AI can answer normally, the configuration is successful

## ❓ Frequently Asked Questions

### Q: How do I know if the API Key is configured correctly?

A: If configured incorrectly, you will see error messages when using AI features. Please check:
- Whether the API Key is copied correctly (no extra spaces)
- Whether the API Key is valid (not expired or revoked)
- Whether the network connection is normal

### Q: Are there usage limits for API Keys?

A: Yes, API Keys usually have usage quota limits. Please check your API service provider's documentation for specific limits.

### Q: Can I use multiple API Keys at the same time?

A: The current version only supports a single API Key. To switch, please modify the `APIConfig.swift` file.

### Q: How do I protect my API Key?

A: 
- Use `.gitignore` to exclude files containing API Keys (if using environment variables)
- Do not share your API Key with others
- Regularly rotate API Keys
- Set usage limits in the API console

## 📚 Related Documentation

- [Agent Feature Documentation](Agent_Feature_Documentation_EN.md) - See the complete configuration section
- [README.md](README_EN.md) - Project overview
- [CONTRIBUTING.md](CONTRIBUTING_EN.md) - Contributing guide

---

**Need Help?** If you encounter configuration issues, please ask in [GitHub Issues](https://github.com/Mengqi-Lei/HyperPaper/issues).

