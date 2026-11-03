#!/usr/bin/env python3
"""Run many Lua test files in one Python process, a fresh Lua runtime per file.

Usage:
  python scripts/run_tests.py                       # every tests/**/test_*.lua
  python scripts/run_tests.py tests/ui/test_a.lua   # just these files
  python scripts/run_tests.py --jobs 1 --lua default

Uses Lua 5.1 (lupa.lua51) by default to match WoW and CI. Keeps going after a
failure, prints a summary, and exits 1 if any file failed. A file that runs past
--timeout seconds fails; a worker process that dies fails the files it had not
finished.
"""

import argparse
import gc
import importlib
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from concurrent.futures.process import BrokenProcessPool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_test

LUA_MODULES = {"51": "lupa.lua51", "default": "lupa"}
MAX_DEFAULT_JOBS = 8
DEFAULT_TIMEOUT = 60
WORKER_DIED = "worker process died before this file finished (BrokenProcessPool)"

_runtime_cls = None


def load_runtime(module_name):
    global _runtime_cls
    _runtime_cls = importlib.import_module(module_name).LuaRuntime


def resolve_lua_module(flavor):
    """Pick the lupa module for the flavor, falling back to default lupa if lua51 is missing."""
    module_name = LUA_MODULES[flavor]
    try:
        importlib.import_module(module_name)
        return module_name
    except ImportError:
        pass
    if module_name == "lupa":
        print("ERROR: lupa is not installed. Run: pip install lupa", file=sys.stderr)
        sys.exit(1)
    print(
        f"WARNING: {module_name} is unavailable (needs lupa 2.x: pip install -U lupa); "
        "falling back to default lupa, whose Lua version differs from WoW's 5.1.",
        file=sys.stderr,
    )
    return resolve_lua_module("default")


def run_one(test_path, timeout):
    try:
        run_test.run_file(_runtime_cls, test_path, timeout)
        return test_path, None
    except Exception as e:
        return test_path, str(e)
    finally:
        gc.collect()


def to_repo_path(path):
    """Turn a path given relative to the caller's cwd into one that still works after chdir to the repo root."""
    absolute = os.path.abspath(path)
    try:
        relative = os.path.relpath(absolute, run_test.PROJECT_ROOT)
    except ValueError:  # different drive on Windows
        return absolute.replace("\\", "/")
    return (absolute if relative.startswith("..") else relative).replace("\\", "/")


def find_test_files():
    return sorted(
        os.path.join(folder, name).replace("\\", "/")
        for folder, _, names in os.walk("tests")
        for name in names
        if name.startswith("test_") and name.endswith(".lua")
    )


def run_all(files, module_name, jobs, timeout):
    if jobs <= 1:
        load_runtime(module_name)
        for test_path in files:
            yield run_one(test_path, timeout)
        return
    with ProcessPoolExecutor(jobs, initializer=load_runtime, initargs=(module_name,)) as pool:
        futures = [pool.submit(run_one, test_path, timeout) for test_path in files]
        for test_path, future in zip(files, futures):
            try:
                yield future.result()
            except BrokenProcessPool:
                yield test_path, WORKER_DIED


def parse_args():
    parser = argparse.ArgumentParser(description="Run Lua test files with lupa.")
    parser.add_argument("files", nargs="*", help="test files (default: every tests/**/test_*.lua)")
    parser.add_argument("--jobs", type=int, default=min(MAX_DEFAULT_JOBS, os.cpu_count() or 1))
    parser.add_argument("--lua", choices=sorted(LUA_MODULES), default="51")
    parser.add_argument(
        "--timeout", type=float, default=DEFAULT_TIMEOUT, help="seconds before a test file fails (0 = no limit)"
    )
    return parser.parse_args()


def main():
    args = parse_args()
    files = [to_repo_path(f) for f in args.files]
    os.chdir(run_test.PROJECT_ROOT)  # tests open files relative to the repo root
    files = files or find_test_files()
    module_name = resolve_lua_module(args.lua)

    started = time.perf_counter()
    failed = []
    for test_path, error in run_all(files, module_name, args.jobs, args.timeout):
        if error is not None:
            failed.append(test_path)
            print(f"FAIL {test_path}\n{error}", file=sys.stderr)
    elapsed = time.perf_counter() - started

    print(f"{len(files)} files, {len(failed)} failed ({elapsed:.1f}s, {module_name}, jobs={args.jobs})")
    for test_path in failed:
        print(f"  FAIL {test_path}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
