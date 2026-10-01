#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="Vesper"
BUNDLE_DIR="$DIR/build/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building Vesper for macOS (Release)..."
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
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VesperMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.vesper.flipper.mac</string>
    <key>CFBundleName</key>
    <string>Vesper</string>
    <key>CFBundleDisplayName</key>
    <string>V3SP3R</string>
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
    <string>Vesper connects to your Flipper Zero wirelessly over Bluetooth Low Energy.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Vesper connects to your Flipper Zero wirelessly over Bluetooth Low Energy.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Vesper uses your microphone for natural language voice commands.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Vesper uses speech recognition to parse natural language voice prompts.</string>
</dict>
</plist>
EOF

# Ad-hoc sign bundle for macOS Gatekeeper and LaunchServices
echo "🔏 Signing App Bundle..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ App bundle created successfully at: $BUNDLE_DIR"
echo "You can launch it via: open '$BUNDLE_DIR'"
