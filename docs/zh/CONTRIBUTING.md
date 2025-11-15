# 贡献指南

**Language / 语言**: [🇬🇧 English](../CONTRIBUTING.md) | [🇨🇳 中文](CONTRIBUTING.md)

感谢你考虑为 HyperPaper 项目做出贡献！

## 如何贡献

### 报告问题

如果你发现了一个bug或有功能建议，请：

1. 检查 [Issues](https://github.com/your-username/HyperPaper/issues) 确认问题尚未被报告
2. 如果不存在，创建一个新的Issue：
   - Bug报告：使用 [Bug报告模板](.github/ISSUE_TEMPLATE/bug_report.md)
   - 功能请求：使用 [功能请求模板](.github/ISSUE_TEMPLATE/feature_request.md)

### 提交代码

1. Fork 这个仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

### 代码规范

- 遵循项目的代码风格
- 确保代码有适当的注释
- 添加必要的测试
- 更新相关文档

### 提交信息规范

我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更改
- `style`: 代码格式（不影响代码运行的更改）
- `refactor`: 代码重构
- `test`: 添加或修改测试
- `chore`: 构建过程或辅助工具的变动

示例：
```
feat: 添加用户登录功能
fix: 修复版本号显示问题
docs: 更新README说明
```

### 版本管理

当你的更改需要发布新版本时：

1. 更新 `VERSION` 文件
2. 更新 `CHANGELOG.md` 记录变更
3. 创建Git标签并推送到GitHub

## 问题？

如果你有任何问题，请随时在 [Issues](https://github.com/your-username/HyperPaper/issues) 中提出。

