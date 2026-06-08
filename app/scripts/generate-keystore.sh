#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$SCRIPT_DIR/../android"
KEYSTORE_DIR="$ANDROID_DIR/keystore"
KEYSTORE_FILE="$KEYSTORE_DIR/kharis-release.jks"
KEY_PROPERTIES="$ANDROID_DIR/key.properties"
GITIGNORE="$ANDROID_DIR/.gitignore"

echo "=== Kharis Android Keystore Generator ==="
echo ""

# Create keystore directory
mkdir -p "$KEYSTORE_DIR"

if [[ -f "$KEYSTORE_FILE" ]]; then
  echo "WARNING: Keystore already exists at $KEYSTORE_FILE"
  read -r -p "Overwrite? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo "Generating keystore for Kharis Ministries..."
echo "You will be prompted for passwords and organization details."
echo ""

keytool -genkey -v \
  -keystore "$KEYSTORE_FILE" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias kharis-release \
  -dname "CN=Kharis Ministries, OU=Mobile, O=Kharis Ministries, L=Unknown, ST=Unknown, C=US"

echo ""
echo "Keystore created at: $KEYSTORE_FILE"
echo ""

# Prompt for passwords to write key.properties
read -r -s -p "Enter keystore (store) password: " STORE_PASS
echo ""
read -r -s -p "Enter key password (same or different): " KEY_PASS
echo ""

# Write key.properties
cat > "$KEY_PROPERTIES" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=kharis-release
storeFile=../keystore/kharis-release.jks
EOF

echo "key.properties written to: $KEY_PROPERTIES"

# Ensure .gitignore entries exist (android/.gitignore already has them by default,
# but guard in case this is a fresh or modified project)
add_gitignore_entry() {
  local entry="$1"
  if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
    echo "$entry" >> "$GITIGNORE"
    echo "Added '$entry' to $GITIGNORE"
  fi
}

add_gitignore_entry "key.properties"
add_gitignore_entry "**/*.jks"
add_gitignore_entry "keystore/"

echo ""
echo "=== Next Steps ==="
echo "1. NEVER commit key.properties or the .jks file — they are already in .gitignore"
echo "2. Store the keystore password and key password somewhere secure (1Password, etc.)"
echo "3. Back up $KEYSTORE_FILE — if lost, you cannot update the app on Play Store"
echo "4. Run scripts/build-android.sh to build a signed release bundle"
echo "5. Upload the .aab file to Google Play Console"
