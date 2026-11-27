"""Runs the MouseShift checks under Lua 5.1, the version the game uses.

Usage, from the repository root:
    pip install lupa
    python tests/run.py

Checks the syntax of every addon file, then runs tests/run.lua.
"""

import glob
import sys

import lupa.lua51 as lua51

runtime = lua51.LuaRuntime()
check_syntax = runtime.eval(
    'function(source, name) local ok, err = loadstring(source, name) return err end'
)

failed = False
for path in sorted(glob.glob("*.lua")):
    with open(path, encoding="utf-8") as handle:
        error = check_syntax(handle.read(), "@" + path)
    if error:
        print("syntax error:", error)
        failed = True
    else:
        print("syntax ok   ", path)
if failed:
    sys.exit(1)

# tests/run.lua calls os.exit(1) when a test fails.
runtime.execute('dofile("tests/run.lua")')
