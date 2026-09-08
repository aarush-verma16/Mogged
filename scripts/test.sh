#!/bin/zsh
# Terminal-only test runner. SwiftPM discovers every test in runtime/Tests
# automatically — add a *Tests.swift file and the next run picks it up.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER=""
WATCH=0
LIST=0
INTERACTIVE=0
VERBOSE=0
LAUNCHER=1

usage() {
  cat <<'EOF'
Mogged tests — terminal only. New test files under runtime/Tests are picked up automatically.

  scripts/test.sh                 run everything (runtime tests + launcher build)
  scripts/test.sh -i              interactive menu
  scripts/test.sh --watch         rerun when Swift/profile files change
  scripts/test.sh --list          list discovered tests
  scripts/test.sh --filter NAME   run matching tests (suite or test name)
  scripts/test.sh Steam           same as --filter Steam
  scripts/test.sh --verbose       extra swift test output

Suites worth filtering: Inventory, Steam, LaunchPath, Runtime surface, ProfileAndInstall
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i|--interactive) INTERACTIVE=1 ;;
    -w|--watch) WATCH=1 ;;
    -l|--list) LIST=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    --filter)
      shift
      FILTER="${1:-}"
      ;;
    --filter=*) FILTER="${1#--filter=}" ;;
    --no-launcher) LAUNCHER=0 ;;
    --) shift; break ;;
    -*)
      echo "unknown flag: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      FILTER="$1"
      ;;
  esac
  shift
done

run_runtime() {
  echo "==> runtime tests${FILTER:+  filter=$FILTER}"
  if [[ -n "$FILTER" && "$VERBOSE" -eq 1 ]]; then
    swift test --package-path "$ROOT/runtime" --filter "$FILTER" --verbose
  elif [[ -n "$FILTER" ]]; then
    swift test --package-path "$ROOT/runtime" --filter "$FILTER"
  elif [[ "$VERBOSE" -eq 1 ]]; then
    swift test --package-path "$ROOT/runtime" --verbose
  else
    swift test --package-path "$ROOT/runtime"
  fi
}

run_launcher() {
  echo "==> launcher build"
  swift build --package-path "$ROOT/apps/launcher"
}

run_all() {
  run_runtime
  if [[ "$LAUNCHER" -eq 1 && -z "$FILTER" ]]; then
    run_launcher
  fi
}

list_tests() {
  echo "==> discovered tests"
  swift test list --package-path "$ROOT/runtime"
}

fingerprint() {
  find "$ROOT/runtime" "$ROOT/apps/launcher" "$ROOT/profiles" \
    \( -name '*.swift' -o -name '*.json' -o -name 'Package.swift' \) \
    -print0 2>/dev/null \
    | xargs -0 stat -f '%m %N' 2>/dev/null \
    | cksum
}

run_watch() {
  echo "==> watch (runtime). Ctrl-C to stop."
  local last=""
  local now
  while true; do
    now="$(fingerprint)"
    if [[ "$now" != "$last" ]]; then
      last="$now"
      echo
      echo "-- $(date '+%H:%M:%S') --"
      run_runtime || true
    fi
    sleep 1
  done
}

interactive() {
  while true; do
    cat <<'EOF'

  1) all (runtime + launcher)
  2) runtime only
  3) Steam / sign-in
  4) launch path
  5) profiles / library
  6) inventory (new files + profiles)
  7) runtime surface
  8) list tests
  9) watch runtime
  /) custom filter
  q) quit

EOF
    printf 'pick: '
    local choice
    if ! read -r choice; then
      echo
      break
    fi
    case "$choice" in
      1) FILTER=""; LAUNCHER=1; run_all || true ;;
      2) FILTER=""; run_runtime || true ;;
      3) FILTER="Steam"; run_runtime || true ;;
      4) FILTER="LaunchPath"; run_runtime || true ;;
      5) FILTER="Profile"; run_runtime || true ;;
      6) FILTER="Inventory"; run_runtime || true ;;
      7) FILTER="Runtime surface"; run_runtime || true ;;
      8) list_tests || true ;;
      9) FILTER=""; run_watch ;;
      /*)
        FILTER="${choice#/}"
        run_runtime || true
        ;;
      q|Q) break ;;
      "") ;;
      *)
        echo "unknown pick: $choice"
        ;;
    esac
  done
}

if [[ "$INTERACTIVE" -eq 1 ]]; then
  interactive
  exit 0
fi

if [[ "$LIST" -eq 1 ]]; then
  list_tests
  exit 0
fi

if [[ "$WATCH" -eq 1 ]]; then
  run_watch
  exit 0
fi

run_all
