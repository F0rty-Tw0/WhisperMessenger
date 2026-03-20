#!/usr/bin/env bash
# Lint and format-check WhisperMessenger Lua source
# Usage:
#   ./scripts/lint.sh          # check only (CI-safe)
#   ./scripts/lint.sh --fix    # auto-format in place

set -euo pipefail
cd "$(dirname "$0")/.."

FIX=false
if [[ "${1:-}" == "--fix" ]]; then
  FIX=true
fi

EXIT_CODE=0

# --- StyLua (formatting) ---
if command -v stylua &>/dev/null; then
  echo "=== StyLua ==="
  if $FIX; then
    stylua . && echo "  Formatted OK"
  else
    if ! stylua --check .; then
      echo "  Run './scripts/lint.sh --fix' to auto-format"
      EXIT_CODE=1
    else
      echo "  OK"
    fi
  fi
else
  echo "WARN: stylua not found (cargo install stylua --features lua51)"
fi

echo ""

# --- Luacheck (static analysis) ---
if command -v luacheck &>/dev/null; then
  echo "=== Luacheck ==="
  if ! luacheck . --no-color; then
    EXIT_CODE=1
  fi
else
  echo "WARN: luacheck not found (luarocks install luacheck)"
fi

exit $EXIT_CODE
