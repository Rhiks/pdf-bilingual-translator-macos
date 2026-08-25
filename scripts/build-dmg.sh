#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_DIR="$ROOT_DIR/upstream/PDFMathTranslate-next"
DIST_DIR="$ROOT_DIR/dist"
VERSION="2.8.2"
DMG_NAME="PDF双语翻译-${VERSION}-arm64.dmg"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    print -u2 "This build currently supports Apple Silicon macOS only."
    exit 1
fi

for command_name in git uv osacompile iconutil sips hdiutil codesign rsync patch; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        print -u2 "Missing required command: $command_name"
        exit 1
    fi
done

git -C "$ROOT_DIR" submodule update --init --recursive
uv python install 3.12
MANAGED_PYTHON="$(uv python find 3.12 --managed-python)"
MANAGED_ROOT="$(realpath "$(dirname "$MANAGED_PYTHON")/..")"

uv sync --no-dev --python "$MANAGED_PYTHON" --project "$UPSTREAM_DIR"
"$UPSTREAM_DIR/.venv/bin/python" -c \
    'from babeldoc.assets.assets import warmup; warmup()'

BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pdf-bilingual-translator.XXXXXX")"
trap 'rm -rf "$BUILD_ROOT"' EXIT

ICONSET="$BUILD_ROOT/AppIcon.iconset"
APP_PATH="$BUILD_ROOT/PDF 双语翻译.app"
STAGING="$BUILD_ROOT/dmg"
mkdir -p "$ICONSET" "$STAGING" "$DIST_DIR"

SOURCE_ICON="$ROOT_DIR/assets/AppIcon.png"
sips -z 16 16 "$SOURCE_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SOURCE_ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$BUILD_ROOT/AppIcon.icns"

osacompile -o "$APP_PATH" "$ROOT_DIR/packaging/launcher.applescript"
PLIST="$APP_PATH/Contents/Info.plist"
cp "$BUILD_ROOT/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/packaging/start-webui.sh" "$APP_PATH/Contents/Resources/start-webui.sh"
chmod 755 "$APP_PATH/Contents/Resources/start-webui.sh"

/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon' "$PLIST"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconName AppIcon' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string local.codex.pdf-bilingual-translator' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string PDF 双语翻译' "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 20802' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 12.0' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :LSApplicationCategoryType string public.app-category.productivity' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$PLIST"

for key_name in NSAppleEventsUsageDescription NSAppleMusicUsageDescription NSCalendarsUsageDescription NSCameraUsageDescription NSContactsUsageDescription NSHomeKitUsageDescription NSMicrophoneUsageDescription NSPhotoLibraryUsageDescription NSRemindersUsageDescription NSSiriUsageDescription NSSystemAdministrationUsageDescription LSRequiresCarbon LSMinimumSystemVersionByArchitecture; do
    /usr/libexec/PlistBuddy -c "Delete :$key_name" "$PLIST" 2>/dev/null || true
done

RESOURCE_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCE_DIR/runtime/src" "$RESOURCE_DIR/runtime/python" "$RESOURCE_DIR/babeldoc-cache"
rsync -a "$UPSTREAM_DIR/.venv/" "$RESOURCE_DIR/runtime/.venv/"
rsync -a "$UPSTREAM_DIR/pdf2zh_next/" "$RESOURCE_DIR/runtime/src/pdf2zh_next/"
rsync -a "$MANAGED_ROOT/" "$RESOURCE_DIR/runtime/python/"
rsync -a "$HOME/.cache/babeldoc/fonts" "$HOME/.cache/babeldoc/cmap" "$HOME/.cache/babeldoc/models" "$HOME/.cache/babeldoc/tiktoken" "$RESOURCE_DIR/babeldoc-cache/"
patch -p1 -d "$RESOURCE_DIR/runtime/src" < "$ROOT_DIR/patches/local-only-webui.patch"

VENV_BIN="$RESOURCE_DIR/runtime/.venv/bin"
unlink "$VENV_BIN/python"
unlink "$VENV_BIN/python3"
unlink "$VENV_BIN/python3.12"
ln -s ../../python/bin/python3.12 "$VENV_BIN/python"
ln -s ../../python/bin/python3.12 "$VENV_BIN/python3"
ln -s ../../python/bin/python3.12 "$VENV_BIN/python3.12"

# Gradio initializes these package-local files on first import. Generate them
# before signing so the installed app bundle remains immutable at runtime.
PYTHONDONTWRITEBYTECODE=1 \
PYTHONPATH="$RESOURCE_DIR/runtime/src:$RESOURCE_DIR/runtime/.venv/lib/python3.12/site-packages" \
    "$RESOURCE_DIR/runtime/python/bin/python3.12" -c \
    'from gradio.utils import get_hash_seed; get_hash_seed(); import gradio_pdf'

plutil -lint "$PLIST"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

/usr/bin/ditto "$APP_PATH" "$STAGING/PDF 双语翻译.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
    -volname 'PDF 双语翻译' \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME"

hdiutil verify "$DIST_DIR/$DMG_NAME"
shasum -a 256 "$DIST_DIR/$DMG_NAME"
print "Built $DIST_DIR/$DMG_NAME"
