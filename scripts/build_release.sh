#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="ClipStock"
APP_NAME="ClipStock"

echo "=== Building $APP_NAME (Release) ==="

# Clean and build Release
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    2>&1 | tail -5

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed — $APP_PATH not found"
    exit 1
fi

echo "=== Build succeeded ==="

# Create DMG
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING"

echo ""
echo "=== Done ==="
echo "App:  $APP_PATH"
echo "DMG:  $DMG_PATH"
echo ""
echo "To verify it's a Release build:"
echo "  file $APP_PATH/Contents/MacOS/$APP_NAME"
