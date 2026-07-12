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
# Ad-hoc re-sign changes CDHash: Accessibility grant often stops applying to the new binary
# even if the list still shows “Dialog Jumper” ON (one row, but bound to the old build).
if ! codesign --verify --quiet "$APP" 2>/dev/null; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "Note: re-signed ad-hoc (new CDHash). Re-grant Accessibility for this build."
else
  # Binary was copied over a valid seal — must re-sign; expect re-grant.
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "Note: binary updated + ad-hoc signed. If menu is DJ!, re-authorize this build:"
  echo "  Settings list: toggle OFF/ON, or delete the row and Request Accessibility again."
fi
pkill -x DialogJumper 2>/dev/null || true
sleep 0.3
open "$APP"
echo "Launched: $APP"
echo "DJ = ready. DJ! = this process is not trusted (list ON ≠ this build trusted)."
