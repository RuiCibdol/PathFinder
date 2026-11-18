"""Runs tests/run.lua with lupa (pip install lupa) when no system Lua is installed. Run from the repo root."""
import sys
from lupa import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("os.exit = function(code) error('EXIT:' .. tostring(code), 0) end")
try:
    L.execute(open("tests/run.lua", encoding="utf-8").read())
except Exception as e:
    msg = str(e)
    sys.exit(int(msg.split("EXIT:")[1][0]) if "EXIT:" in msg else (print(msg) or 2))
