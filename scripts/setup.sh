#!/bin/sh
# One-time (and after adding files) setup on a Mac:
#   1. Copies REVERSED_CLIENT_ID from Vadan/GoogleService-Info.plist into Config/Google.xcconfig
#      so Google Sign-In can return to the app.
#   2. Generates Vadan.xcodeproj from project.yml with XcodeGen.
set -e
cd "$(dirname "$0")/.."

PLIST="Vadan/GoogleService-Info.plist"
if [ -f "$PLIST" ]; then
  REVERSED=$(/usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "$PLIST" 2>/dev/null || true)
  if [ -n "$REVERSED" ]; then
    cat > Config/Google.xcconfig <<XC
// Google Sign-In's return URL scheme: REVERSED_CLIENT_ID from GoogleService-Info.plist.
// Written by scripts/setup.sh.
GOOGLE_REVERSED_CLIENT_ID = $REVERSED
XC
    echo "Google Sign-In URL scheme set."
  else
    echo "Note: $PLIST has no REVERSED_CLIENT_ID. Enable Google sign-in in the Firebase console,"
    echo "      download GoogleService-Info.plist again, and re-run this script."
  fi
else
  echo "Note: $PLIST is missing. Download it from the Firebase console (see README)."
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen isn't installed. Run: brew install xcodegen" >&2
  exit 1
fi
xcodegen generate
echo "Done. Open Vadan.xcodeproj."
