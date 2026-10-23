local addonName, Pathwise = ...

-- Minimap button: left-click shows/hides the To-do window, right-click opens
-- the settings, drag moves it around the minimap's edge. Its angle and
-- visibility are saved (PathwiseDB.minimap). Built without libraries
-- (no LibDBIcon), following PATHWISE_DESIGN.md.

local L = Pathwise.L

local MinimapButton = Pathwise:NewModule("MinimapButton")

local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local RADIUS_OFFSET = 10 -- from the minimap's edge, outward

local button

-- Places the button on a circle around the minimap at `angle` degrees
-- (0 = right, 90 = top).
local function Place(angle)
  local radius = Minimap:GetWidth() / 2 + RADIUS_OFFSET
  local radians = math.rad(angle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

-- While dragging: angle from the minimap's center to the cursor.
local function OnDragUpdate()
  local cursorX, cursorY = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local centerX, centerY = Minimap:GetCenter()
  local angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
  Pathwise.db.minimap.angle = angle
  Place(angle)
end

local function CreateButton()
  button = CreateFrame("Button", "PathwiseMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  -- The usual minimap button look: round background, icon, gold ring.
  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(20, 20)
  background:SetPoint("CENTER", button, "CENTER", 0, 1)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", button, "CENTER", 0, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      Pathwise:GetModule("SettingsPanel"):Open()
    else
      Pathwise:GetModule("NextStepsFrame"):Toggle()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Pathwise")
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

function MinimapButton:Update()
  local saved = Pathwise.db.minimap
  Place(saved.angle)
  button:SetShown(not saved.hide and Pathwise:IsModuleEnabled("MinimapButton"))
end

-- /pw reset replaced the saved settings: re-place the button and let the
-- settings checkbox follow.
function MinimapButton:OnSettingsReset()
  self:Update()
  Pathwise:FireCallback("MINIMAP_BUTTON_CHANGED", not Pathwise.db.minimap.hide)
end

function MinimapButton:SetShown(shown)
  Pathwise.db.minimap.hide = not shown
  self:Update()
  Pathwise:FireCallback("MINIMAP_BUTTON_CHANGED", shown)
end

function MinimapButton:OnInitialize()
  if not Minimap then
    return
  end
  CreateButton()
  -- Saved variables are loaded: show it at its saved spot right away.
  self:Update()
  self:RegisterCallback("SETTINGS_RESET", "OnSettingsReset")
end

-- /pw minimap: show or hide the button.
Pathwise:RegisterCommand("minimap", function()
  if not button then
    return
  end
  local shown = Pathwise.db.minimap.hide
  MinimapButton:SetShown(shown)
  Pathwise:Print(shown and L.MINIMAP_SHOWN or L.MINIMAP_HIDDEN)
end, L.CMD_MINIMAP)
