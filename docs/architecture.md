# 架构与边界

## 组件职责

macOS 应用壳只负责启动和生命周期管理：选择本地端口、复用已有服务、从钥匙串读取可选 DeepSeek Key、启动 PDFMathTranslate 并打开浏览器。它不实现 PDF 解析、翻译或排版算法。

`runtime/python/` 是 uv 提供的可迁移 Python 3.12；`runtime/.venv/` 保存上游锁定依赖；`runtime/src/` 保存当前 PDFMathTranslate 源码；`babeldoc-cache/` 预置布局模型、字体和 CMap。

## 数据流

1. 用户把 PDF 交给本机 WebUI。
2. BabelDOC 在本机解析文本块、公式、图表和阅读顺序。
3. 待翻译文本发送给用户选择的翻译服务，或交给本机 Ollama。
4. BabelDOC 把译文写回文档中间表示并重新渲染 PDF。
5. 用户从浏览器下载双语或纯译文结果。

## 进程与文件

| 项目 | 位置或行为 |
| --- | --- |
| WebUI 地址 | `127.0.0.1:7860` 起的首个空闲端口 |
| PID | `~/Library/Application Support/PDF Bilingual Translator/server.pid` |
| 端口 | `~/Library/Application Support/PDF Bilingual Translator/server.port` |
| 日志 | `~/Library/Logs/PDF Bilingual Translator/webui.log` |
| 资源缓存 | `~/.cache/babeldoc/` |
| DeepSeek Key | macOS 钥匙串服务 `local.codex.pdf-bilingual-translator.deepseek` |

## 安全边界

启动器不把 Key 放进命令行参数或 Git。Key 会存在于翻译进程环境中，这是调用上游 SDK 所必需的；同一用户下拥有调试权限的本机进程理论上仍可检查该进程，因此不要在不受信任的共享账号中运行。

WebUI 不启用公网分享，但在线模型服务是外部信任边界。敏感文档应使用本机 Ollama，或先确认服务商的数据处理政策。
