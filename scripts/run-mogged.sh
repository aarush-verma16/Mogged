#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MOGGED_PROFILES="$ROOT/profiles"

swift build --package-path "$ROOT/apps/launcher"
BIN="$(swift build --package-path "$ROOT/apps/launcher" --show-bin-path)/Mogged"
APP="$ROOT/apps/launcher/.build/Mogged.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/apps/launcher/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Mogged"
chmod +x "$APP/Contents/MacOS/Mogged"

open "$APP"
