#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: ./scripts/run_terrain_perf_gate.sh <metrics.json>" >&2
  exit 2
fi

godot --headless -s res://scripts/terrain_perf_gate.gd "$1"
