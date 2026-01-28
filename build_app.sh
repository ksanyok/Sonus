#!/bin/bash

set -euo pipefail

APP_NAME="Sonus"
DIST_DIR="dist"
BUILD_CONFIG="${1:-release}"  # По умолчанию release, но можно передать debug

echo "🚀 Building $BUILD_CONFIG version..."
if [ "$BUILD_CONFIG" = "debug" ]; then
    BIN_DIR="$(swift build --show-bin-path)"
else
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating App Bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "📄 Copying files..."

# Copy Executable
cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/"

# Copy SwiftPM resources bundle (required for runtime assets)
if [ -d "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$RESOURCES_DIR/"
else
    echo "⚠️ Warning: ${APP_NAME}_${APP_NAME}.bundle not found in $BIN_DIR"
fi

# Copy Info.plist
cp "Info.plist" "$CONTENTS_DIR/"

# Fix placeholders in Info.plist
sed -i '' "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" "$CONTENTS_DIR/Info.plist"
sed -i '' "s/\$(PRODUCT_NAME)/$APP_NAME/g" "$CONTENTS_DIR/Info.plist"

# Copy Icon
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    cp "Sources/Resources/AppIcon.icns" "$RESOURCES_DIR/"
else
    echo "⚠️ Warning: AppIcon.icns not found in Sources/Resources/"
fi

# Set PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "🧹 Stripping extended attributes..."
xattr -cr "$APP_BUNDLE" || true

echo "🔏 Signing app (ad-hoc)..."
if [ -f "Sonus.entitlements" ]; then
    codesign --force --deep --sign - --entitlements "Sonus.entitlements" "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "🧪 Verifying signature..."
codesign --verify --deep --strict "$APP_BUNDLE"

echo "📦 Creating ZIP for distribution..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$APP_NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DIST_DIR/$APP_NAME.zip"

echo "✅ Build complete"
echo "📂 App:  $PWD/$APP_BUNDLE"
echo "📦 Zip:  $PWD/$DIST_DIR/$APP_NAME.zip"
echo "👉 Install: drag $APP_NAME.app to /Applications"
