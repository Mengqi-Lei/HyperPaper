# 📤 GitHub 发布指南

本指南将帮助你将 HyperPaper 项目发布到 GitHub。

## 🎯 方案选择

### 方案一：创建全新的 GitHub 仓库（推荐）

如果你还没有 GitHub 仓库，或者想创建一个全新的仓库来发布这个清理后的版本。

### 方案二：使用现有仓库

如果你已经有一个 GitHub 仓库，可以直接使用。

---

## 📋 方案一：创建新仓库并发布

### 步骤 1: 在 GitHub 上创建新仓库

1. 登录 GitHub
2. 点击右上角的 **"+"** 按钮，选择 **"New repository"**
3. 填写仓库信息：
   - **Repository name**: `HyperPaper`（或你喜欢的名字）
   - **Description**: `下一代智能 PDF 阅读与注释工具 - AI驱动的论文阅读助手`
   - **Visibility**: 
     - 选择 **Public**（公开，推荐）
     - 或 **Private**（私有，如果你不想公开）
   - **不要**勾选 "Initialize this repository with a README"（我们已经有了）
   - **不要**添加 .gitignore 或 license（我们已经有了）
4. 点击 **"Create repository"**

### 步骤 2: 在本地初始化 Git 仓库

```bash
# 进入发布版本目录
cd /Volumes/T7Shield/Projects/HyperPaper/HyperPaper-release

# 初始化 Git 仓库
git init

# 添加所有文件
git add .

# 创建首次提交
git commit -m "Initial commit: HyperPaper - AI-powered PDF reader and annotation tool"
```

### 步骤 3: 连接到 GitHub 仓库并推送

GitHub 会显示类似这样的命令，**替换 `<your-username>` 和 `<repository-name>`**：

```bash
# 添加远程仓库（替换为你的实际仓库地址）
git remote add origin https://github.com/<your-username>/<repository-name>.git

# 或者使用 SSH（如果你配置了 SSH key）
# git remote add origin git@github.com:<your-username>/<repository-name>.git

# 重命名主分支为 main（如果还没有）
git branch -M main

# 推送到 GitHub
git push -u origin main
```

**示例**（假设用户名是 `Mengqi-Lei`，仓库名是 `HyperPaper`）：
```bash
git remote add origin https://github.com/Mengqi-Lei/HyperPaper.git
git branch -M main
git push -u origin main
```

### 步骤 4: 验证发布

1. 访问你的 GitHub 仓库页面
2. 确认所有文件都已上传
3. 确认 README.md 正确显示
4. 确认 API Key 是占位符 `YOUR_API_KEY_HERE`（不是真实密钥）

---

## 📋 方案二：使用现有仓库

如果你已经有一个 GitHub 仓库，可以：

### 选项 A: 替换现有仓库内容

```bash
# 进入发布版本目录
cd /Volumes/T7Shield/Projects/HyperPaper/HyperPaper-release

# 初始化 Git（如果还没有）
git init

# 添加现有仓库作为远程
git remote add origin https://github.com/<your-username>/<repository-name>.git

# 拉取现有内容（如果有）
git pull origin main --allow-unrelated-histories

# 添加所有新文件
git add .

# 提交
git commit -m "Release: Clean version with API key placeholder"

# 推送
git push origin main
```

### 选项 B: 创建新分支

如果你想保留原有内容，可以创建一个新分支：

```bash
cd /Volumes/T7Shield/Projects/HyperPaper/HyperPaper-release

git init
git remote add origin https://github.com/<your-username>/<repository-name>.git
git checkout -b release/clean-version
git add .
git commit -m "Release: Clean version ready for public"
git push origin release/clean-version
```

---

## ✅ 发布后建议

### 1. 创建 Release Tag

```bash
# 创建标签
git tag -a v1.0.0 -m "First public release"

# 推送标签
git push origin v1.0.0
```

### 2. 在 GitHub 上创建 Release

1. 访问仓库页面
2. 点击 **"Releases"** → **"Create a new release"**
3. 选择刚创建的标签 `v1.0.0`
4. 填写 Release 信息：
   - **Title**: `HyperPaper v1.0.0 - First Public Release`
   - **Description**: 
     ```
     ## 🎉 首次公开发布
     
     ### ✨ 主要特性
     - AI 驱动的智能问答
     - OCR 识别和公式解析
     - 智能翻译
     - 完整的注释系统
     
     ### 📝 使用说明
     1. 克隆仓库
     2. 配置 API Key（见 API_CONFIGURATION.md）
     3. 在 Xcode 中打开并运行
     
     详细说明请查看 README.md 和 QUICK_START.md
     ```
5. 点击 **"Publish release"**

### 3. 添加仓库描述和主题

在仓库设置中添加：
- **Description**: `下一代智能 PDF 阅读与注释工具 - AI驱动的论文阅读助手`
- **Topics**: `swift`, `swiftui`, `pdf-reader`, `ai`, `ocr`, `pdf-annotation`, `macos`, `qwen`, `pix2text`

### 4. 添加徽章（可选）

在 README.md 顶部已经有徽章，确保仓库地址正确。

---

## 🔒 安全检查清单

在推送前，再次确认：

- [ ] API Key 已替换为 `YOUR_API_KEY_HERE`
- [ ] 没有硬编码的密码或密钥
- [ ] `.gitignore` 已配置
- [ ] 没有包含 `.env` 或其他敏感文件
- [ ] 构建文件和用户文件已排除

**验证命令**：
```bash
# 检查是否还有真实 API Key
cd /Volumes/T7Shield/Projects/HyperPaper/HyperPaper-release
grep -r "sk-nhPh96zksiEQMILYe0kx4yQZx0juPSHRkEjEQ7cwglzEf2YL" . || echo "✅ 没有找到真实 API Key"
```

---

## 🆘 常见问题

### Q: 推送时要求输入用户名和密码？

A: 
- 使用 Personal Access Token 代替密码
- 或配置 SSH key（推荐）

### Q: 如何创建 Personal Access Token？

A:
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token
3. 选择权限：`repo`（完整仓库访问）
4. 复制 token，在推送时作为密码使用

### Q: 如何配置 SSH key？

A:
```bash
# 生成 SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# 复制公钥
cat ~/.ssh/id_ed25519.pub

# 添加到 GitHub: Settings → SSH and GPG keys → New SSH key
```

### Q: 推送后想修改某些文件怎么办？

A:
```bash
# 修改文件后
git add .
git commit -m "Update: 描述你的修改"
git push origin main
```

---

## 📚 相关文档

- [README.md](README.md) - 项目总体介绍
- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [API_CONFIGURATION.md](API_CONFIGURATION.md) - API 配置说明
- [RELEASE_NOTES.md](RELEASE_NOTES.md) - 发布说明

---

**准备好发布了吗？** 🚀

按照上述步骤操作，你的项目就可以在 GitHub 上公开了！

