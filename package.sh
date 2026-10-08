#!/usr/bin/env bash
# Clean allowlisted app assembly. No personal libraries are read or bundled.
set -euo pipefail
cd "$(dirname "$0")"
RELEASE_ROOT="$PWD"
MODE="${1:---build}"
case "$MODE" in --build|--dmg|--run|--demo) ;; *) echo "Usage: $0 [--build|--dmg|--run|--demo]" >&2; exit 2;; esac
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
ARCH="$(uname -m)"
swift build -c release -Xswiftc -debug-prefix-map -Xswiftc "$RELEASE_ROOT=/Waymark"
BIN_DIR="$(swift build -c release --show-bin-path)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/waymark-package.XXXXXX")"
trap '[[ -n "$STAGE" && -d "$STAGE" && "$STAGE" == */waymark-package.* ]] && rm -rf "$STAGE"' EXIT
APP="$STAGE/Waymark.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Demo" dist
cp "$BIN_DIR/Waymark" "$APP/Contents/MacOS/Waymark"
xcrun strip -S "$APP/Contents/MacOS/Waymark"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for asset in coast garden lake; do cp "Resources/Demo/$asset.png" "$APP/Contents/Resources/Demo/$asset.png"; done
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
# Remove only this script's previous generated bundle; never touch /Applications or a library.
if [[ -e "$RELEASE_ROOT/dist/Waymark.app" ]]; then rm -rf "$RELEASE_ROOT/dist/Waymark.app"; fi
mv "$APP" "$RELEASE_ROOT/dist/Waymark.app"
echo "Built: $RELEASE_ROOT/dist/Waymark.app ($ARCH, ad-hoc signed; NOT notarized)"
if [[ "$MODE" == --dmg ]]; then
  mkdir "$STAGE/disk"
  cp -R dist/Waymark.app "$STAGE/disk/Waymark.app"
  ln -s /Applications "$STAGE/disk/Applications"
  cp LICENSE "$STAGE/disk/LICENSE.txt"
  DMG="Waymark-$VERSION-macOS-$ARCH.dmg"
  hdiutil create -volname "Waymark $VERSION" -srcfolder "$STAGE/disk" -format UDZO -ov "dist/$DMG"
  (cd dist && shasum -a 256 "$DMG" > SHA256SUMS)
  echo "DMG: dist/$DMG"
fi
if [[ "$MODE" == --run ]]; then open "$RELEASE_ROOT/dist/Waymark.app"; fi
if [[ "$MODE" == --demo ]]; then open -n "$RELEASE_ROOT/dist/Waymark.app" --args --demo; fi
