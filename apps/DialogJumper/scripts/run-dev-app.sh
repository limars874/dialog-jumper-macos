#!/usr/bin/env bash
# Build + sign with dedicated keychain (no hardened runtime) + single instance launch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIGN_DIR="${DIALOGJUMPER_SIGN_DIR:-$HOME/.dialog-jumper-dev-signing}"
CN="${DIALOGJUMPER_SIGN_IDENTITY:-DialogJumper Dev}"
KC="$SIGN_DIR/dialogjumper-dev.keychain-db"
KC_PASS="${DIALOGJUMPER_KEYCHAIN_PASS:-dialogjumper-dev-local}"
P12_PASS="${DIALOGJUMPER_P12_PASS:-dialogjumper-dev}"

ensure_dedicated_keychain() {
  mkdir -p "$SIGN_DIR"
  if [[ ! -f "$SIGN_DIR/dev.p12" ]]; then
    echo "Missing $SIGN_DIR/dev.p12 — run: apps/DialogJumper/scripts/setup-dev-signing.sh" >&2
    exit 1
  fi
  if [[ ! -f "$KC" ]]; then
    security create-keychain -p "$KC_PASS" "$KC"
    security set-keychain-settings -lut 21600 "$KC"
    security unlock-keychain -p "$KC_PASS" "$KC"
    security import "$SIGN_DIR/dev.p12" -k "$KC" -P "$P12_PASS" \
      -T /usr/bin/codesign -T /usr/bin/security
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC" 2>/dev/null || true
  fi
  security unlock-keychain -p "$KC_PASS" "$KC" >/dev/null
}

sign_app() {
  local app="$1"
  local old_search
  old_search=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
  security list-keychains -d user -s "$KC" $old_search
  security unlock-keychain -p "$KC_PASS" "$KC" >/dev/null

  # No --options runtime: Hardened Runtime breaks AX without full entitlements.
  set +e
  codesign --force --deep --sign "$CN" --keychain "$KC" "$app" 2>/tmp/dj-codesign.err
  local ec=$?
  set -e

  security list-keychains -d user -s $old_search

  if [[ $ec -ne 0 ]]; then
    echo "codesign failed:" >&2
    cat /tmp/dj-codesign.err >&2 || true
    exit "$ec"
  fi
  codesign --verify --verbose=2 "$app" >/dev/null
  codesign -dv --verbose=4 "$app" 2>&1 | grep -E 'Authority|Identifier|flags=' || true
}

pkill -x DialogJumper 2>/dev/null || true
sleep 0.3

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

ensure_dedicated_keychain
sign_app "$APP"

# Ensure only one instance
pkill -x DialogJumper 2>/dev/null || true
sleep 0.3
open "$APP"
sleep 0.8
COUNT=$(pgrep -x DialogJumper | wc -l | tr -d ' ')
echo "Launched: $APP (instances=$COUNT)"
echo "Expect: one DJ in menu bar. Open TextEdit → ⌘O → DJ● + side Path toolbar."
