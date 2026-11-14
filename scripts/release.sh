#!/bin/zsh
# Build and package a release zip: build/DisplaySwitch-<version>.zip
# (DisplaySwitch.app + displayctl). The version comes from Resources/Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_NAME}" != "v${VERSION}" ]]; then
  echo "Tag ${GITHUB_REF_NAME} ne correspond pas à la version ${VERSION} de Info.plist" >&2
  exit 1
fi

scripts/build-app.sh

STAGE=build/release/DisplaySwitch-${VERSION}
rm -rf build/release && mkdir -p "$STAGE"
cp -R build/DisplaySwitch.app build/displayctl README.md README.fr.md LICENSE "$STAGE/"
ZIP=build/DisplaySwitch-${VERSION}.zip
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$STAGE" "$ZIP"
(cd "$(dirname "$ZIP")" && shasum -a 256 "$(basename "$ZIP")") | tee "$ZIP.sha256"
echo "OK: $ZIP"
