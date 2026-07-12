#!/usr/bin/env bash
# Build and launch the stable-path dev .app (for Accessibility + menu bar).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build
BIN="$ROOT/.build/arm64-apple-macosx/debug/DialogJumper"
APP="$ROOT/dist/DialogJumper.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/DialogJumper"
if [[ ! -f "$APP/Contents/Info.plist" ]]; then
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>DialogJumper</string>
  <key>CFBundleIdentifier</key>
  <string>me.dialogjumper.dev</string>
  <key>CFBundleName</key>
  <string>DialogJumper</string>
  <key>CFBundleDisplayName</key>
  <string>Dialog Jumper</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST
fi
chmod +x "$APP/Contents/MacOS/DialogJumper"
# Replacing the binary invalidates the seal; re-sign only when needed.
# Ad-hoc re-sign changes CDHash and often drops Accessibility grants — avoid --force every run.
if ! codesign --verify --quiet "$APP" 2>/dev/null; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "Note: re-signed ad-hoc. You may need to re-enable Accessibility for Dialog Jumper."
fi
pkill -x DialogJumper 2>/dev/null || true
sleep 0.3
open "$APP"
echo "Launched: $APP"
echo "Menu DJ = ready, DJ! = need Accessibility. After enabling, fully Quit and reopen (no rebuild)."
