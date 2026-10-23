local addonName, Pathwise = ...

-- Next Steps window: a small movable window listing what to do now, from
-- all modules (quests, trainer, ...). Toggle with /pw. Hover a line for
-- details (e.g. a quest's objectives). Position and visibility are saved.

local L = Pathwise.L

local NextStepsFrame = Pathwise:NewModule("NextStepsFrame")

local WIDTH = 340
local ROW_HEIGHT = 16
local MAX_ROWS = 16
local INDENT = 12 -- per sub-line level
local TASK_COLOR = "|cff99e6ff"
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
    row.text:SetJustifyH("LEFT")
    rows[index] = row
  end
  return row
end

local function UpdatePath()
  local active = Pathwise:GetModule("Talents"):GetSpecInfo().active
  frame.path.text:SetText(string.format(L.NS_PATH, L["SPEC_" .. active]))
  frame.path:SetWidth(frame.path.text:GetStringWidth() + 4)
end

-- The step that gets its details listed underneath: the one the arrow
-- follows, else the first one that has details.
local function ExpandedItem(items)
  local followed = Pathwise:GetModule("Waypoints"):GetAutoItemId()
  for _, item in ipairs(items) do
    if item.id == followed and item.subLines and #item.subLines > 0 then
      return item
    end
  end
  for _, item in ipairs(items) do
    if item.subLines and #item.subLines > 0 then
      return item
    end
  end
end

-- Flattens the items into window lines: { text, indent, item }.
local function BuildLines(items)
  local lines = {}
  local expanded = ExpandedItem(items)
  for _, item in ipairs(items) do
    local text = item == expanded and item.expandedText or item.text
    if item.target then
      text = text .. " " .. L.NS_HAS_LOCATION
    end
    lines[#lines + 1] = { text = text, indent = 0, item = item }
    if item == expanded then
      for _, sub in ipairs(item.subLines) do
        local subText = sub.task and (TASK_COLOR .. sub.text .. "|r") or sub.text
        lines[#lines + 1] = { text = subText, indent = sub.level * INDENT, item = item }
      end
    end
  end
  return lines
end

function NextStepsFrame:Render()
  if not frame or not frame:IsShown() then
    return
  end
  UpdatePath()
  local items = Pathwise:GetModule("NextSteps"):GetItems()
  local lines = BuildLines(items)
  if #lines == 0 then
    lines[1] = { text = L.NS_EMPTY, indent = 0 }
  elseif #lines > MAX_ROWS then
    local hidden = {}
    for i = MAX_ROWS, #lines do
      if lines[i].item and lines[i].indent == 0 then
        hidden[#hidden + 1] = true
      end
    end
    for i = #lines, MAX_ROWS, -1 do
      lines[i] = nil
    end
    lines[MAX_ROWS] = { text = string.format(L.NS_MORE, #hidden), indent = 0 }
  end

  for i, line in ipairs(lines) do
    local row = GetRow(i)
    row.item = line.item
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", line.indent, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetText(line.text)
    row:Show()
  end
  for i = #lines + 1, #rows do
    rows[i]:Hide()
  end
  frame:SetHeight(TOP_PADDING + #lines * ROW_HEIGHT + BOTTOM_PADDING)
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

  -- "Path: Marksmanship" - click to change path (opens the path chooser).
  local path = CreateFrame("Button", nil, frame)
  path:SetHeight(16)
  path:SetPoint("RIGHT", close, "LEFT", -2, 0)
  path.text = path:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  path.text:SetPoint("RIGHT", path, "RIGHT", 0, 0)
  path:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  path:SetScript("OnClick", function()
    Pathwise:GetModule("Talents"):RequestGoalPrompt()
  end)
  path:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(self.text:GetText())
    GameTooltip:AddLine(L.NS_PATH_TOOLTIP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  path:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  frame.path = path

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
  self:RegisterCallback("SPEC_CHANGED", "OnUpdated")
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
