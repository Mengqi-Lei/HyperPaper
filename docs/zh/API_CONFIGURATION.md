# 🔑 API 配置指南

**Language / 语言**: [🇬🇧 English](../API_CONFIGURATION.md) | [🇨🇳 中文](API_CONFIGURATION.md)

在使用 HyperPaper 之前，你需要配置 API Key 才能使用 AI 问答和翻译功能。

## 📋 配置步骤

### 1. 获取 API Key

1. 访问 [ProbeX API](https://api.probex.top)
2. 注册账号并登录
3. 在控制台中创建 API Key
4. 复制你的 API Key（格式类似：`sk-...`）

### 2. 配置 API Key

#### 方法一：直接修改代码（推荐）

1. 打开项目文件：
   ```
   HyperPaper/HyperPaper/Models/APIConfig.swift
   ```

2. 找到以下代码：
   ```swift
   static let apiKey = "YOUR_API_KEY_HERE"
   ```

3. 将 `YOUR_API_KEY_HERE` 替换为你的实际 API Key：
   ```swift
   static let apiKey = "sk-你的实际API密钥"
   ```

4. 保存文件并重新编译运行

#### 方法二：通过环境变量（计划中）

未来版本将支持通过环境变量配置：

```bash
export HYPERPAPER_API_KEY="sk-你的API密钥"
```

#### 方法三：通过偏好设置界面（计划中）

未来版本将在偏好设置中添加 API Key 配置界面，使用 Keychain 安全存储。

## ⚠️ 安全提示

- **不要将包含真实 API Key 的代码提交到公共仓库**
- API Key 具有访问权限，请妥善保管

## 🔍 验证配置

配置完成后，你可以通过以下方式验证：

1. **运行应用**：打开 HyperPaper
2. **打开 PDF**：选择任意 PDF 文件
3. **测试功能**：
   - 框选文本区域
   - 在右侧问答面板输入问题
   - 如果 AI 能够正常回答，说明配置成功

## ❓ 常见问题

### Q: 如何知道 API Key 是否配置正确？

A: 如果配置错误，在使用 AI 功能时会看到错误提示。请检查：
- API Key 是否正确复制（没有多余空格）
- API Key 是否有效（未过期或被撤销）
- 网络连接是否正常

### Q: API Key 有使用限制吗？

A: 是的，API Key 通常有使用配额限制。具体限制请查看你的 API 服务商文档。

### Q: 可以同时使用多个 API Key 吗？

A: 当前版本只支持单个 API Key。如需切换，请修改 `APIConfig.swift` 文件。

### Q: 如何保护我的 API Key？

A: 
- 使用 `.gitignore` 排除包含 API Key 的文件（如果使用环境变量）
- 不要将 API Key 分享给他人
- 定期轮换 API Key
- 在 API 控制台中设置使用限制

## 📚 相关文档

- [Agent 功能详细说明文档](Agent_Feature_Documentation.md) - 查看完整的配置说明章节
- [README.md](README.md) - 项目总体介绍
- [CONTRIBUTING.md](CONTRIBUTING.md) - 贡献指南

---

**需要帮助？** 如果遇到配置问题，请在 [GitHub Issues](https://github.com/Mengqi-Lei/HyperPaper/issues) 中提问。

