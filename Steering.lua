local _, ns = ...

---------------------------------------------------------------------------
-- The steering decisions, as plain functions of numbers: no frames, no game
-- calls, so they can be tested outside the game (tests/run.lua).
-- Navigator.lua owns the route and the command dot, and calls these each tick.
--
--   Advance          which target to steer at (skips points passed or close by)
--   HeadingError     how far, and which way, to turn: radians, > 0 = target is left
--   Command          error + distance -> turn level (-3 hard right .. 3 hard left) and walk or not
--   NewStuckTracker  notices walking that makes no progress
---------------------------------------------------------------------------

local Steering = {}
ns.Steering = Steering

Steering.LOOKAHEAD = 7                      -- yards: steer at the first step at least this far ahead, so small bends don't make it turn
Steering.END_RADIUS = 1.5                   -- yards: this close to the pin, done
Steering.EXACT_RADIUS = 1.5                 -- yards: this close to a point of an exact map before heading for the next
Steering.TURN_DEADBAND = math.rad(4)        -- heading error left alone
Steering.TURN_STEP = math.rad(10)           -- each this much more error is one more level of turn strength (1-3)
Steering.WALK_CONE = math.rad(50)           -- walk while the error is under this, else turn in place
Steering.NEAR_CONE = math.rad(25)           -- tighter cone close to a target, so it doesn't circle it
Steering.NEAR = 6                           -- yards
Steering.STUCK_WINDOW = 1                   -- seconds of walking to check progress over
Steering.STUCK_MOVE = 1                     -- yards: less than this in a window counts as stuck
Steering.STUCK_LIMIT = 4                    -- stuck windows on one leg before giving up

-- Steer at the first target from `index` that is at least LOOKAHEAD away (an exact point must be
-- reached, within EXACT_RADIUS) or the final one, skipping targets passed or close by, so the
-- heading changes smoothly instead of with every small step of a curve.
-- Returns index, target, dx, dy, distance, arrived (the final target is within END_RADIUS).
function Steering.Advance(targets, index, px, py)
    while true do
        local target = targets[index]
        local vx, vy = target.x - px, target.y - py
        local d = math.sqrt(vx * vx + vy * vy)
        if target.final then
            return index, target, vx, vy, d, d <= Steering.END_RADIUS
        end
        if d > (target.exact and Steering.EXACT_RADIUS or Steering.LOOKAHEAD) then
            return index, target, vx, vy, d, false
        end
        index = index + 1
    end
end

-- Radians to turn to face (vx, vy) from `facing`, in -pi..pi. > 0 = to the left. (nx, ny) and
-- (wx, wy) are the map's north and west axes in world coordinates; facing is the bearing from
-- north, counter-clockwise like GetPlayerFacing.
function Steering.HeadingError(vx, vy, facing, nx, ny, wx, wy)
    local bearing = math.atan2(vx * wx + vy * wy, vx * nx + vy * ny)
    return (bearing - facing + math.pi) % (2 * math.pi) - math.pi
end

-- How hard to turn (0 inside the deadband, then 1-3 as the error grows; positive is left) and
-- whether to walk meanwhile (error inside the cone, a tighter one when `distance` is near).
function Steering.Command(err, distance)
    local absErr = math.abs(err)
    local strength = absErr < Steering.TURN_DEADBAND and 0
        or math.min(3, 1 + math.floor((absErr - Steering.TURN_DEADBAND) / Steering.TURN_STEP))
    local turnLevel = err > 0 and strength or -strength
    local walk = absErr < (distance < Steering.NEAR and Steering.NEAR_CONE or Steering.WALK_CONE)
    return turnLevel, walk
end

-- Plain words for a heading error, for the GPS arrow: "ahead", "left", "right" or "behind".
function Steering.Hint(err)
    local a = math.abs(err)
    if a < math.rad(15) then return "ahead" end
    if a > math.rad(150) then return "behind" end
    return err > 0 and "left" or "right"
end

-- Watches walking for progress. Update(px, py, now) while walking returns "ok", "stuck" (less than
-- STUCK_MOVE yards over the last STUCK_WINDOW seconds: time to jump) or "giveup" (STUCK_LIMIT
-- stuck windows in a row on one leg). Pause() when not walking (progress is measured from the
-- next walking tick); Reset() on a new leg or route (also forgets the stuck count).
function Steering.NewStuckTracker()
    local t = { count = 0 }
    local x, y, since

    function t.Reset() x, y, since, t.count = nil, nil, nil, 0 end
    function t.Pause() x = nil end
    function t.Update(px, py, now)
        if not x then
            x, y, since = px, py, now
            return "ok"
        end
        if now - since < Steering.STUCK_WINDOW then return "ok" end
        local moved = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
        x, y, since = px, py, now
        if moved >= Steering.STUCK_MOVE then return "ok" end
        t.count = t.count + 1
        return t.count >= Steering.STUCK_LIMIT and "giveup" or "stuck"
    end
    return t
end
