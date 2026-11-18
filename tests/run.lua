-- Run from the repo root:  lua tests/run.lua   (or tests/run.py, which uses lupa)
local H = dofile("tests/harness.lua")
local ns = H.ns
H.load("Graph.lua")
H.load("Maps.lua")
H.load("Maps/Community.lua")

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1 else failed = failed + 1 print("FAIL: " .. name .. (detail and (" - " .. tostring(detail)) or "")) end
end

-- Shipped maps decode, links are two-way, ids are unique.
local count = 0
for i = 1, 50 do
    local m = ns.Maps.Find("b:" .. i)
    if not m then break end
    count = count + 1
    check(m.name .. " has points", next(m.nodes) ~= nil)
    for id, node in pairs(m.nodes) do
        for other in pairs(node.links) do
            check(m.name .. " link " .. id .. "-" .. other .. " is two-way", m.nodes[other] and m.nodes[other].links[id])
        end
    end
    -- Round trip: encode, decode, encode again is stable.
    local text = ns.Maps.Encode(m)
    local back = assert(ns.Maps.Decode(text))
    check(m.name .. " round trip", ns.Maps.Encode(back) == text)
end
check("at least one built-in map", count >= 1, count)

-- Decode rejects junk.
check("junk rejected", ns.Maps.Decode("hello") == nil)
check("damaged points rejected", ns.Maps.Decode("PF1~a~safe~1~Z~x,y") == nil)

-- Graph: shortest path on a hand-made map.
local map = { nodes = {}, nextId = 1 }
ns.Graph.Use(map)
local a = ns.Graph.AddWorld(1, 0, 0)
local b = ns.Graph.AddWorld(1, 10, 0, a)
local c = ns.Graph.AddWorld(1, 10, 10, b)
local d = ns.Graph.AddWorld(1, 0, 10, c)
ns.Graph.Link(d, a)
local path = ns.Graph.ShortestPath(a, c)
check("shortest path length", path and #path == 3, path and #path)
local dist = ns.Graph.Distances(a)
check("distance to far corner", math.abs(dist[c] - 20) < 1e-9, dist[c])
-- Early exit gives the same distance as the full run.
local _, prevTo = ns.Graph.Distances(a, c)
check("early exit path", #ns.Graph.PathTo(prevTo, a, c) == 3)
-- Isolated node is unreachable.
local e = ns.Graph.AddWorld(1, 99, 99)
check("unreachable is nil", ns.Graph.ShortestPath(a, e) == nil)
-- Removing a chain-middle node rejoins its neighbours.
ns.Graph.Remove(b)
check("chain rejoined on remove", ns.Graph.Get(a).links[c] == true)
-- Links across continents are refused.
local f = ns.Graph.AddWorld(2, 0, 0)
check("cross-continent link refused", ns.Graph.Link(a, f) == false)

-- The heap Dijkstra agrees with a brute-force reference on a shipped map.
local big = ns.Maps.Find("b:1")
ns.Graph.Use(big)
local ids = {}
for id in pairs(big.nodes) do ids[#ids + 1] = id end
sort(ids)
local function reference(from)
    local dist, done = { [from] = 0 }, {}
    while true do
        local cur, cd
        for id, d in pairs(dist) do if not done[id] and (not cd or d < cd) then cur, cd = id, d end end
        if not cur then break end
        done[cur] = true
        for o in pairs(big.nodes[cur].links) do
            local d = cd + ns.Distance(big.nodes[cur].x, big.nodes[cur].y, big.nodes[o].x, big.nodes[o].y)
            if not dist[o] or d < dist[o] then dist[o] = d end
        end
    end
    return dist
end
local ref, got = reference(ids[1]), ns.Graph.Distances(ids[1])
local same = true
for id, d in pairs(ref) do if not got[id] or math.abs(got[id] - d) > 1e-6 then same = false end end
check("heap Dijkstra matches reference", same)

dofile("tests/steering_test.lua")(H, check)

print(format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
