#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/CalEvents.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS"

swiftc -O -o "$MACOS/cal-events" "$DIR/cal-events.swift" -framework EventKit -framework AppKit

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
