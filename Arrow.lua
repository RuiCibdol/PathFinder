local _, ns = ...

---------------------------------------------------------------------------
-- The GPS arrow: while travelling, an arrow on screen that points where to
-- go (relative to the way you face, like a car's navigation) with the
-- yards to the next point and a word for it: ahead / left / right / behind.
-- Drag it to move it (remembered). Navigator.Guidance() supplies the numbers.
---------------------------------------------------------------------------

local TICK = 0.03
local TEXTURE = "Interface\\Minimap\\ROTATING-MINIMAPARROW"   -- points up

local frame = CreateFrame("Frame", "PathFinderArrow", UIParent)
frame:SetSize(64, 64)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

local arrow = frame:CreateTexture(nil, "ARTWORK")
arrow:SetAllPoints()
arrow:SetTexture(TEXTURE)
arrow:SetVertexColor(0.2, 1, 0.3)

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
label:SetPoint("TOP", frame, "BOTTOM", 0, -2)

local function Place()
    frame:ClearAllPoints()
    local p = ns.db.hud.arrowPoint
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end
ns.OnInit(Place)

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.hud.arrowPoint = { point, relPoint, x, y }
end)

local since = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    since = since + elapsed
    if since < TICK then return end
    since = 0
    local err, yards = ns.Navigator.Guidance()
    if not err or not ns.db.options.arrow then self:Hide() return end
    arrow:SetRotation(err)      -- positive turns counter-clockwise: the target is to your left
    local hint = ns.Steering.Hint(err)
    label:SetText(format("%d yd  %s", yards or 0, hint))
    self:Show()
end)
