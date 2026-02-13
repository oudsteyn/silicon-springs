#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${1:-godot}"
if [[ $# -gt 0 ]]; then
  shift
fi

OUT_FILE="$(mktemp)"
cleanup() {
  rm -f "$OUT_FILE"
}
trap cleanup EXIT

set +e
"$GODOT_BIN" --headless -s tests/run_headless.gd "$@" >"$OUT_FILE" 2>&1
status=$?
set -e

cat "$OUT_FILE"

if [[ $status -ne 0 ]]; then
  exit "$status"
fi

if grep -Eq "SCRIPT ERROR:|Parse Error:|Failed to load script|Invalid type in function|Invalid call\\.|Stack overflow" "$OUT_FILE"; then
  echo "Strict test mode failed: runtime script errors were emitted."
  exit 1
fi

if grep -Eq "ObjectDB instances leaked at exit|resources still in use at exit|Resource still in use:" "$OUT_FILE"; then
  echo "Strict test mode failed: leak/resource warnings were emitted."
  exit 1
fi
