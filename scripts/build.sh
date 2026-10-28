#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app='dist/Codex Mac GUI Unlock.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
rm -f "$app/Contents/project-marker"
cp .build/release/GUIUnlock "$app/Contents/MacOS/GUIUnlock"
iconset='.build/AppIcon.iconset'
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" assets/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" assets/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.codexcommunity.MacGUIUnlock</string>
<key>CFBundleName</key><string>Codex Mac GUI Unlock</string>
<key>CFBundleExecutable</key><string>GUIUnlock</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
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
