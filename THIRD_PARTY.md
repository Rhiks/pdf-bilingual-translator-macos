# 第三方组件

本项目是 PDFMathTranslate 2.0 的第三方 macOS 分发封装。

| 组件 | 固定版本或来源 | 用途 | 许可证 |
| --- | --- | --- | --- |
| PDFMathTranslate-next | commit `3538a8195d8379fe3fb4a0117c88d15c5b7b5e89` | CLI、服务配置和 WebUI | AGPL-3.0 |
| BabelDOC | `0.5.24` | PDF 布局解析与恢复 | AGPL-3.0 |
| Gradio | `5.35.0` | 本地 WebUI | Apache-2.0 |
| Python | `3.12.13`，uv managed build | 独立运行时 | PSF-2.0 |
| BabelDOC Assets | funstory-ai/BabelDOC-Assets | 字体、CMap 和模型资源 | 各资产自带许可证 |

完整 Python 依赖由上游 `uv.lock`/`pyproject.toml` 定义。构建脚本不修改 PDF 或翻译逻辑，只在打包副本上应用 `patches/local-only-webui.patch`，把 WebUI 限制到 `127.0.0.1` 并禁止公网分享回退。

字体和模型的具体来源、哈希与许可证信息可在 BabelDOC 源码和 [BabelDOC-Assets](https://github.com/funstory-ai/BabelDOC-Assets) 中查阅。
