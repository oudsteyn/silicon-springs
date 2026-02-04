#!/usr/bin/env bash
set -euo pipefail

# Filter out noisy resource load logs while preserving errors and test output.
godot --headless --verbose -s tests/run_headless.gd 2>&1 | python -u - <<'PY'
import sys
for line in sys.stdin:
    if line.startswith("Loading resource: "):
        continue
    print(line, end="")
PY
