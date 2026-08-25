# 安全说明

## 报告安全问题

请通过 GitHub Security Advisory 私下报告应用启动器、打包脚本或发布产物中的安全问题。不要在公开 Issue 中提交 API Key、私密 PDF、完整日志或本机路径截图。

PDFMathTranslate 或 BabelDOC 本身的问题应提交到相应上游仓库。

## API Key

发布包不包含 API Key。推荐把 DeepSeek Key 保存到 macOS 钥匙串，启动器只在运行时读取。仓库忽略 `.env`、`config.toml`、日志、DMG 和 `secrets/` 目录。

如果 Key 曾出现在公开提交、Issue、Release、终端录屏或共享日志中，请立即到对应模型服务商后台撤销并创建新 Key。仅从 Git 历史删除字符串不等于完成密钥轮换。

## 网络边界

WebUI 仅用于本机访问，不启用 Gradio `share`。在线翻译服务仍会接收需要翻译的文本；完全本地处理需要使用 Ollama 等本地模型。
