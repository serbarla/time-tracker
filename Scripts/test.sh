#!/usr/bin/env bash
# Test pipeline: build+test -> package -> UI smoke.
# Stages delegate to the standalone scripts; no logic of its own.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "usage: bash Scripts/test.sh [all|build|package|smoke]" >&2
  exit 2
}

stage_build() {
  swift build
  swift test
}

stage_package() {
  bash "$ROOT/Scripts/package-app.sh"
}

stage_smoke() {
  bash "$ROOT/Scripts/ui-smoke.sh"
}

case "${1:-all}" in
  all) stages=(build package smoke) ;;
  build|package|smoke) stages=("$1") ;;
  *) usage ;;
esac

for s in "${stages[@]}"; do
  echo "==> $s"
  "stage_$s"
done
