#!/bin/zsh
# Builds, signs and (when possible) notarizes "Clipboard Fix.app" into ./build.
#
#   ./build.sh                     sign with Developer ID if present, else Apple Development
#   SIGN_IDENTITY="…" ./build.sh   force an identity ("-" for an ad-hoc signature)
#
# Notarization (Developer ID only) uses either an App Store Connect API key
# (APPLE_API_KEY = path to the .p8, APPLE_API_KEY_ID, APPLE_API_ISSUER — what CI uses)
# or NOTARY_PROFILE, a profile saved with `xcrun notarytool store-credentials`.
set -euo pipefail
cd "${0:A:h}"

APP="build/Clipboard Fix.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
xcrun actool Resources/Assets.xcassets --compile "$APP/Contents/Resources" \
  --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon \
  --output-partial-info-plist build/assets-info.plist > /dev/null
rm build/assets-info.plist

swiftc -O -parse-as-library \
  -target arm64-apple-macos14.0 -o build/ClipboardFix-arm64 Sources/ClipboardFix.swift
swiftc -O -parse-as-library \
  -target x86_64-apple-macos14.0 -o build/ClipboardFix-x86_64 Sources/ClipboardFix.swift
lipo -create build/ClipboardFix-arm64 build/ClipboardFix-x86_64 -output "$APP/Contents/MacOS/ClipboardFix"
rm build/ClipboardFix-arm64 build/ClipboardFix-x86_64

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  ids=$(security find-identity -v -p codesigning)
  SIGN_IDENTITY=$(print -r -- "$ids" | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)
  [[ -z "$SIGN_IDENTITY" ]] && SIGN_IDENTITY=$(print -r -- "$ids" | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"' || true)
fi
[[ -z "$SIGN_IDENTITY" ]] && { echo "No signing identity found"; exit 1; }

echo "Signing with: $SIGN_IDENTITY"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

notary=()
if [[ -n "${APPLE_API_KEY:-}" ]]; then
  notary=(--key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER")
elif [[ -n "${NOTARY_PROFILE:-}" ]]; then
  notary=(--keychain-profile "$NOTARY_PROFILE")
fi

ditto -c -k --keepParent "$APP" build/ClipboardFix.zip
if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* && ${#notary} -gt 0 ]]; then
  xcrun notarytool submit build/ClipboardFix.zip "${notary[@]}" --wait
  xcrun stapler staple "$APP"
  rm build/ClipboardFix.zip
  ditto -c -k --keepParent "$APP" build/ClipboardFix.zip
  echo "Notarized."
else
  echo "Not notarized (needs a Developer ID Application certificate and notary credentials)."
fi
echo "Built: $APP and build/ClipboardFix.zip"
