#!/usr/bin/env python3
"""Run a single Lua test file using the lupa (LuaJIT FFI) runtime.

Usage:  python scripts/run_test.py tests/ui/test_theme_presets.lua

run_file() is shared with scripts/run_tests.py, which runs many files.
"""

import sys
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")

# Set up package.path to mirror tests/run.lua.
#
# Match tests/run.lua: do NOT pre-install _G.UIParent / _G.CreateFrame
# stubs. Those thin stubs break tests that require("WhisperMessenger.Bootstrap")
# before fake_ui, because Bootstrap.lua's `if type(_G.CreateFrame) ==
# "function"` guard runs Install against an empty-table stub with no
# RegisterEvent/SetScript methods. Tests that need these globals load
# fake_ui themselves, which rawsets a full-fidelity _G.CreateFrame.
SETUP_LUA = """
    package.path = "{root}/?.lua;{root}/?/init.lua;" .. package.path

    local rawRequire = require
    require = function(name)
        if type(name) == "string" and name:find("WhisperMessenger.", 1, true) == 1 then
            name = name:sub(#"WhisperMessenger." + 1)
        end
        return rawRequire(name)
    end
    _G.require = require

    _G.C_ChatInfo = _G.C_ChatInfo or {{}}
    _G.GameTooltip = _G.GameTooltip or {{
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
    }}

    -- A real os.exit would end the whole Python process, and os.exit(0) would look like a pass.
    os.exit = function(code)
        error("os.exit(" .. tostring(code) .. ") called; a test must fail with error() instead", 2)
    end

    -- Lua 5.1 shares one C rand() state per process, so seed every file the same way.
    math.randomseed(1)
"""

# Every TIMEOUT_CHECK_INSTRUCTIONS Lua instructions, error out once the deadline has passed.
# os.time is captured up front so a test that fakes it cannot stop the clock. A test that
# installs its own debug hook replaces this one for the rest of its file.
TIMEOUT_LUA = """
    local timeout, every = ...
    local now, sethook = os.time, debug.sethook
    local deadline = now() + timeout
    sethook(function()
        if now() > deadline then
            error("test file timed out after " .. timeout .. "s", 0)
        end
    end, "", every)
    return sethook
"""
TIMEOUT_CHECK_INSTRUCTIONS = 1000000


def run_file(runtime_cls, test_path, timeout=None):
    """Run one test file in a fresh Lua runtime. Raises on an assert, error, syntax error, or timeout (seconds)."""
    lua = runtime_cls(unpack_returned_tuples=True)
    lua.execute(SETUP_LUA.format(root=PROJECT_ROOT))
    abs_test_path = os.path.join(PROJECT_ROOT, test_path).replace("\\", "/")
    sethook = lua.execute(TIMEOUT_LUA, timeout, TIMEOUT_CHECK_INSTRUCTIONS) if timeout else None
    try:
        test_fn = lua.execute(f'return dofile("{abs_test_path}")')
        if callable(test_fn):
            test_fn()
    finally:
        if sethook:
            sethook()
        # Lua prints go through C stdio, not Python's sys.stdout; flush so they land before our own output.
        lua.execute("io.stdout:flush()")


def main():
    try:
        from lupa import LuaRuntime
    except ImportError:
        print("ERROR: lupa is not installed. Run: pip install lupa", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) < 2:
        print("Usage: python scripts/run_test.py <test-file.lua>", file=sys.stderr)
        sys.exit(1)

    test_path = sys.argv[1].replace("\\", "/")
    abs_test_path = os.path.join(PROJECT_ROOT, test_path).replace("\\", "/")
    if not os.path.isfile(abs_test_path):
        print(f"ERROR: test file not found: {abs_test_path}", file=sys.stderr)
        sys.exit(1)

    try:
        run_file(LuaRuntime, test_path)
        print(f"PASS {test_path}")
    except Exception as e:
        print(f"FAIL {test_path}", file=sys.stderr)
        print(str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
