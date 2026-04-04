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
TARGETS=(Bootstrap.lua Core Model Persistence Transport UI Util tests)

STYLUA_CMD=""
if [[ -x ".tools/stylua/stylua.exe" ]]; then
  STYLUA_CMD=".tools/stylua/stylua.exe"
elif command -v stylua &>/dev/null; then
  STYLUA_CMD="$(command -v stylua)"
fi

LUACHECK_CMD=""
if [[ -f ".tools/hererocks54/bin/luacheck.bat" ]]; then
  LUACHECK_CMD=".tools/hererocks54/bin/luacheck.bat"
elif command -v luacheck &>/dev/null; then
  LUACHECK_CMD="$(command -v luacheck)"
fi

LUALS_CMD=""
if [[ -x ".tools/lua-language-server/bin/lua-language-server.exe" ]]; then
  LUALS_CMD=".tools/lua-language-server/bin/lua-language-server.exe"
elif command -v lua-language-server &>/dev/null; then
  LUALS_CMD="$(command -v lua-language-server)"
fi

# --- StyLua (formatting) ---
if [[ -n "$STYLUA_CMD" ]]; then
  echo "=== StyLua ==="
  if $FIX; then
    if ! "$STYLUA_CMD" "${TARGETS[@]}"; then
      EXIT_CODE=1
    else
      echo "  Formatted OK"
    fi
  else
    if ! "$STYLUA_CMD" --check "${TARGETS[@]}"; then
      echo "  Run './scripts/lint.sh --fix' to auto-format"
      EXIT_CODE=1
    else
      echo "  OK"
    fi
  fi
else
  echo "WARN: stylua not found (run 'powershell -ExecutionPolicy Bypass -File scripts/setup-lint-tools.ps1' or install globally)"
fi

echo ""

# --- Luacheck (static analysis) ---
if [[ -n "$LUACHECK_CMD" ]]; then
  echo "=== Luacheck ==="
  if ! "$LUACHECK_CMD" --no-color "${TARGETS[@]}"; then
    EXIT_CODE=1
  fi
else
  echo "WARN: luacheck not found (run 'powershell -ExecutionPolicy Bypass -File scripts/setup-lint-tools.ps1' or install globally)"
fi


echo ""

# --- Lua Language Server diagnostics (type/null flow checks) ---
if [[ -n "$LUALS_CMD" ]]; then
  echo "=== LuaLS Diagnostics ==="
  if ! "$LUALS_CMD" --check=. --check_format=pretty --checklevel=Warning; then
    EXIT_CODE=1
  fi
else
  echo "WARN: lua-language-server not found (run 'powershell -ExecutionPolicy Bypass -File scripts/setup-lint-tools.ps1' or install globally)"
  EXIT_CODE=1
fi
exit $EXIT_CODE