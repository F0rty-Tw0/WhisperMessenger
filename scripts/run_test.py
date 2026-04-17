#!/usr/bin/env python3
"""Run a single Lua test file using the lupa (LuaJIT FFI) runtime.

Usage:  python scripts/run_test.py tests/ui/test_theme_presets.lua
"""

import sys
import os

try:
    from lupa import LuaRuntime
except ImportError:
    print("ERROR: lupa is not installed. Run: pip install lupa", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/run_test.py <test-file.lua>", file=sys.stderr)
        sys.exit(1)

    test_path = sys.argv[1].replace("\\", "/")
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")

    lua = LuaRuntime(unpack_returned_tuples=True)

    # Set up package.path to mirror tests/run.lua
    lua.execute(f"""
        package.path = "{project_root}/?.lua;{project_root}/?/init.lua;" .. package.path

        local rawRequire = require
        require = function(name)
            if type(name) == "string" and name:find("WhisperMessenger.", 1, true) == 1 then
                name = name:sub(#"WhisperMessenger." + 1)
            end
            return rawRequire(name)
        end
        _G.require = require
    """)

    # Provide minimal _G stubs that tests/helpers/fake_ui.lua may not cover
    lua.execute("""
        _G.UIParent = _G.UIParent or {
            CreateTexture = function() return {
                SetTexture = function() end,
                SetAlpha = function() end,
                SetSize = function() end,
            } end,
        }
        _G.CreateFrame = _G.CreateFrame or function() return {} end
        _G.C_ChatInfo = _G.C_ChatInfo or {}
        _G.GameTooltip = _G.GameTooltip or {
            SetOwner = function() end,
            SetText = function() end,
            AddLine = function() end,
            Show = function() end,
            Hide = function() end,
        }
    """)

    abs_test_path = os.path.join(project_root, test_path).replace("\\", "/")
    if not os.path.isfile(abs_test_path):
        print(f"ERROR: test file not found: {abs_test_path}", file=sys.stderr)
        sys.exit(1)

    try:
        test_fn = lua.execute(f'return dofile("{abs_test_path}")')
        if callable(test_fn):
            test_fn()
        print(f"PASS {test_path}")
    except Exception as e:
        print(f"FAIL {test_path}", file=sys.stderr)
        print(str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
