local addonName, Pathwise = ...

-- The goal prompt: a small dialog with one button per goal (e.g. Leveling /
-- Beast Mastery / Marksmanship / Survival for a hunter). Shown once per
-- character by Core/Talents.lua, and again on /pw spec. Never shown during
-- combat; it waits until combat ends.

local L = Pathwise.L
local Platform = Pathwise.Platform

local GoalPrompt = Pathwise:NewModule("GoalPrompt")

local FRAME_WIDTH = 300
local BUTTON_WIDTH = 220
local BUTTON_HEIGHT = 24
local BUTTON_SPACING = 6
local BUTTONS_TOP = 80   -- distance from the top edge to the first button
local BOTTOM_PADDING = 52 -- room for the hint text below the buttons

local frame
local buttons = {}

local function OnButtonClick(button)
  frame.chosen = true
  frame:Hide()
  Pathwise:GetModule("Talents"):SetGoal(button.goalKey)
end

local function OnButtonEnter(button)
  -- The class's own description first (e.g. SPEC_DESC_PALADIN_HOLY).
  local class = Pathwise:GetModule("Character"):GetSnapshot().class or ""
  local description = rawget(L, "SPEC_DESC_" .. class .. "_" .. button.goalKey)
    or rawget(L, "SPEC_DESC_" .. button.goalKey)
  if not description then
    return -- no description for this goal
  end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText(L["SPEC_" .. button.goalKey])
  GameTooltip:AddLine(description, 1, 1, 1, true)
  GameTooltip:Show()
end

local function OnButtonLeave()
  GameTooltip:Hide()
end

local function CreatePromptFrame()
  -- BackdropTemplate is required for SetBackdrop since the 1.13.6 backdrop
  -- changes; check it exists rather than assuming.
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "PathwiseGoalPrompt", UIParent, template)
  frame:SetWidth(FRAME_WIDTH)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
  -- The dialog background texture is partly see-through; darken it so the
  -- game world (and e.g. the target frame) doesn't show through.
  local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  if shade.SetColorTexture then
    shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
    shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
    shade:SetColorTexture(0, 0, 0, 0.6)
  end
  frame:Hide()

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -20)
  title:SetText("Pathwise")

  local question = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  question:SetPoint("TOP", title, "BOTTOM", 0, -12)
  question:SetWidth(FRAME_WIDTH - 50)
  question:SetText(L.GOAL_PROMPT_QUESTION)

  local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
  hint:SetWidth(FRAME_WIDTH - 50)
  hint:SetText(L.GOAL_PROMPT_HINT)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  frame:SetScript("OnHide", function()
    GameTooltip:Hide()
    if not frame.chosen then
      Pathwise:GetModule("Talents"):OnGoalPromptDismissed()
    end
  end)

  -- Lets Escape close the dialog.
  table.insert(UISpecialFrames, "PathwiseGoalPrompt")
end

local function GetButton(index)
  local button = buttons[index]
  if not button then
    button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetScript("OnClick", OnButtonClick)
    button:SetScript("OnEnter", OnButtonEnter)
    button:SetScript("OnLeave", OnButtonLeave)
    buttons[index] = button
  end
  return button
end

function GoalPrompt:Show(options, currentGoal)
  if Platform.InCombat() then
    self.pending = { options = options, currentGoal = currentGoal }
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
    return
  end
  if not frame then
    CreatePromptFrame()
  end

  for index, key in ipairs(options) do
    local button = GetButton(index)
    button.goalKey = key
    local text = L["SPEC_" .. key]
    if key == currentGoal then
      text = string.format(L.GOAL_CURRENT, text)
    end
    button:SetText(text)
    button:ClearAllPoints()
    button:SetPoint("TOP", frame, "TOP", 0, -(BUTTONS_TOP + (index - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)))
    button:Show()
  end
  for index = #options + 1, #buttons do
    buttons[index]:Hide()
  end

  frame:SetHeight(BUTTONS_TOP + #options * (BUTTON_HEIGHT + BUTTON_SPACING) + BOTTOM_PADDING)
  frame.chosen = false
  frame:Show()
end

function GoalPrompt:OnCombatEnded()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  local pending = self.pending
  self.pending = nil
  if pending then
    self:Show(pending.options, pending.currentGoal)
  end
end

function GoalPrompt:OnGoalPromptRequested(_, options, currentGoal)
  self:Show(options, currentGoal)
end

function GoalPrompt:OnInitialize()
  self:RegisterCallback("GOAL_PROMPT_REQUESTED", "OnGoalPromptRequested")
end
