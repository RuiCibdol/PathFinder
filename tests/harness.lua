-- Plain-Lua stand-ins for the WoW globals, so Graph.lua / Maps.lua run outside the game.
-- WoW runs Lua 5.1 (math.atan2); newer Lua folded it into math.atan.
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
tinsert, tremove, sort, format = table.insert, table.remove, table.sort, string.format
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s)
    local out, pos = {}, 1
    while true do
        local i = s:find(sep, pos, true)
        if not i then out[#out + 1] = s:sub(pos) break end
        out[#out + 1] = s:sub(pos, i - 1)
        pos = i + #sep
    end
    return (table.unpack or unpack)(out)
end

local ns = { db = { maps = {}, nextMapId = 1 } }
function ns.Distance(x1, y1, x2, y2) return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) end
function ns.OnInit() end
function ns.MapToWorld() return nil end
function ns.WorldToMap() return nil end

local function load_addon_file(path)
    local f = assert(loadfile(path))
    f("PathFinder", ns)
end
return { ns = ns, load = load_addon_file }
