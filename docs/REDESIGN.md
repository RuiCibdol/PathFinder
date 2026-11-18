# PathFinder: redesign notes

Status after v0.6.0. Nothing here has been run in the game (no AutoHotkey / game session available when this was written); the pure-Lua parts are covered by `tests/`.

## Done in 0.6.0
- Targets the current `_forever_` client (build 1.60.x, Interface 16001): default AHK path, README, and `install.ps1` that finds the client.
- `Graph.Distances` is now a binary-heap Dijkstra; `ShortestPath` stops once the target is settled. Verified against a brute-force reference on a shipped map.
- `tests/` (map format round trip, link symmetry, graph routing), run with `python tests/run.py` or `lua tests/run.lua`.
- README: "editing existing maps" was already implemented (Load map -> Save map keeps your own copy); the stale todo is replaced by a how-to.

## What stays
- Lua steers, AHK presses keys. Addons can't send input, so an external helper is unavoidable.
- One text string per navigation map (`PF1~...`): plain data, safe to share.

## Proposed next (needs in-game testing)
1. **Split `Navigator.lua` (416 lines)** into steering (heading error -> command), route following (legs, stuck handling) and the command-dot encoder, so the first two can be tested with plain Lua like the graph.
2. **Protocol check on the command dot.** Lua and `PathFinder.ahk` must agree on dot size, position and levels; a version signal would make a mismatch fail loudly instead of misreading.
3. **Danger-aware routing.** Edge cost currently ignores map kind; weight Dangerous maps higher when a route could use either.
4. **Community maps.** `Maps/Community.lua` ships one map (Thousand Needles). More maps help users most; per-line validation already exists in `ns.AddMapString`.

## Not planned
Anything aimed at hiding the addon from the game or from Blizzard. The README's ToS warning stands: this automates movement and risks the account.
