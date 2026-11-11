#!/bin/zsh
# Builds a Developer ID–signed, notarized Overflight and installs it to /Applications.
# Usage: FLIGHT_TEAM_ID=XXXXXXXXXX FLIGHT_NOTARY_PROFILE=flight-notary scripts/release.sh
set -euo pipefail

: "${FLIGHT_TEAM_ID:?Set FLIGHT_TEAM_ID to your Apple Developer team ID}"
: "${FLIGHT_NOTARY_PROFILE:?Set FLIGHT_NOTARY_PROFILE to a notarytool keychain profile (see README)}"

ROOT=${0:A:h:h}
BUILD="$ROOT/build/release"
ARCHIVE="$BUILD/Overflight.xcarchive"
EXPORT="$BUILD/export"
APP="$EXPORT/Overflight.app"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "No 'Developer ID Application' certificate found." >&2
  echo "Create one in Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application." >&2
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$FLIGHT_NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Notary profile '$FLIGHT_NOTARY_PROFILE' not found. Create it once with:" >&2
  echo "  xcrun notarytool store-credentials $FLIGHT_NOTARY_PROFILE --apple-id <apple-id> --team-id $FLIGHT_TEAM_ID" >&2
  exit 1
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

xcodegen --spec "$ROOT/Xcode/project.yml"

xcodebuild archive \
  -project "$ROOT/Xcode/Overflight.xcodeproj" \
  -scheme Overflight \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet

cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$FLIGHT_TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" \
  -allowProvisioningUpdates \
  -quiet

ditto -c -k --keepParent "$APP" "$BUILD/Overflight.zip"
xcrun notarytool submit "$BUILD/Overflight.zip" --keychain-profile "$FLIGHT_NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

pkill -x Overflight || true
rm -rf /Applications/Overflight.app
cp -R "$APP" /Applications/
spctl -a -vv /Applications/Overflight.app
echo "Installed /Applications/Overflight.app"
