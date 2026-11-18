# PathFinder: redesign notes

Status after v0.6.0. Nothing here has been run in the game (no AutoHotkey / game session available when this was written); the pure-Lua parts are covered by `tests/`.

## Done in 0.6.0
- Targets the current `_forever_` client (build 1.60.x, Interface 16001): default AHK path, README, and `install.ps1` that finds the client.
- `Graph.Distances` is now a binary-heap Dijkstra; `ShortestPath` stops once the target is settled. Verified against a brute-force reference on a shipped map.
- **Steering split out of `Navigator.lua`** into `Steering.lua`: target selection, heading error, turn/walk command and stuck detection are now plain functions. A test replays the original v0.5 inline logic against the new module over ~36,000 random ticks (identical results; a deliberately altered constant makes it fail), so the refactor keeps behaviour. `Navigator.lua` keeps the route, the command dot and the key watch.
- `tests/` (map format round trip, link symmetry, graph routing), run with `python tests/run.py` or `lua tests/run.lua`.
- README: "editing existing maps" was already implemented (Load map -> Save map keeps your own copy); the stale todo is replaced by a how-to.

## What stays
- Lua steers, AHK presses keys. Addons can't send input, so an external helper is unavoidable.
- One text string per navigation map (`PF1~...`): plain data, safe to share.

## Proposed next (needs in-game testing)
1. **Route building** (`Travel` in `Navigator.lua`: nearest point, path, curve rounding) can move out the same way and get tests.
2. **Protocol check on the command dot.** Lua and `PathFinder.ahk` must agree on dot size, position and levels; a version signal would make a mismatch fail loudly instead of misreading.
3. **Danger-aware routing.** Edge cost currently ignores map kind; weight Dangerous maps higher when a route could use either.
4. **Community maps.** `Maps/Community.lua` ships one map (Thousand Needles). More maps help users most; per-line validation already exists in `ns.AddMapString`.

## Not planned
Anything aimed at hiding the addon from the game or from Blizzard. The README's ToS warning stands: this automates movement and risks the account.
