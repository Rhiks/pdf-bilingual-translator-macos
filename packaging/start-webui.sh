#!/bin/zsh

set -u

RESOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$RESOURCE_DIR/runtime"
PYTHON_BIN="$RUNTIME_DIR/python/bin/python3.12"
APP_SUPPORT_DIR="$HOME/Library/Application Support/PDF Bilingual Translator"
WORK_DIR="$APP_SUPPORT_DIR/workspace"
LOG_DIR="$HOME/Library/Logs/PDF Bilingual Translator"
PID_FILE="$APP_SUPPORT_DIR/server.pid"
PORT_FILE="$APP_SUPPORT_DIR/server.port"
LOG_FILE="$LOG_DIR/webui.log"
DEFAULT_PORT=7860

mkdir -p "$WORK_DIR/pdf2zh_files" "$LOG_DIR" "$HOME/.cache/babeldoc"

if [[ ! -f "$HOME/.cache/babeldoc/models/doclayout_yolo_docstructbench_imgsz1024.onnx" ]]; then
    /usr/bin/ditto "$RESOURCE_DIR/babeldoc-cache" "$HOME/.cache/babeldoc"
fi

open_ui() {
    /usr/bin/open "http://127.0.0.1:$1/"
}

if [[ -f "$PID_FILE" && -f "$PORT_FILE" ]]; then
    existing_pid="$(<"$PID_FILE")"
    existing_port="$(<"$PORT_FILE")"
    if /bin/kill -0 "$existing_pid" 2>/dev/null && /usr/bin/curl -fsS --max-time 2 "http://127.0.0.1:$existing_port/" >/dev/null 2>&1; then
        open_ui "$existing_port"
        exit 0
    fi
fi

server_port="$DEFAULT_PORT"
while /usr/bin/nc -z 127.0.0.1 "$server_port" >/dev/null 2>&1; do
    server_port=$((server_port + 1))
done

export PYTHONPATH="$RUNTIME_DIR/src:$RUNTIME_DIR/.venv/lib/python3.12/site-packages"
export PYTHONDONTWRITEBYTECODE=1
export PDF2ZH_LANG_FROM="English"
export PDF2ZH_LANG_TO="Simplified Chinese"

deepseek_api_key="$(/usr/bin/security find-generic-password \
    -a "$USER" \
    -s 'local.codex.pdf-bilingual-translator.deepseek' \
    -w 2>/dev/null || true)"
if [[ -n "$deepseek_api_key" ]]; then
    export PDF2ZH_DEEPSEEK=true
    export PDF2ZH_DEEPSEEK_API_KEY="$deepseek_api_key"
    export PDF2ZH_DEEPSEEK_MODEL="deepseek-v4-flash"
fi
unset deepseek_api_key

cd "$WORK_DIR" || exit 1

nohup "$PYTHON_BIN" -m pdf2zh_next.main \
    --gui \
    --server-port "$server_port" \
    --ui-lang zh \
    --disable-config-auto-save \
    >>"$LOG_FILE" 2>&1 &

server_pid=$!
print -r -- "$server_pid" >"$PID_FILE"
print -r -- "$server_port" >"$PORT_FILE"

for _ in {1..180}; do
    if ! /bin/kill -0 "$server_pid" 2>/dev/null; then
        break
    fi
    if /usr/bin/curl -fsS --max-time 2 "http://127.0.0.1:$server_port/" >/dev/null 2>&1; then
        open_ui "$server_port"
        exit 0
    fi
    /bin/sleep 0.5
done

/usr/bin/osascript -e 'display alert "PDF 双语翻译未能启动" message "请查看日志：~/Library/Logs/PDF Bilingual Translator/webui.log" as critical'
exit 1
