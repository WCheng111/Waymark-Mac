#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# One project-local entrypoint; intentionally does not kill an installed personal instance.
case "${1:-run}" in
  run) exec ./package.sh --run ;;
  --demo) exec ./package.sh --demo ;;
  --debug) ./package.sh; exec lldb dist/Waymark.app/Contents/MacOS/Waymark ;;
  --verify) ./package.sh; codesign --verify --deep --strict dist/Waymark.app ;;
  --logs|--telemetry) ./package.sh --run; exec /usr/bin/log stream --info --style compact --predicate 'process == "Waymark"' ;;
  *) echo "Usage: $0 [--demo|--debug|--verify|--logs|--telemetry]" >&2; exit 2 ;;
esac
