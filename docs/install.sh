#!/bin/bash
set -euo pipefail

APP_NAME="ClipStock"
REPO="nabbbk/ClipStock"
INSTALL_DIR="/Applications"

echo "==> Fetching latest $APP_NAME release..."
DMG_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"browser_download_url"' \
    | grep '\.dmg"' \
    | cut -d'"' -f4)

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG in latest release."
    exit 1
fi

TMP_DMG=$(mktemp /tmp/ClipStock-XXXXXX.dmg)
trap 'rm -f "$TMP_DMG"' EXIT

echo "==> Downloading $(basename "$DMG_URL")..."
curl -fsSL --progress-bar "$DMG_URL" -o "$TMP_DMG"

echo "==> Mounting DMG..."
MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -noautoopen | awk 'END{print $NF}')

cleanup_mount() { hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true; }
trap 'cleanup_mount; rm -f "$TMP_DMG"' EXIT

echo "==> Installing to $INSTALL_DIR..."
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "==> Stopping running $APP_NAME..."
    pkill -x "$APP_NAME" || true
    sleep 1
fi
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

echo "==> Removing quarantine flag..."
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "$APP_NAME installed successfully!"
echo "Launch it from Applications or Spotlight (Cmd+Space → $APP_NAME)."
