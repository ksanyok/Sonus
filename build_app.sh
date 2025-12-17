#!/bin/bash

APP_NAME="Sonus"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 Building Release version..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📦 Creating App Bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📄 Copying files..."
# Copy Executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist
cp "Info.plist" "$CONTENTS_DIR/"

# Fix placeholders in Info.plist
sed -i '' 's/\$(EXECUTABLE_NAME)/Sonus/g' "$CONTENTS_DIR/Info.plist"
sed -i '' 's/\$(PRODUCT_NAME)/Sonus/g' "$CONTENTS_DIR/Info.plist"

# Copy Icon
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    cp "Sources/Resources/AppIcon.icns" "$RESOURCES_DIR/"
else 
    echo "⚠️ Warning: AppIcon.icns not found in Sources/Resources/"
fi

# Set PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Ad-hoc signing (Required for Apple Silicon & recent macOS)
echo "🔏 Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ $APP_NAME.app created successfully!"
echo "📂 Location: $PWD/$APP_BUNDLE"
echo "👉 You can now drag this to your Applications folder or run it directly."
