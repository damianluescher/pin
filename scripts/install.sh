#!/bin/zsh
# Builds Pin, installs /Applications/Pin.app and the agents' `pin` command.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Pin
swift build -c release --product pincli
bin=$(swift build -c release --show-bin-path)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
app="$work/Pin.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$work/Pin.iconset"
cp "$bin/Pin" "$app/Contents/MacOS/Pin"
swift scripts/icon.swift "$work/Pin.iconset"
iconutil -c icns "$work/Pin.iconset" -o "$app/Contents/Resources/Pin.icns"
cat > "$app/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Pin</string><key>CFBundleDisplayName</key><string>Pin</string>
<key>CFBundleIdentifier</key><string>ch.yoveo.pin</string><key>CFBundleExecutable</key><string>Pin</string>
<key>CFBundleIconFile</key><string>Pin</string><key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string><key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/>
</dict></plist>
P
codesign --force --deep --sign - "$app"
pkill -x Pin 2>/dev/null || true
if [ -d /Applications/Pin.app ]; then mv /Applications/Pin.app "$work/old.app"; fi
mv "$app" /Applications/Pin.app
mkdir -p ~/.local/bin ~/tools/pin/.bin
cp "$bin/pincli" ~/tools/pin/.bin/pin
ln -sf ~/tools/pin/.bin/pin ~/.local/bin/pin
echo installed
