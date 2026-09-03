#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MOGGED_PROFILES="$ROOT/profiles"

swift build --package-path "$ROOT/apps/launcher"
BIN="$(swift build --package-path "$ROOT/apps/launcher" --show-bin-path)/Mogged"
APP="$ROOT/apps/launcher/.build/Mogged.app"
FONTS="$ROOT/apps/launcher/Sources/Mogged/Resources/Fonts"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
cp "$ROOT/apps/launcher/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Mogged"
cp "$FONTS/"*.ttf "$APP/Contents/Resources/Fonts/"
chmod +x "$APP/Contents/MacOS/Mogged"

open "$APP"
