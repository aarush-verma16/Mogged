#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift test --package-path "$ROOT/runtime"
swift build --package-path "$ROOT/apps/launcher"
