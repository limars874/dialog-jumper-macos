#!/usr/bin/env bash
# Build release DialogJumper.app + zip for GitHub Releases (ad-hoc sign, no Developer ID).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${DIALOGJUMPER_VERSION:-}"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
if [[ -z "$VERSION" ]]; then
  if VERSION="$(git -C "$REPO_ROOT" describe --tags --exact-match 2>/dev/null)"; then
    :
  elif VERSION="$(git -C "$REPO_ROOT" describe --tags --always 2>/dev/null)"; then
    :
  else
    VERSION="0.1.0-dev"
  fi
fi
SAFE_VERSION="${VERSION#v}"
echo "==> swift test"
swift test

echo "==> swift build -c release"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/DialogJumper"
if [[ ! -x "$BIN" ]]; then
  echo "error: release binary not found at $BIN" >&2
  exit 1
fi

APP="$ROOT/dist/DialogJumper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/DialogJumper"
chmod +x "$APP/Contents/MacOS/DialogJumper"

cat > "$APP/Contents/Info.plist" <<PLIST
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
  <key>CFBundleShortVersionString</key>
  <string>${SAFE_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${SAFE_VERSION}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Dialog Jumper reads open Finder windows so you can jump to those folders in File Dialogs.</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
PLIST

# Ad-hoc sign — no Developer ID / no hardened runtime (AX needs to work).
echo "==> codesign (ad-hoc, no hardened runtime)"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP" || true

ARCH="$(uname -m)"
ZIP_NAME="DialogJumper-${SAFE_VERSION}-macos-${ARCH}.zip"
ZIP_PATH="$ROOT/dist/$ZIP_NAME"
rm -f "$ZIP_PATH"
(
  cd "$ROOT/dist"
  ditto -c -k --keepParent "DialogJumper.app" "$ZIP_NAME"
)

echo "==> packaged $ZIP_PATH"
ls -lh "$ZIP_PATH"
echo "$ZIP_PATH" > "$ROOT/dist/latest-zip-path.txt"
