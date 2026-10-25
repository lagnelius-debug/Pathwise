local addonName, Pathwise = ...

-- Talent window highlight: a pulsing gold glow on the talent the advisor
-- recommends for the next point (Talents:GetNextPoint), and on its tree's
-- tab while another tree is shown. Hovering the talent adds a Pathwise line
-- to its tooltip.
--
-- The talent window (Blizzard_TalentUI) loads on demand, so this waits for
-- it. Classic Era names it TalentFrame (buttons TalentFrameTalent1..N, tabs
-- TalentFrameTab1..3, refreshed by TalentFrame_Update); later Classic
-- flavors use PlayerTalentFrame. Both are checked at runtime. Button N shows
-- talent N of the selected tree (GetTalentInfo order).

local L = Pathwise.L

local TalentHighlight = Pathwise:NewModule("TalentHighlight")

local TALENT_ADDON = "Blizzard_TalentUI"
local FRAME_NAMES = { "TalentFrame", "PlayerTalentFrame" }
local MAX_BUTTONS = 40
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GOLD = { 1, 0.82, 0.1 }

local talentFrame, frameName
local glow, tabGlow
local glowButton -- the button the glow is on, for the tooltip line
local hookedButtons = {}

local function Pulse(frame)
  if not frame.CreateAnimationGroup then
    return
  end
  local group = frame:CreateAnimationGroup()
  if not group then
    return
  end
  group:SetLooping("BOUNCE")
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.35)
  fade:SetDuration(0.7)
  group:Play()
end

-- A glow frame: the action-button border texture, gold, additive.
local function CreateGlow(scale)
  local frame = CreateFrame("Frame", nil, talentFrame)
  local texture = frame:CreateTexture(nil, "OVERLAY")
  texture:SetTexture(GLOW_TEXTURE)
  texture:SetBlendMode("ADD")
  texture:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
  texture:SetAllPoints(frame)
  frame.scale = scale
  frame:Hide()
  Pulse(frame)
  return frame
end

local function PlaceGlow(frame, target)
  frame:SetParent(target)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", target, "CENTER", 0, 0)
  frame:SetSize(target:GetWidth() * frame.scale, target:GetHeight() * frame.scale)
  frame:SetFrameLevel(target:GetFrameLevel() + 2)
  frame:Show()
end

local function SelectedTab()
  if PanelTemplates_GetSelectedTab then
    local tab = PanelTemplates_GetSelectedTab(talentFrame)
    if tab then
      return tab
    end
  end
  return talentFrame.selectedTab or 1
end

local function OnButtonEnter(button)
  if button ~= glowButton then
    return
  end
  local point = Pathwise:GetModule("Talents"):GetNextPoint()
  if point then
    GameTooltip:AddLine("Pathwise: " .. string.format(L.TALENT_HIGHLIGHT_TOOLTIP, point.rank, point.maxRank), 0.2, 1, 0.2, true)
    GameTooltip:Show()
  end
end

function TalentHighlight:Update()
  if not talentFrame then
    return
  end
  glow:Hide()
  tabGlow:Hide()
  glowButton = nil
  local point = Pathwise:GetModule("Talents"):GetNextPoint()
  if not point or not talentFrame:IsShown() then
    return
  end
  if SelectedTab() == point.tab then
    local button = _G[frameName .. "Talent" .. point.index]
    if button and button:IsShown() then
      glowButton = button
      PlaceGlow(glow, button)
    end
  else
    local tab = _G[frameName .. "Tab" .. point.tab]
    if tab then
      PlaceGlow(tabGlow, tab)
    end
  end
end

-- Sets up once the talent window exists. Returns true when it did.
local function Attach()
  if talentFrame then
    return true
  end
  for _, name in ipairs(FRAME_NAMES) do
    if _G[name] then
      talentFrame, frameName = _G[name], name
      break
    end
  end
  if not talentFrame then
    return false
  end
  glow = CreateGlow(1.8)
  tabGlow = CreateGlow(1.3)
  local function Refresh()
    TalentHighlight:Update()
  end
  local updateName = frameName .. "_Update"
  if type(_G[updateName]) == "function" then
    hooksecurefunc(updateName, Refresh)
  end
  talentFrame:HookScript("OnShow", Refresh)
  for i = 1, MAX_BUTTONS do
    local button = _G[frameName .. "Talent" .. i]
    if button and not hookedButtons[button] then
      hookedButtons[button] = true
      button:HookScript("OnEnter", OnButtonEnter)
    end
  end
  TalentHighlight:Debugf("Talent highlight attached to %s.", frameName)
  return true
end

function TalentHighlight:OnAddonLoaded(_, name)
  if name == TALENT_ADDON and Attach() then
    self:UnregisterEvent("ADDON_LOADED")
    self:Update()
  end
end

function TalentHighlight:OnAdviceUpdated()
  self:Update()
end

function TalentHighlight:OnInitialize()
  self:RegisterCallback("TALENT_ADVICE_UPDATED", "OnAdviceUpdated")
end

function TalentHighlight:OnEnable()
  if not Attach() then
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
  end
end
