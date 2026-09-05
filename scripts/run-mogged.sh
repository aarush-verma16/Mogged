#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUPPORT="${HOME}/Library/Application Support/Mogged"

swift build --package-path "$ROOT/apps/launcher"
BIN="$(swift build --package-path "$ROOT/apps/launcher" --show-bin-path)/Mogged"
APP="$ROOT/apps/launcher/.build/Mogged.app"
FONTS="$ROOT/apps/launcher/Sources/Mogged/Resources/Fonts"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts" "$APP/Contents/Resources/profiles"
cp "$ROOT/apps/launcher/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Mogged"
cp "$FONTS/"*.ttf "$APP/Contents/Resources/Fonts/"
cp "$ROOT/profiles/"*.json "$APP/Contents/Resources/profiles/"
chmod +x "$APP/Contents/MacOS/Mogged"

mkdir -p "$SUPPORT/engine/dxvk" "$SUPPORT/profiles"
cp "$ROOT/profiles/"*.json "$SUPPORT/profiles/"
if [[ -f "$ROOT/third_party/dxvk/x64/d3d11.dll" ]]; then
  cp "$ROOT/third_party/dxvk/x64/"*.dll "$SUPPORT/engine/dxvk/"
fi

# Run from Application Support so the live app is not on Desktop (no TCC re-prompt).
STABLE="$SUPPORT/Mogged.app"
rm -rf "$STABLE"
ditto "$APP" "$STABLE"

# Do not pass repo paths into the app. Desktop/Mogged would re-ask for Desktop access.
open "$STABLE"
