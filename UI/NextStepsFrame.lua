local addonName, Pathwise = ...

-- Next Steps window: a small movable window listing what to do now, from
-- all modules (quests, trainer, ...). Toggle with /pw. Hover a line for
-- details (e.g. a quest's objectives). Position and visibility are saved.

local L = Pathwise.L

local NextStepsFrame = Pathwise:NewModule("NextStepsFrame")

local WIDTH = 330
local ROW_HEIGHT = 16
local MAX_ROWS = 12
local TOP_PADDING = 34
local BOTTOM_PADDING = 14

local frame
local rows = {}

local function SavePosition()
  local point, _, relativePoint, x, y = frame:GetPoint()
  local saved = Pathwise.db.nextSteps
  saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function RestorePosition()
  local saved = Pathwise.db.nextSteps
  frame:ClearAllPoints()
  if saved.point then
    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
  else
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
  end
end

local function OnRowEnter(row)
  local item = row.item
  local detail = item and item.detail
  if not item or ((not detail or #detail == 0) and not item.target) then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_LEFT")
  GameTooltip:SetText(row.text:GetText(), 1, 1, 1, 1, true)
  for _, line in ipairs(detail or {}) do
    GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
  end
  if item.target then
    GameTooltip:AddLine(L.NS_CLICK_ARROW, 0.4, 0.8, 1, true)
  end
  GameTooltip:Show()
end

-- Clicking a step with a known location points the arrow there.
local function OnRowClick(row, button)
  if button == "LeftButton" and row.item and row.item.target then
    Pathwise:GetModule("Waypoints"):SetManual(row.item.target)
  end
end

local function OnRowLeave()
  GameTooltip:Hide()
end

local function GetRow(index)
  local row = rows[index]
  if not row then
    row = CreateFrame("Frame", nil, frame)
    row:SetSize(WIDTH - 28, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(TOP_PADDING + (index - 1) * ROW_HEIGHT))
    row:EnableMouse(true)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    row:SetScript("OnMouseUp", OnRowClick)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetAllPoints(row)
    row.text:SetJustifyH("LEFT")
    rows[index] = row
  end
  return row
end

function NextStepsFrame:Render()
  if not frame or not frame:IsShown() then
    return
  end
  local items = Pathwise:GetModule("NextSteps"):GetItems()
  local shown = math.min(#items, MAX_ROWS)
  local count = shown

  for i = 1, shown do
    local row = GetRow(i)
    row.item = items[i]
    row.text:SetText(items[i].target and (items[i].text .. " " .. L.NS_HAS_LOCATION) or items[i].text)
    row:Show()
  end
  if #items == 0 then
    count = 1
    local row = GetRow(1)
    row.item = nil
    row.text:SetText(L.NS_EMPTY)
    row:Show()
  elseif #items > MAX_ROWS then
    count = shown + 1
    local row = GetRow(count)
    row.item = nil
    row.text:SetText(string.format(L.NS_MORE, #items - MAX_ROWS))
    row:Show()
  end
  for i = count + 1, #rows do
    rows[i]:Hide()
  end
  frame:SetHeight(TOP_PADDING + count * ROW_HEIGHT + BOTTOM_PADDING)
end

local function CreateWindow()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "PathwiseNextSteps", UIParent, template)
  frame:SetWidth(WIDTH)
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
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.75)
  end

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
  title:SetText(L.NS_TITLE)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function()
    NextStepsFrame:SetShown(false)
  end)

  RestorePosition()
  frame:Hide()
end

function NextStepsFrame:SetShown(shown)
  Pathwise.db.nextSteps.shown = shown
  frame:SetShown(shown)
  self:Render()
end

function NextStepsFrame:Toggle()
  self:SetShown(not frame:IsShown())
end

function NextStepsFrame:OnUpdated()
  self:Render()
end

function NextStepsFrame:OnInitialize()
  CreateWindow()
  self:RegisterCallback("NEXT_STEPS_UPDATED", "OnUpdated")
  self:RegisterCallback("SETTINGS_RESET", "OnSettingsReset")
end

function NextStepsFrame:OnEnable()
  frame:SetShown(Pathwise.db.nextSteps.shown)
  self:Render()
end

function NextStepsFrame:OnSettingsReset()
  RestorePosition()
  frame:SetShown(Pathwise.db.nextSteps.shown)
  self:Render()
end

-- "/pw" with no arguments toggles the window.
Pathwise:RegisterCommand("", function()
  NextStepsFrame:Toggle()
end, L.CMD_TOGGLE)
