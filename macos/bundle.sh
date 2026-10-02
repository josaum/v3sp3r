#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# SINGLE SOURCE OF TRUTH for the product name (macOS).
# Also the source of record for the in-app name via AppInfo.productName
# in Sources/VesperMac/AppInfo.swift. Change both together.
APP_NAME="ferriteSuite"
BUNDLE_DIR="$DIR/build/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building $APP_NAME for macOS (Release)..."
cd "$DIR"
swift build -c release

echo "📦 Creating macOS App Bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$DIR/.build/release/VesperMac" "$MACOS_DIR/VesperMac"
chmod +x "$MACOS_DIR/VesperMac"

# Generate Info.plist
# Unquoted heredoc: $APP_NAME must interpolate so the display name has ONE source
# of truth. CFBundleExecutable stays VesperMac — it must match the SwiftPM product.
cat << EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VesperMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.vesper.flipper.mac</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>$APP_NAME connects to your Flipper Zero wirelessly over Bluetooth Low Energy.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>$APP_NAME connects to your Flipper Zero wirelessly over Bluetooth Low Energy.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>$APP_NAME uses your microphone for natural language voice commands.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>$APP_NAME uses speech recognition to parse natural language voice prompts.</string>
</dict>
</plist>
EOF

# Ad-hoc sign bundle for macOS Gatekeeper and LaunchServices
echo "🔏 Signing App Bundle..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ $APP_NAME bundle created successfully at: $BUNDLE_DIR"
echo "You can launch it via: open '$BUNDLE_DIR'"
