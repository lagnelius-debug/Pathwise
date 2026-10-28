local addonName, Pathwise = ...

-- Floating target button: shows up while the arrow points at the spawn of a
-- quest mob (kill or loot quests) and targets it when clicked - the same
-- /cleartarget + /targetexact lines and skull mark as the "Pathwise" target
-- macro (Core/TargetMacro.lua), without needing a macro slot or action bar.
--
-- It's a secure action button: targeting only works from a hardware click
-- on one. Secure frames can't be changed in combat, so a change during a
-- fight (new mob, hide/show) waits until it ends.

local L = Pathwise.L
local Platform = Pathwise.Platform

local TargetButton = Pathwise:NewModule("TargetButton")

local ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"
local SIZE = 36

local button
local pending = false

local function SavePosition()
  local point, _, relativePoint, x, y = button:GetPoint()
  local saved = Pathwise.db.targetButton
  saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function RestorePosition()
  local saved = Pathwise.db.targetButton
  button:ClearAllPoints()
  if saved.point then
    button:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
  else
    button:SetPoint("TOP", UIParent, "TOP", -40, -250)
  end
end

-- Mob names (the one to go for first leading, as in the macro) when the
-- arrow follows a quest mob, else nil. Turn-in NPCs and object spawns (no
-- names) get no button.
function TargetButton.GetMobNames()
  local target = Pathwise:GetModule("Waypoints"):GetTarget()
  if target and target.spawn and target.names and #target.names > 0 then
    return Pathwise:GetModule("TargetMacro").Ordered(target.names)
  end
end

local function CreateButton()
  button = CreateFrame("Button", "PathwiseTargetButton", UIParent, "SecureActionButtonTemplate")
  button:SetSize(SIZE, SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetClampedToScreen(true)
  -- Both: newer clients act on the down or the up click depending on the
  -- "ActionButtonUseKeyDown" setting; registering only one can do nothing.
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("type", "macro")
  button:SetAttribute("macrotext", "")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(button)
  icon:SetTexture(ICON)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetSize(SIZE * 1.7, SIZE * 1.7)
  border:SetPoint("CENTER", button, "CENTER", 0, 0)

  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.label:SetPoint("LEFT", button, "RIGHT", 6, 0)
  button.label:SetJustifyH("LEFT")

  button:SetMovable(true)
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnDragStart", function(self)
    if not Platform.InCombat() then
      self:StartMoving()
    end
  end)
  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Pathwise")
    GameTooltip:AddLine(string.format(L.TARGET_BUTTON_TOOLTIP, self.mobName or "?"), 1, 1, 1, true)
    GameTooltip:AddLine(L.TARGET_BUTTON_HELP, 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  RestorePosition()
  button:Hide()
end

function TargetButton:Update()
  if not button then
    return
  end
  if Platform.InCombat() then
    if not pending then
      pending = true
      self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
    end
    return
  end
  local names = Pathwise.db.targetButton.shown and TargetButton.GetMobNames()
  if not names then
    button:Hide()
    return
  end
  local body = Pathwise:GetModule("TargetMacro").BuildBody(names)
  if button:GetAttribute("macrotext") ~= body then
    button:SetAttribute("macrotext", body)
  end
  -- (As the macro groups them: "Crag Boar" for the Large ones too.)
  local groups = Pathwise:GetModule("TargetMacro").Groups(names)
  button.mobName = groups[1].name
  local label = #groups > 1 and string.format(L.TARGET_BUTTON_MORE, groups[1].name, #groups - 1) or groups[1].name
  button.label:SetText(string.format(L.TARGET_BUTTON_LABEL, label))
  button:Show()
end

function TargetButton:OnCombatEnded()
  pending = false
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  self:Update()
end

function TargetButton:SetShown(shown)
  Pathwise.db.targetButton.shown = shown
  self:Update()
  Pathwise:FireCallback("TARGET_BUTTON_CHANGED", shown)
end

function TargetButton:OnWaypointChanged()
  self:Update()
end

function TargetButton:OnSettingsReset()
  if Platform.InCombat() then
    -- Position can't change in combat either; the update after the fight
    -- shows/hides it, the saved default position applies after /reload.
    self:Update()
  else
    RestorePosition()
    self:Update()
  end
  Pathwise:FireCallback("TARGET_BUTTON_CHANGED", Pathwise.db.targetButton.shown)
end

function TargetButton:OnInitialize()
  CreateButton()
  self:RegisterCallback("WAYPOINT_CHANGED", "OnWaypointChanged")
  self:RegisterCallback("SETTINGS_RESET", "OnSettingsReset")
  -- (Several kinds of mobs: the label names the one the next click goes for.)
  self:RegisterCallback("TARGET_ORDER_CHANGED", "OnWaypointChanged")
end

function TargetButton:OnEnable()
  self:Update()
end

-- /pw targetbutton: turn the button on or off.
Pathwise:RegisterCommand("targetbutton", function()
  local shown = not Pathwise.db.targetButton.shown
  TargetButton:SetShown(shown)
  Pathwise:Print(shown and L.TARGET_BUTTON_SHOWN or L.TARGET_BUTTON_HIDDEN)
  if Platform.InCombat() then
    Pathwise:Print(L.TARGET_BUTTON_COMBAT)
  end
end, L.CMD_TARGET_BUTTON)
