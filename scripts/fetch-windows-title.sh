#!/bin/zsh
set -euo pipefail

# Pull a Windows Steam depot onto this Mac. The Mac Steam app cannot do this.
# Mogged is not a store — this is an operator script. Uses your Steam account.
# Never commit games, steamcmd, or credentials.

TITLE="${1:-apex-legends}"
ROOT="${MOGGED_HOME:-$HOME/Library/Application Support/Mogged}"
STEAMCMD_DIR="$ROOT/steamcmd"
GAMES="$ROOT/games"
LIBRARY_JSON="$ROOT/library.json"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz"

case "$TITLE" in
  apex-legends|apex|1172470)
    TITLE_ID="apex-legends"
    APP_ID="1172470"
    EXE="r5apex.exe"
    ;;
  marvel-rivals|rivals|2767030)
    TITLE_ID="marvel-rivals"
    APP_ID="2767030"
    EXE="Marvel-Win64-Shipping.exe"
    ;;
  *)
    echo "unknown title: $TITLE"
    echo "usage: STEAM_USER=yourname npm run fetch -- apex-legends"
    echo "       STEAM_USER=yourname npm run fetch -- marvel-rivals"
    exit 2
    ;;
esac

mkdir -p "$STEAMCMD_DIR" "$GAMES"
DEST="$GAMES/$TITLE_ID"

if [[ ! -x "$STEAMCMD_DIR/steamcmd.sh" ]]; then
  echo "installing SteamCMD into $STEAMCMD_DIR"
  TMP="$(mktemp -d)"
  curl -L --fail -o "$TMP/steamcmd_osx.tar.gz" "$STEAMCMD_URL"
  tar -xzf "$TMP/steamcmd_osx.tar.gz" -C "$STEAMCMD_DIR"
  rm -rf "$TMP"
  xattr -dr com.apple.quarantine "$STEAMCMD_DIR" 2>/dev/null || true
fi

if [[ -z "${STEAM_USER:-}" ]]; then
  echo
  echo "SteamCMD is ready. Mac Steam still cannot install Windows Apex."
  echo "This script will download the Windows files with SteamCMD (your account)."
  echo
  echo "  STEAM_USER=your_steam_username npm run fetch -- $TITLE_ID"
  echo
  echo "Use the Steam account name, not email. Password and Steam Guard are typed"
  echo "into SteamCMD. Apex must already be in that account's library (it is F2P;"
  echo "add it once on any Steam client if needed). Expect ~50–80 GB and a long wait."
  exit 2
fi

avail_gb=$(df -g "$ROOT" | awk 'NR==2 { print $4 }')
if [[ -n "$avail_gb" ]] && (( avail_gb < 80 )); then
  echo "need ~80 GB free for $TITLE_ID; this volume has ${avail_gb} GB"
  exit 1
fi

echo "Windows depot $APP_ID → $DEST"
echo "SteamCMD will prompt for password / Steam Guard. Do not paste a password on the command line."

"$STEAMCMD_DIR/steamcmd.sh" \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$DEST" \
  +login "$STEAM_USER" \
  +app_update "$APP_ID" validate \
  +quit

found="$(find "$DEST" -iname "$EXE" 2>/dev/null | head -n 1)"
if [[ -z "$found" ]]; then
  echo "SteamCMD exited but $EXE is not under $DEST"
  echo "If you saw Invalid platform, the Windows force flag failed. Re-run."
  echo "If you saw Failed to request AppInfo, log into Steam once on any device and add the game."
  exit 1
fi

GAME_DIR="$(dirname "$found")"
python3 - "$LIBRARY_JSON" "$TITLE_ID" "$DEST" <<'PY'
import json, sys, pathlib
path, title_id, dest = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
data = {"overrides": []}
if path.exists():
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        data = {"overrides": []}
overrides = [o for o in data.get("overrides", []) if o.get("titleId") != title_id]
overrides.append({"titleId": title_id, "path": dest})
data["overrides"] = overrides
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2) + "\n")
print(f"wrote {path}: {title_id} → {dest}")
PY

echo "done. $EXE is at $found"
echo "Open Mogged and Play. Locate is already pointed at $DEST."
