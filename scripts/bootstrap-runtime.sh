#!/bin/zsh
set -euo pipefail

# Puts the free on-device stack on this Mac. Never paid. Never committed to git.
# Homebrew wine casks are Gatekeeper-disabled (2026-09-01). Use Gcenx tarballs.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$HOME/Library/Application Support/Mogged/engine"
WINE_VER="11.16"
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VER}/wine-staging-${WINE_VER}-osx64.tar.xz"
DXVK_URL="https://github.com/Gcenx/DXVK-macOS/releases/download/v1.10.3-20230507-repack/dxvk-macOS-async-v1.10.3-20230507-repack.tar.gz"

mkdir -p "$ENGINE"
mkdir -p "$ROOT/third_party/dxvk/x64"

wine_bin() {
  local candidates=(
    "$ENGINE/Wine Staging.app/Contents/Resources/wine/bin/wine64"
    "$ENGINE/Wine Staging.app/Contents/Resources/wine/bin/wine"
    "/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine64"
    "/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine"
  )
  if command -v wine64 >/dev/null 2>&1; then
    command -v wine64
    return
  fi
  if command -v wine >/dev/null 2>&1; then
    command -v wine
    return
  fi
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      echo "$c"
      return
    fi
  done
  return 1
}

if wine_bin >/dev/null 2>&1; then
  echo "wine: $(wine_bin)"
else
  echo "installing Wine Staging ${WINE_VER} (Gcenx, free)"
  if command -v brew >/dev/null 2>&1; then
    brew install --cask gstreamer-runtime || true
  fi
  if ! /usr/bin/pgrep -q oahd 2>/dev/null; then
    echo "Rosetta 2 is not installed. Gcenx Wine is x86_64. Installing (needs sudo)..."
    softwareupdate --install-rosetta --agree-to-license || echo "install Rosetta later: softwareupdate --install-rosetta"
  fi
  TMP="$(mktemp -d)"
  curl -L --fail -o "$TMP/wine.tar.xz" "$WINE_URL"
  tar -xJf "$TMP/wine.tar.xz" -C "$ENGINE"
  rm -rf "$TMP"
  echo "wine extracted under $ENGINE"
  if wine_bin >/dev/null 2>&1; then
    echo "wine: $(wine_bin)"
  else
    echo "warning: tarball extracted but wine binary not at the expected path. ls $ENGINE"
    ls -la "$ENGINE"
  fi
fi

if [[ -f /opt/homebrew/lib/libMoltenVK.dylib || -f /usr/local/lib/libMoltenVK.dylib ]]; then
  echo "moltenvk: present"
else
  brew install molten-vk
fi

if [[ -f "$ROOT/third_party/dxvk/x64/d3d11.dll" ]]; then
  echo "dxvk: present"
else
  echo "installing DXVK-macOS into third_party/dxvk (gitignored)"
  TMP="$(mktemp -d)"
  curl -L --fail -o "$TMP/dxvk.tar.gz" "$DXVK_URL"
  tar -xzf "$TMP/dxvk.tar.gz" -C "$TMP"
  found="$(find "$TMP" -name 'd3d11.dll' | head -n 1)"
  if [[ -n "$found" ]]; then
    cp "$(dirname "$found")"/*.dll "$ROOT/third_party/dxvk/x64/"
    echo "dxvk: copied $(ls "$ROOT/third_party/dxvk/x64")"
  else
    echo "dxvk: archive had no d3d11.dll"
  fi
  rm -rf "$TMP"
fi

echo "done. Mogged looks for wine on PATH, /Applications/Wine*.app, or $ENGINE"
echo "next: put a Windows game folder on disk, then Play in Mogged."
