#!/usr/bin/env bash
# One-time: self-signed codesign cert + dedicated keychain file (NOT login keychain).
set -euo pipefail

SIGN_DIR="${DIALOGJUMPER_SIGN_DIR:-$HOME/.dialog-jumper-dev-signing}"
CN="${DIALOGJUMPER_SIGN_IDENTITY:-DialogJumper Dev}"
KC="$SIGN_DIR/dialogjumper-dev.keychain-db"
KC_PASS="${DIALOGJUMPER_KEYCHAIN_PASS:-dialogjumper-dev-local}"
P12_PASS="${DIALOGJUMPER_P12_PASS:-dialogjumper-dev}"

mkdir -p "$SIGN_DIR"
chmod 700 "$SIGN_DIR"

if [[ ! -f "$SIGN_DIR/dev.p12" ]]; then
  openssl req -x509 -newkey rsa:2048 -days 3650 \
    -keyout "$SIGN_DIR/dev.key" -out "$SIGN_DIR/dev.crt" -nodes \
    -subj "/CN=${CN}/O=DialogJumper/C=US" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"
  openssl pkcs12 -export -legacy \
    -in "$SIGN_DIR/dev.crt" -inkey "$SIGN_DIR/dev.key" \
    -out "$SIGN_DIR/dev.p12" -password "pass:${P12_PASS}" \
    -name "$CN"
  chmod 600 "$SIGN_DIR"/dev.key "$SIGN_DIR"/dev.crt "$SIGN_DIR"/dev.p12
  echo "Created $SIGN_DIR/dev.p12"
fi

if [[ -f "$KC" ]]; then
  security delete-keychain "$KC" 2>/dev/null || true
fi
security create-keychain -p "$KC_PASS" "$KC"
security set-keychain-settings -lut 21600 "$KC"
security unlock-keychain -p "$KC_PASS" "$KC"
# ONLY dedicated keychain — do not import into login.keychain-db
security import "$SIGN_DIR/dev.p12" -k "$KC" -P "$P12_PASS" \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC" 2>/dev/null || true

echo "Dedicated keychain ready: $KC"
security find-identity -v -p codesigning "$KC"
echo
echo "Optional cleanup if an older import polluted login keychain:"
echo "  security delete-identity -c \"$CN\" ~/Library/Keychains/login.keychain-db"
echo
echo "Then: apps/DialogJumper/scripts/run-dev-app.sh"
