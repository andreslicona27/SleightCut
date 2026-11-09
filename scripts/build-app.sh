#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Universal builds require the macOS SDK and Xcode command line tools.
mkdir -p .build/universal
for ARCH in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -swift-version 5 -target "$ARCH-apple-macos13.0" Sources/SleightCut/*.swift -o ".build/universal/SleightCut-$ARCH"
done
xcrun lipo -create .build/universal/SleightCut-arm64 .build/universal/SleightCut-x86_64 -output .build/universal/SleightCut
BIN_DIR="$PWD/.build/universal"
APP="$PWD/dist/SleightCut.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
./scripts/build-icon.sh
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN_DIR/SleightCut" "$APP/Contents/MacOS/SleightCut"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
ditto -c -k --keepParent "$APP" "$PWD/dist/SleightCut-macOS.zip"
echo "Created $APP and dist/SleightCut-macOS.zip"
