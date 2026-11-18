-- Steering.lua: behaviour checks, plus equivalence with the original inline code from Navigator.lua (v0.5).
return function(H, check)
    local ns = H.ns
    H.load("Steering.lua")
    local S = ns.Steering

    -- Reference: the original Steer() decision code, verbatim apart from state passed in/out.
    local function reference(targets, index, px, py, facing, nx, ny, wx, wy, st, now)
        local LOOKAHEAD, END_RADIUS, EXACT_RADIUS = 7, 1.5, 1.5
        local TURN_DEADBAND, TURN_STEP, WALK_CONE, NEAR_CONE, NEAR = math.rad(4), math.rad(10), math.rad(50), math.rad(25), 6
        local STUCK_WINDOW, STUCK_MOVE, STUCK_LIMIT = 1, 1, 4
        local target, vx, vy, d
        while true do
            target = targets[index]
            vx, vy = target.x - px, target.y - py
            d = math.sqrt(vx * vx + vy * vy)
            if target.final then
                if d <= END_RADIUS then return "arrived" end
                break
            end
            if d > (target.exact and EXACT_RADIUS or LOOKAHEAD) then break end
            index, st.count, st.x = index + 1, 0, nil
        end
        local bearing = math.atan2(vx * wx + vy * wy, vx * nx + vy * ny)
        local err = (bearing - facing + math.pi) % (2 * math.pi) - math.pi
        local absErr = math.abs(err)
        local strength = absErr < TURN_DEADBAND and 0 or math.min(3, 1 + math.floor((absErr - TURN_DEADBAND) / TURN_STEP))
        local turnLevel = err > 0 and strength or -strength
        local walk = absErr < (d < NEAR and NEAR_CONE or WALK_CONE)
        local jump = false
        if walk then
            if not st.x then
                st.x, st.y, st.t = px, py, now
            elseif now - st.t >= STUCK_WINDOW then
                if math.sqrt((px - st.x) ^ 2 + (py - st.y) ^ 2) < STUCK_MOVE then
                    st.count = st.count + 1
                    if st.count >= STUCK_LIMIT then return "giveup" end
                    jump = true
                end
                st.x, st.y, st.t = px, py, now
            end
        else
            st.x = nil
        end
        return jump and "jump" or walk and "walk" or "steer", turnLevel, index
    end

    local function candidate(targets, index, px, py, facing, nx, ny, wx, wy, tracker, now)
        local idx, _, vx, vy, d, arrived = S.Advance(targets, index, px, py)
        if idx ~= index then tracker.Reset() end
        if arrived then return "arrived" end
        local err = S.HeadingError(vx, vy, facing, nx, ny, wx, wy)
        local turnLevel, walk = S.Command(err, d)
        local jump = false
        if walk then
            local status = tracker.Update(px, py, now)
            if status == "giveup" then return "giveup" end
            jump = status == "stuck"
        else
            tracker.Pause()
        end
        return jump and "jump" or walk and "walk" or "steer", turnLevel, idx
    end

    -- Random routes and walkers; both implementations run side by side, including state over time.
    math.randomseed(12345)
    local mismatches, runs = 0, 0
    for _ = 1, 300 do
        local exact = math.random() < 0.5
        local targets = {}
        local x, y = 0, 0
        for i = 1, math.random(2, 12) do
            x, y = x + math.random(-30, 30), y + math.random(-30, 30)
            targets[i] = { x = x, y = y, exact = exact }
        end
        targets[#targets].final = true
        -- map axes: north/west as unit vectors, possibly rotated
        local rot = math.random() * 2 * math.pi
        local nx, ny, wx, wy = math.cos(rot), math.sin(rot), -math.sin(rot), math.cos(rot)
        local st, tracker = { count = 0 }, S.NewStuckTracker()
        local index, idx2 = 1, 1
        local px, py, facing, now = 0, 0, math.random() * 2 * math.pi, 0
        for _ = 1, 120 do
            now = now + 0.03 * math.random(1, 12)           -- irregular ticks, some long enough to cross the stuck window
            if math.random() < 0.7 then                     -- usually progress, sometimes stand still
                px, py = px + math.random(-3, 3) * 0.5, py + math.random(-3, 3) * 0.5
            end
            facing = (facing + (math.random() - 0.5) * 0.8) % (2 * math.pi)
            local a1, a2, a3 = reference(targets, index, px, py, facing, nx, ny, wx, wy, st, now)
            local b1, b2, b3 = candidate(targets, idx2, px, py, facing, nx, ny, wx, wy, tracker, now)
            runs = runs + 1
            if a1 ~= b1 or a2 ~= b2 or a3 ~= b3 then mismatches = mismatches + 1 end
            if a1 == "arrived" or a1 == "giveup" then break end
            index, idx2 = a3, b3
        end
    end
    check("steering matches original (" .. runs .. " ticks)", mismatches == 0, mismatches .. " mismatches")

    -- Behaviour, spelled out.
    local function approx(a, b) return math.abs(a - b) < 1e-9 end
    check("facing the target: no turn, walk", (function() local t, w = S.Command(0, 50) return t == 0 and w end)())
    check("inside deadband: no turn", S.Command(math.rad(3), 50) == 0)
    check("left error turns left", S.Command(math.rad(20), 50) > 0)
    check("right error turns right", S.Command(-math.rad(20), 50) < 0)
    check("turn strength capped at 3", S.Command(math.rad(120), 50) == 3)
    check("far off: turn in place", select(2, S.Command(math.rad(80), 50)) == false)
    check("tighter cone when near", select(2, S.Command(math.rad(40), 3)) == false and select(2, S.Command(math.rad(40), 20)) == true)
    check("north faces north", approx(S.HeadingError(0, 1, 0, 0, 1, -1, 0), 0))
    check("target west of a north-facing player is to the left", S.HeadingError(-1, 0, 0, 0, 1, -1, 0) > 0)

    local line = { { x = 0, y = 5 }, { x = 0, y = 30 }, { x = 0, y = 60, final = true } }
    local i, _, _, _, _, arrived = S.Advance(line, 1, 0, 0)
    check("skips a point closer than the lookahead", i == 2 and not arrived, i)
    local _, _, _, _, _, done = S.Advance(line, 3, 0, 59)
    check("arrives within END_RADIUS", done == true)
    local exactLine = { { x = 0, y = 5, exact = true }, { x = 0, y = 60, final = true } }
    check("an exact point is not skipped at lookahead range", S.Advance(exactLine, 1, 0, 0) == 1)
    check("an exact point is skipped once reached", S.Advance(exactLine, 1, 0, 4.5) == 2)

    local tr = S.NewStuckTracker()
    check("first tick ok", tr.Update(0, 0, 0) == "ok")
    check("progress ok", tr.Update(5, 0, 1.1) == "ok")
    check("no progress: stuck", tr.Update(5, 0, 2.2) == "stuck")
    check("window not elapsed: ok", tr.Update(5, 0, 2.5) == "ok")
    tr.Update(5, 0, 3.3) tr.Update(5, 0, 4.4)
    check("fourth stuck window gives up", tr.Update(5, 0, 5.5) == "giveup", tr.count)
    tr.Reset()
    check("reset forgets the count", tr.count == 0 and tr.Update(0, 0, 10) == "ok")
end
