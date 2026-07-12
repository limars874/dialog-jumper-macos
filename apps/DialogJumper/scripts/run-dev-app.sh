#!/usr/bin/env bash
# Build + sign with project-dedicated keychain only (not login keychain) + launch.
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
  if [[ ! -f "$SIGN_DIR/dev.p12" || ! -f "$SIGN_DIR/dev.crt" ]]; then
    echo "Missing signing materials. Run: apps/DialogJumper/scripts/setup-dev-signing.sh" >&2
    exit 1
  fi
  if [[ ! -f "$KC" ]]; then
    security create-keychain -p "$KC_PASS" "$KC"
    security set-keychain-settings -lut 21600 "$KC"
    security unlock-keychain -p "$KC_PASS" "$KC"
    # Import ONLY into dedicated keychain — never login.keychain
    security import "$SIGN_DIR/dev.p12" -k "$KC" -P "$P12_PASS" \
      -T /usr/bin/codesign -T /usr/bin/security
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC" 2>/dev/null || true
  fi
  security unlock-keychain -p "$KC_PASS" "$KC"
}

sign_app() {
  local app="$1"
  local old_search
  old_search=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
  # codesign resolves identities via search list; put dedicated KC first, then restore.
  security list-keychains -d user -s "$KC" $old_search
  security unlock-keychain -p "$KC_PASS" "$KC"
  set +e
  codesign --force --deep --options runtime --sign "$CN" --keychain "$KC" "$app"
  local ec=$?
  set -e
  security list-keychains -d user -s $old_search
  if [[ $ec -ne 0 ]]; then
    echo "codesign failed ($ec). If CSSMERR_TP_NOT_TRUSTED: Keychain Access → $CN → Trust → Code Signing → Always Trust" >&2
    exit $ec
  fi
  codesign --verify --verbose=2 "$app" >/dev/null
  codesign -dv --verbose=4 "$app" 2>&1 | grep -E 'Authority|Identifier' || true
}

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

pkill -x DialogJumper 2>/dev/null || true
sleep 0.3
open "$APP"
echo "Launched: $APP"
echo "Signed with dedicated keychain: $KC"
echo "If you still see login-keychain password prompts, Deny — identity should not live in login."
