#!/bin/zsh
# Build DisplaySwitch.app (menu bar app) and displayctl (CLI) into ./build.
# Universal binaries (Apple Silicon + Intel).
# Usage: scripts/build-app.sh [--install]   (--install copies the app to /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}" --product DisplaySwitch
swift build -c release "${ARCHS[@]}" --product displayctl
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

APP=build/DisplaySwitch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN/DisplaySwitch" "$APP/Contents/MacOS/DisplaySwitch"
cp "$BIN/displayctl" build/displayctl

# Ad-hoc signature: enough for local use and for SMAppService (launch at login).
codesign --force --sign - "$APP"
codesign --force --sign - build/displayctl

echo "OK: $APP et build/displayctl ($(lipo -archs build/displayctl))"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x DisplaySwitch 2>/dev/null || true
  rm -rf /Applications/DisplaySwitch.app
  cp -R "$APP" /Applications/
  echo "Installé dans /Applications/DisplaySwitch.app"
fi
