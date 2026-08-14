#!/bin/bash
set -euo pipefail

# ==============================================================================
# Joule Release Build Script
# Builds Mac Catalyst (.app, .zip, .dmg) and iOS (.ipa) for GitHub Releases
# ==============================================================================

PROJECT_NAME="Joule"
SCHEME="Joule"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build"

VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "1.0.0")

echo "🚀 Building ${PROJECT_NAME} (Version: ${VERSION})"
echo "📁 Output directory: ${DIST_DIR}"

# Clean previous build artifacts
rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${BUILD_DIR}"

cd "${ROOT_DIR}"

# Ensure project is generated if project.yml exists and xcodegen is installed
if command -v xcodegen &> /dev/null && [ -f "project.yml" ]; then
    echo "⚙️  Regenerating Xcode project with xcodegen..."
    xcodegen generate --quiet
fi

# ==============================================================================
# 1. Build macOS (Mac Catalyst) App & Zip / DMG
# ==============================================================================
echo ""
echo "🖥️  [1/2] Building macOS (Mac Catalyst) Application..."

xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    | xcbeautify 2>/dev/null || true

MAC_APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release-maccatalyst/${PROJECT_NAME}.app"

if [ -d "${MAC_APP_PATH}" ]; then
    echo "📦 Packaging macOS App into ZIP..."
    MAC_ZIP="${DIST_DIR}/${PROJECT_NAME}-macOS-${VERSION}.zip"
    ditto -c -k --sequesterRsrc --keepParent "${MAC_APP_PATH}" "${MAC_ZIP}"
    echo "✅ Created: ${MAC_ZIP}"

    # If hdiutil is available, create a .dmg
    if command -v hdiutil &> /dev/null; then
        echo "💿 Packaging macOS DMG..."
        DMG_TEMP="${BUILD_DIR}/dmg_temp"
        mkdir -p "${DMG_TEMP}"
        cp -R "${MAC_APP_PATH}" "${DMG_TEMP}/"
        ln -s /Applications "${DMG_TEMP}/Applications"
        
        MAC_DMG="${DIST_DIR}/${PROJECT_NAME}-macOS-${VERSION}.dmg"
        hdiutil create -volname "${PROJECT_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${MAC_DMG}" -quiet
        rm -rf "${DMG_TEMP}"
        echo "✅ Created: ${MAC_DMG}"
    fi
else
    echo "⚠️  Could not find built macOS app at ${MAC_APP_PATH}"
fi

# ==============================================================================
# 2. Build iOS Archive & Package IPA
# ==============================================================================
echo ""
echo "📱 [2/2] Building iOS (.ipa) for Sideloading..."

IOS_ARCHIVE="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"

xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "${IOS_ARCHIVE}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    | xcbeautify 2>/dev/null || true

IOS_APP_PATH="${IOS_ARCHIVE}/Products/Applications/${PROJECT_NAME}.app"

if [ -d "${IOS_APP_PATH}" ]; then
    echo "📦 Packaging iOS App into IPA..."
    PAYLOAD_DIR="${BUILD_DIR}/Payload"
    mkdir -p "${PAYLOAD_DIR}"
    cp -R "${IOS_APP_PATH}" "${PAYLOAD_DIR}/"
    
    IOS_IPA="${DIST_DIR}/${PROJECT_NAME}-iOS-${VERSION}.ipa"
    (cd "${BUILD_DIR}" && zip -qr "${IOS_IPA}" "Payload")
    rm -rf "${PAYLOAD_DIR}"
    echo "✅ Created: ${IOS_IPA}"
else
    echo "⚠️  Could not find built iOS app in archive at ${IOS_APP_PATH}"
fi

echo ""
echo "🎉 Build complete! Release artifacts located in:"
ls -lh "${DIST_DIR}"
