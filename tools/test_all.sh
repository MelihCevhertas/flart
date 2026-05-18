#!/usr/bin/env bash
# Run `dart test` against every workspace member that has a `test/` directory.
#
# Workspace-wide test execution: `dart test` from the root does not
# auto-discover member packages. This script cd's into each package so the
# package's own pubspec is resolved before running its tests.
#
# CI and the day-to-day developer loop should prefer this script; ad-hoc
# `dart test packages/<pkg>/test` is fine for quick single-package runs.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
FAILED=()

for pkg in packages/*/; do
  if [ -d "${pkg}test" ]; then
    echo "=== Testing ${pkg%/} ==="
    if (cd "$pkg" && dart test); then
      :
    else
      FAILED+=("${pkg%/}")
    fi
    echo
  fi
done

cd "$ROOT"

if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All package test suites passed."
else
  echo "FAILED packages:"
  for p in "${FAILED[@]}"; do
    echo "  - $p"
  done
  exit 1
fi
