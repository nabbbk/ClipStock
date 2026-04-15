#!/bin/bash
#
# Signs a DMG with Sparkle's sign_update tool and appends a new <item>
# to docs/appcast.xml.
#
# Usage:
#   ./scripts/sign_and_update_appcast.sh <dmg-path> <version> <download-url>
#
# Example:
#   ./scripts/sign_and_update_appcast.sh build/ClipStock.dmg 1.4.0 \
#     https://github.com/nabbbk/ClipStock/releases/download/v1.4.0/ClipStock.dmg
#
# Prerequisites:
#   - Sparkle's sign_update must be in PATH or in the DerivedData Sparkle build.
#     Typically at: DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
#   - EdDSA keys must already be generated (run: sign_update --generate)

set -euo pipefail

DMG_PATH="${1:?Usage: $0 <dmg-path> <version> <download-url>}"
VERSION="${2:?Usage: $0 <dmg-path> <version> <download-url>}"
DOWNLOAD_URL="${3:?Usage: $0 <dmg-path> <version> <download-url>}"

APPCAST="$(dirname "$0")/../docs/appcast.xml"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

if [ ! -f "$APPCAST" ]; then
    echo "Error: appcast.xml not found at $APPCAST"
    exit 1
fi

# Try to find sign_update
SIGN_UPDATE=""
if command -v sign_update &>/dev/null; then
    SIGN_UPDATE="sign_update"
else
    # Search in Xcode DerivedData
    FOUND=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -path "*/Sparkle/bin/*" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        SIGN_UPDATE="$FOUND"
    fi
fi

if [ -z "$SIGN_UPDATE" ]; then
    echo "Error: sign_update not found. Build the project first, then retry."
    echo "Or run: find ~/Library/Developer/Xcode/DerivedData -name sign_update"
    exit 1
fi

echo "Signing $DMG_PATH ..."
SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH")

# sign_update outputs: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$ED_SIGNATURE" ] || [ -z "$LENGTH" ]; then
    echo "Error: Could not parse sign_update output:"
    echo "$SIGN_OUTPUT"
    exit 1
fi

PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S %z")

NEW_ITEM="    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url=\"${DOWNLOAD_URL}\"
        type=\"application/octet-stream\"
        sparkle:edSignature=\"${ED_SIGNATURE}\"
        length=\"${LENGTH}\"
      />
    </item>"

# Insert the new item before the closing </channel> tag
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|  </channel>|${NEW_ITEM}\n\n  </channel>|" "$APPCAST"
else
    sed -i "s|  </channel>|${NEW_ITEM}\n\n  </channel>|" "$APPCAST"
fi

echo ""
echo "Done! Appcast updated:"
echo "  Version:   $VERSION"
echo "  Signature: ${ED_SIGNATURE:0:20}..."
echo "  Size:      $LENGTH bytes"
echo ""
echo "Next steps:"
echo "  1. git add docs/appcast.xml && git commit -m 'Update appcast for v${VERSION}'"
echo "  2. git push"
echo "  3. Upload ${DMG_PATH} to GitHub Releases as v${VERSION}"
