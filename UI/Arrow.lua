local addonName, Pathwise = ...

-- Navigation arrow: rotates towards the current waypoint (see
-- Core/Waypoints.lua) and shows the label and distance. Drag to move,
-- right-click to clear a manual waypoint (or turn off auto-follow).
-- Spawn spots of quest mobs get no distance: the mob is only somewhere
-- around there, so a number would be misleading. Objects (a moonwell, a
-- herb) stay where they are, so they keep it.

local L = Pathwise.L

local Arrow = Pathwise:NewModule("Arrow")

local UPDATE_INTERVAL = 0.05

-- 3D arrow: a sprite sheet of 64 pre-rendered rotations (8x8 grid, frame k
-- turned k * 360/64 degrees counterclockwise; tools/render_arrow.py). The
-- frame for the direction is picked with SetTexCoord - rotating one flat
-- image can't show the arrow's sides and tilt.
local ARROW_TEXTURE = "Interface\\AddOns\\" .. addonName .. "\\Media\\Arrow\\arrow3d"
local SHEET_COLUMNS = 8
local SHEET_FRAMES = SHEET_COLUMNS * SHEET_COLUMNS
local ARROW_SIZE = 64

-- Within this angle (radians) of straight ahead the arrow is fully green;
-- beyond it the color goes through yellow (to the side) to red (behind).
local ON_COURSE = 0.25
local GREEN, YELLOW, RED = { 0.2, 1, 0.2 }, { 1, 0.85, 0.2 }, { 1, 0.25, 0.2 }
-- The "Next" link: soft gold, brighter on hover.
local NEXT_DIM, NEXT_BRIGHT = { 0.85, 0.75, 0.5, 0.75 }, { 1, 0.85, 0.4 }

local frame, elapsedSinceUpdate = nil, 0

-- Shows the sprite sheet frame for `relative` (radians counterclockwise,
-- 0 = straight ahead).
local function SetDirection(texture, relative)
  local index = math.floor(relative / (2 * math.pi) * SHEET_FRAMES + 0.5) % SHEET_FRAMES
  local column, row = index % SHEET_COLUMNS, math.floor(index / SHEET_COLUMNS)
  texture:SetTexCoord(column / SHEET_COLUMNS, (column + 1) / SHEET_COLUMNS,
    row / SHEET_COLUMNS, (row + 1) / SHEET_COLUMNS)
end

local function Mix(a, b, t)
  return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Green when on course, yellow at 90 degrees off, red when it's behind you.
function Arrow.CourseColor(offCourse)
  if offCourse <= ON_COURSE then
    return GREEN[1], GREEN[2], GREEN[3]
  elseif offCourse <= math.pi / 2 then
    return Mix(GREEN, YELLOW, (offCourse - ON_COURSE) / (math.pi / 2 - ON_COURSE))
  end
  return Mix(YELLOW, RED, (offCourse - math.pi / 2) / (math.pi / 2))
end

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
  local distance, relative, via = Waypoints:GetDirection()
  if via then
    -- A portal or boat first: say which, with the destination underneath.
    frame.label:SetText((via.text or L[via.label]) .. "\n" .. string.format(L.TRAVEL_THEN, target.label or ""))
  else
    frame.label:SetText(target.label or "")
  end
  if not distance then
    -- No position (instance) or the target is on another continent.
    frame.arrow:Hide()
    frame.distance:SetText(L.ARROW_UNKNOWN)
    return
  end

  local roaming = not via and target.spawn and target.npcName ~= nil and not target.vendor -- a mob's spawn spot
  if via then
    -- On the way: no arrival here (the portal moves the player on).
    if distance <= Waypoints.ARRIVE_YARDS then
      frame.arrow:Hide()
      frame.distance:SetText(L.TRAVEL_HERE)
      return
    end
  elseif distance <= Waypoints.ARRIVE_YARDS then
    frame.arrow:Hide()
    frame.distance:SetText(roaming and L.ARROW_SPAWN_HERE or L.ARROW_HERE)
    Waypoints:OnArrived()
    return
  end

  frame.distance:SetText(roaming and "" or Pathwise.FormatDistance(distance))
  if relative then
    SetDirection(frame.arrow, relative)
    frame.arrow:SetVertexColor(Arrow.CourseColor(math.min(relative, 2 * math.pi - relative)))
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
  if button == "RightButton" then
    GetWaypoints():Next()
  end
end

local function CreateArrow()
  frame = CreateFrame("Frame", "PathwiseArrow", UIParent)
  frame:SetSize(120, 128)
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
  frame.arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
  frame.arrow:SetPoint("TOP", frame, "TOP", 0, 0)

  frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.label:SetPoint("TOP", frame.arrow, "BOTTOM", 0, -2)
  frame.label:SetWidth(200)

  frame.distance = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.distance:SetPoint("TOP", frame.label, "BOTTOM", 0, -2)

  -- "Next »": the mob/node isn't there, or the player wants another step.
  -- Same as right-clicking the arrow, /pw next or the key binding. Just a
  -- small, dim text link under the distance; brighter and underlined on
  -- hover.
  local next = CreateFrame("Button", nil, frame)
  next.text = next:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  next.text:SetPoint("CENTER", next, "CENTER", 0, 1)
  next.text:SetText(L.ARROW_NEXT_BUTTON)
  next.text:SetTextColor(NEXT_DIM[1], NEXT_DIM[2], NEXT_DIM[3], NEXT_DIM[4])
  next:SetSize(next.text:GetStringWidth() + 12, 16)
  next:SetPoint("TOP", frame.distance, "BOTTOM", 0, -3)
  next.underline = next:CreateTexture(nil, "ARTWORK")
  next.underline:SetColorTexture(NEXT_BRIGHT[1], NEXT_BRIGHT[2], NEXT_BRIGHT[3], 0.6)
  next.underline:SetHeight(1)
  next.underline:SetPoint("BOTTOMLEFT", next, "BOTTOMLEFT", 5, 1)
  next.underline:SetPoint("BOTTOMRIGHT", next, "BOTTOMRIGHT", -5, 1)
  next.underline:Hide()
  next:SetScript("OnClick", function()
    GetWaypoints():Next()
  end)
  next:SetScript("OnEnter", function(self)
    self.text:SetTextColor(NEXT_BRIGHT[1], NEXT_BRIGHT[2], NEXT_BRIGHT[3], 1)
    self.underline:Show()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L.ARROW_NEXT_TOOLTIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  next:SetScript("OnLeave", function(self)
    self.text:SetTextColor(NEXT_DIM[1], NEXT_DIM[2], NEXT_DIM[3], NEXT_DIM[4])
    self.underline:Hide()
    GameTooltip:Hide()
  end)
  frame.next = next

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
