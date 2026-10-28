#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app='dist/Codex Mac GUI Unlock.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
rm -f "$app/Contents/project-marker"
cp .build/release/GUIUnlock "$app/Contents/MacOS/GUIUnlock"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.codexcommunity.MacGUIUnlock</string>
<key>CFBundleName</key><string>Codex Mac GUI Unlock</string>
<key>CFBundleExecutable</key><string>GUIUnlock</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
printf '%s\n' 'org.codexcommunity.MacGUIUnlock' > "$app/Contents/Resources/project-marker"
codesign --force --sign - --identifier org.codexcommunity.MacGUIUnlock "$app"
codesign --verify --deep --strict "$app"
