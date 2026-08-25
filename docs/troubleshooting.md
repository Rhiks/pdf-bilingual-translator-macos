# 故障排查

## 应用没有打开浏览器

查看服务端口：

```bash
cat "$HOME/Library/Application Support/PDF Bilingual Translator/server.port"
```

假设输出为 `7861`，手动打开 `http://127.0.0.1:7861/`。如果端口文件不存在，查看日志：

```bash
tail -n 100 "$HOME/Library/Logs/PDF Bilingual Translator/webui.log"
```

## macOS 提示无法验证开发者

Release 当前使用 ad-hoc 签名，没有 Apple notarization。确认下载来源和 Release SHA-256 后，在 Finder 中右键应用并选择“打开”。不要全局关闭 Gatekeeper。

## DeepSeek 没有被自动选择

确认钥匙串条目存在，但不要输出 Key 内容：

```bash
security find-generic-password \
  -a "$USER" \
  -s "local.codex.pdf-bilingual-translator.deepseek" >/dev/null \
  && echo "Key exists"
```

删除并重新写入钥匙串后，退出旧服务并重新打开应用。

## 端口被占用

启动器会从 `7860` 开始自动选择空闲端口。实际端口保存在 `server.port`。不要为了使用固定端口而结束不认识的系统进程。

## 翻译很慢

- 首先试译 1–3 页。
- 在线模型的速度受服务商排队、QPS 和网络影响。
- 本机 Ollama 受模型大小、内存和芯片性能影响。
- 扫描 PDF、复杂表格和大量公式会增加布局处理时间。

## 输出错位或缺字

先尝试兼容模式、OCR workaround 或不同输出模式。如果问题能在不含敏感信息的最小 PDF 上复现，再向 BabelDOC/PDFMathTranslate 上游提交 Issue。

翻译中间文件和结果写入 `~/Library/Application Support/PDF Bilingual Translator/workspace/pdf2zh_files/`。应用包本身保持只读，启动后不会改写已签名内容。

## 完全停止服务

读取 PID 并仅结束该应用记录的进程：

```bash
PID_FILE="$HOME/Library/Application Support/PDF Bilingual Translator/server.pid"
kill "$(cat "$PID_FILE")"
```
