#!/bin/zsh
set -euo pipefail

# Installs the free execution stack for local M0/M1 work.
# Never installs paid software. Never copies binaries into git.

if command -v wine64 >/dev/null 2>&1 || command -v wine >/dev/null 2>&1; then
  echo "wine: $(command -v wine64 2>/dev/null || command -v wine)"
else
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install Wine. https://brew.sh" >&2
    exit 1
  fi
  echo "installing wine-stable (Homebrew, free)"
  brew install wine-stable
fi

if [[ -f /opt/homebrew/lib/libMoltenVK.dylib || -f /usr/local/lib/libMoltenVK.dylib ]]; then
  echo "moltenvk: present"
else
  if command -v brew >/dev/null 2>&1; then
    echo "installing molten-vk (Homebrew, free)"
    brew install molten-vk
  fi
fi

echo "done. Play uses whatever Wine is on PATH; Mogged writes backend.json on first launch."
