#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/Runx Calendar Plugin Helper.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS"

swiftc -O -target arm64-apple-macosx11.0 -o "$MACOS/cal-events-arm64" "$DIR/cal-events.swift" -framework EventKit -framework AppKit
swiftc -O -target x86_64-apple-macosx11.0 -o "$MACOS/cal-events-x86_64" "$DIR/cal-events.swift" -framework EventKit -framework AppKit
lipo -create "$MACOS/cal-events-arm64" "$MACOS/cal-events-x86_64" -output "$MACOS/cal-events"
rm "$MACOS/cal-events-arm64" "$MACOS/cal-events-x86_64"

cat > "$CONTENTS/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>io.github.sloppish.runx.cal-events</string>
  <key>CFBundleExecutable</key>
  <string>cal-events</string>
  <key>CFBundleName</key>
  <string>Runx Calendar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>Runx needs access to your calendars to show upcoming events.</string>
</dict>
</plist>
EOF

codesign -fs - "$APP"
echo "Built $APP"
