#!/bin/sh
# One-time (and after adding files) setup on a Mac:
#   1. Copies REVERSED_CLIENT_ID from Vadan/GoogleService-Info.plist into Config/Google.xcconfig
#      so Google Sign-In can return to the app.
#   2. Saves the App Check debug token in Config/AppCheck.xcconfig (git-ignored), so debug
#      builds pass App Check however they're launched. Pass it as the first argument, or the
#      script asks for it the first time.
#   3. Generates Vadan.xcodeproj from project.yml with XcodeGen.
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

// App Check debug token (git-ignored; see README).
#include? "AppCheck.xcconfig"
XC
    echo "Google Sign-In URL scheme set."
  else
    echo "Note: $PLIST has no REVERSED_CLIENT_ID. Enable Google sign-in in the Firebase console,"
    echo "      download GoogleService-Info.plist again, and re-run this script."
  fi
else
  echo "Note: $PLIST is missing. Download it from the Firebase console (see README)."
fi

# App Check debug token: from the first argument, or asked for once and kept.
TOKEN_FILE="Config/AppCheck.xcconfig"
TOKEN="$1"
if [ -z "$TOKEN" ] && [ ! -f "$TOKEN_FILE" ] && [ -t 0 ]; then
  printf "App Check debug token (Firebase console > App Check > Vadan (iOS) > Manage debug tokens),\nor press Return to skip: "
  read -r TOKEN
fi
if [ -n "$TOKEN" ]; then
  printf '// App Check debug token for debug builds. Git-ignored: never commit it.\nAPP_CHECK_DEBUG_TOKEN = %s\n' "$TOKEN" > "$TOKEN_FILE"
  echo "App Check debug token saved."
elif [ ! -f "$TOKEN_FILE" ]; then
  echo "Note: no App Check debug token yet. Translation and friends will be rejected until you"
  echo "      run ./scripts/setup.sh <token>."
fi

# Use an installed XcodeGen, or download it into .tools/ (no Homebrew or admin password needed).
if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN=xcodegen
else
  XCODEGEN=".tools/xcodegen/bin/xcodegen"
  if [ ! -x "$XCODEGEN" ]; then
    echo "Downloading XcodeGen..."
    mkdir -p .tools
    curl -fsSL -o .tools/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
    unzip -q -o .tools/xcodegen.zip -d .tools
    rm .tools/xcodegen.zip
  fi
fi
"$XCODEGEN" generate
echo "Done. Open Vadan.xcodeproj."
