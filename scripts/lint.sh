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

find_command() {
  local name="$1"
  local resolved=""

  if resolved="$(command -v "$name" 2>/dev/null)"; then
    printf '%s\n' "$resolved"
    return 0
  fi

  local old_ifs="$IFS"
  IFS=:
  for dir in $PATH; do
    IFS="$old_ifs"
    for candidate in "$dir/$name" "$dir/$name.exe" "$dir/$name.EXE"; do
      if [[ -x "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
    IFS=:
  done
  IFS="$old_ifs"

  return 1
}

STYLUA_CMD=""
if [[ -x ".tools/stylua/stylua.exe" ]]; then
  STYLUA_CMD=".tools/stylua/stylua.exe"
elif STYLUA_CMD="$(find_command stylua)"; then
  :
else
  STYLUA_CMD=""
fi

LUACHECK_CMD=""
if [[ -f ".tools/hererocks54/bin/luacheck.bat" ]]; then
  LUACHECK_CMD=".tools/hererocks54/bin/luacheck.bat"
elif LUACHECK_CMD="$(find_command luacheck)"; then
  :
else
  LUACHECK_CMD=""
fi

LUALS_CMD=""
if [[ -x ".tools/lua-language-server/bin/lua-language-server.exe" ]]; then
  LUALS_CMD=".tools/lua-language-server/bin/lua-language-server.exe"
elif LUALS_CMD="$(find_command lua-language-server)"; then
  :
else
  LUALS_CMD=""
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
fi
exit $EXIT_CODE
