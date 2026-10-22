local addonName, Pathwise = ...

-- Navigation arrow: rotates towards the current waypoint (see
-- Core/Waypoints.lua) and shows the label and distance. Drag to move,
-- right-click to clear a manual waypoint (or turn off auto-follow).

local L = Pathwise.L

local Arrow = Pathwise:NewModule("Arrow")

local UPDATE_INTERVAL = 0.05
local ARROW_TEXTURE = "Interface\\Minimap\\MinimapArrow"
-- Within this angle (radians) of straight ahead the arrow turns green.
local ON_COURSE = 0.25

local frame, elapsedSinceUpdate = nil, 0

local function GetWaypoints()
  return Pathwise:GetModule("Waypoints")
end

local function SavePosition()
  local point, _, relativePoint, x, y = frame:GetPoint()
  local saved = Pathwise.db.arrow
  saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function RestorePosition()
  local saved = Pathwise.db.arrow
  frame:ClearAllPoints()
  if saved.point then
    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -110)
  end
end

function Arrow:Update()
  local Waypoints = GetWaypoints()
  local target = Waypoints:GetTarget()
  if not target then
    frame:Hide()
    return
  end
  frame.label:SetText(target.label or "")

  local distance, relative = Waypoints:GetDirection()
  if not distance then
    -- No position (instance) or the target is on another continent.
    frame.arrow:Hide()
    frame.distance:SetText(L.ARROW_UNKNOWN)
    return
  end

  if distance <= Waypoints.ARRIVE_YARDS then
    frame.arrow:Hide()
    frame.distance:SetText(L.ARROW_HERE)
    Waypoints:OnArrived()
    return
  end

  frame.distance:SetText(string.format(L.ARROW_YARDS, distance))
  if relative and frame.arrow.SetRotation then
    frame.arrow:SetRotation(relative)
    local offCourse = math.min(relative, 2 * math.pi - relative)
    if offCourse <= ON_COURSE then
      frame.arrow:SetVertexColor(0.2, 1, 0.2)
    else
      frame.arrow:SetVertexColor(1, 0.85, 0.2)
    end
    frame.arrow:Show()
  else
    frame.arrow:Hide()
  end
end

local function OnUpdate(_, elapsed)
  elapsedSinceUpdate = elapsedSinceUpdate + elapsed
  if elapsedSinceUpdate >= UPDATE_INTERVAL then
    elapsedSinceUpdate = 0
    Arrow:Update()
  end
end

local function OnMouseUp(_, button)
  if button ~= "RightButton" then
    return
  end
  local Waypoints = GetWaypoints()
  local _, kind = Waypoints:GetTarget()
  if kind == "manual" then
    Waypoints:ClearManual()
  else
    Pathwise.db.arrowAuto = false
    Pathwise:Print(L.ARROW_AUTO_OFF)
    Pathwise:FireCallback("WAYPOINT_CHANGED", nil)
  end
end

local function CreateArrow()
  frame = CreateFrame("Frame", "PathwiseArrow", UIParent)
  frame:SetSize(120, 92)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
  end)
  frame:SetScript("OnMouseUp", OnMouseUp)
  frame:SetScript("OnUpdate", OnUpdate)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L.ARROW_TOOLTIP_TITLE)
    GameTooltip:AddLine(L.ARROW_TOOLTIP_HELP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.arrow = frame:CreateTexture(nil, "ARTWORK")
  frame.arrow:SetTexture(ARROW_TEXTURE)
  frame.arrow:SetSize(52, 52)
  frame.arrow:SetPoint("TOP", frame, "TOP", 0, 0)

  frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.label:SetPoint("TOP", frame.arrow, "BOTTOM", 0, -2)
  frame.label:SetWidth(200)

  frame.distance = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.distance:SetPoint("TOP", frame.label, "BOTTOM", 0, -2)

  RestorePosition()
  frame:Hide()
end

function Arrow:OnWaypointChanged(_, target)
  if target then
    frame:Show()
    self:Update()
  else
    frame:Hide()
  end
end

function Arrow:OnInitialize()
  CreateArrow()
  self:RegisterCallback("WAYPOINT_CHANGED", "OnWaypointChanged")
end

function Arrow:OnEnable()
  if GetWaypoints():GetTarget() then
    frame:Show()
  end
end
