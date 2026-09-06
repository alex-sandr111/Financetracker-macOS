#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT_DIR/FinanceTracker.xcodeproj"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="FinanceTracker"
APP_PATH="$BUILD_DIR/Release/$APP_NAME.app"
DIST_APP="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
SOURCE_ICON="$ROOT_DIR/FinanceTracker/AppIcon.icns"

printf '▶︎ Cleaning previous build...\n'
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

printf '▶︎ Building Release app for Apple Silicon...\n'
xcodebuild \
  -project "$PROJECT" \
  -target "$APP_NAME" \
  -configuration Release \
  -sdk macosx \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  SYMROOT="$BUILD_DIR" \
  OBJROOT="$BUILD_DIR/Intermediates" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ Build finished, but $APP_PATH was not found."
  exit 1
fi

printf '▶︎ Copying app to dist/...\n'
ditto "$APP_PATH" "$DIST_APP"

# Finder does not use NSApplication.applicationIconImage. It reads the app
# bundle metadata and Resources directly. Make the bundle icon explicit.
printf '▶︎ Installing Finder/Application icon into the app bundle...\n'
mkdir -p "$DIST_APP/Contents/Resources"
cp -f "$SOURCE_ICON" "$DIST_APP/Contents/Resources/AppIcon.icns"

INFO_PLIST="$DIST_APP/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "❌ Info.plist not found at $INFO_PLIST"
  exit 1
fi

# Add or replace both keys. CFBundleIconFile is the canonical macOS bundle key;
# CFBundleIconName also helps asset-catalog-aware system components.
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$INFO_PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$INFO_PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$INFO_PLIST"

if [[ ! -f "$DIST_APP/Contents/Resources/AppIcon.icns" ]]; then
  echo "❌ AppIcon.icns was not copied into the app bundle."
  exit 1
fi

printf '▶︎ Bundle icon metadata:\n'
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$INFO_PLIST"
file "$DIST_APP/Contents/Resources/AppIcon.icns"

printf '▶︎ Applying local ad-hoc signature...\n'
codesign --force --deep --sign - "$DIST_APP"

printf '▶︎ Verifying app bundle...\n'
codesign --verify --deep --strict --verbose=2 "$DIST_APP"

# Touch the bundle after metadata/resource changes so Finder sees a fresh app.
touch "$DIST_APP"

rm -f "$ZIP_PATH"
printf '▶︎ Creating distributable ZIP...\n'
ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$ZIP_PATH"

printf '\n✅ Ready:\n  %s\n  %s\n\n' "$DIST_APP" "$ZIP_PATH"
echo "You can drag FinanceTracker.app into /Applications."
