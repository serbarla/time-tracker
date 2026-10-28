#!/usr/bin/env bash
# Assembles and ad-hoc signs a menubar .app bundle from the SPM release build.
# Launch-at-login (SMAppService) requires a real bundle with a bundle id + signature.
set -euo pipefail

APP_NAME="TimeTracker"
BUNDLE_ID="com.sergiobarba.timetracker"
VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
if [[ -z "$VERSION" ]]; then
  VERSION="1.0.0"
  echo "warning: no git tag; version defaults to 1.0.0" >&2
fi
BUILD="$(git rev-list --count HEAD)"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"
ICON_MASTER="Assets/app-icon-1024.png"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/${APP_NAME}" "$APP_DIR/Contents/MacOS/${APP_NAME}"

# SPM resource bundle (Localization.json); Bundle.module looks in Contents/Resources.
cp -R "$BUILD_DIR/${APP_NAME}_TimeTrackerApp.bundle" "$APP_DIR/Contents/Resources/"
codesign --force --sign - "$APP_DIR/Contents/Resources/${APP_NAME}_TimeTrackerApp.bundle"

# App icon: downsize the 1024 master into iconutil's canonical iconset, then .icns.
[[ -f "$ICON_MASTER" ]] || { echo "missing $ICON_MASTER" >&2; exit 1; }
rm -rf dist/AppIcon.iconset
mkdir -p dist/AppIcon.iconset
for spec in \
  "16 16 icon_16x16.png" "32 32 diana.v@example.org" \
  "32 32 icon_32x32.png" "64 64 ivan.p@example.net" \
  "128 128 icon_128x128.png" "256 256 wendy.h@example.org" \
  "256 256 icon_256x256.png" "512 512 wendy.h@example.net" \
  "512 512 icon_512x512.png" "1024 1024 william.b@example.com"; do
  set -- $spec
  sips -z "$1" "$2" "$ICON_MASTER" --out "dist/AppIcon.iconset/.tmp.png" >/dev/null
  mv "dist/AppIcon.iconset/.tmp.png" "dist/AppIcon.iconset/$3"
done
iconutil -c icns dist/AppIcon.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>${APP_NAME}</string>
	<key>CFBundleDisplayName</key><string>${APP_NAME}</string>
	<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
	<key>CFBundleExecutable</key><string>${APP_NAME}</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleShortVersionString</key><string>${VERSION}</string>
	<key>CFBundleVersion</key><string>${BUILD}</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Sergio Barba. MIT License.</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP_DIR"

# DMG for direct download: app + Applications symlink + install instructions.
rm -rf dist/dmg-staging
mkdir -p dist/dmg-staging
cp -R "$APP_DIR" dist/dmg-staging/
ln -s /Applications dist/dmg-staging/Applications
cat > dist/dmg-staging/Install.txt <<'INSTALL'
TimeTracker — install
=====================

1. Drag TimeTracker.app into the Applications folder.
2. Eject the disk image, then open TimeTracker from Applications.

First launch (unsigned build)
-----------------------------
This build is not notarized, so macOS blocks the first launch:

  - Open TimeTracker once (double-click). macOS shows a "Not Opened" dialog
    ("Apple could not verify…") — click "Done", NOT "Move to Trash".
  - Open System Settings -> Privacy & Security, scroll down to the Security
    section, and click "Open Anyway" next to the message about TimeTracker.
  - In the "Open TimeTracker.app?" dialog that follows, click "Open Anyway"
    again. The app starts and its clock appears in the menu bar.

Terminal alternative:
  xattr -d com.apple.quarantine /Applications/TimeTracker.app

Requirements: macOS 26 or newer.

Your data
---------
Checks are stored in ~/Library/Application Support/TimeTracker/checks.json.
Nothing leaves your Mac.

Uninstall
---------
In the app: Settings -> turn off "Launch at login", then quit.
Then delete /Applications/TimeTracker.app and
~/Library/Application Support/TimeTracker.
INSTALL
hdiutil create -volname TimeTracker -srcfolder dist/dmg-staging -ov -format UDZO "dist/TimeTracker-${VERSION}.dmg"

echo "Built and signed $APP_DIR"
echo "Built dist/TimeTracker-${VERSION}.dmg"
