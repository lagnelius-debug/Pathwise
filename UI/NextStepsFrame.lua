local addonName, Pathwise = ...

-- To-do window (Next Steps): a small movable window listing what to do now,
-- from all modules (quests, trainer, ...). Toggle with /pw. Hover a line for
-- details (e.g. a quest's objectives); click a line with a location to point
-- the arrow there. Position and visibility are saved; the look comes from
-- the active theme (UI/Theme.lua).

local L = Pathwise.L

local NextStepsFrame = Pathwise:NewModule("NextStepsFrame")

local ROW_HEIGHT = 16
local MAX_ROWS = 16 -- with automatic height
local MIN_WIDTH = 240
local MIN_ROWS = 3  -- smallest height the grip allows
local INDENT = 12 -- per sub-line level
local TASK_COLOR = "|cff99e6ff"

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
    local content = frame.content
    row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    row:SetScript("OnMouseUp", OnRowClick)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    -- One line per row: text that doesn't fit ends in "..." instead of
    -- wrapping into the next row.
    row.text:SetHeight(ROW_HEIGHT)
    if row.text.SetWordWrap then
      row.text:SetWordWrap(false)
    end
    rows[index] = row
  end
  return row
end

local UpdateTitle

local function UpdateFooter(stepCount)
  UpdateTitle()
  local active = Pathwise:GetModule("Talents"):GetSpecInfo().active
  local path = frame.path
  path.text:SetText(string.format(L.NS_PATH, L["SPEC_" .. active]))
  path:SetWidth(path.text:GetStringWidth() + 4)
  -- The mode button says what a click switches to.
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local dungeons = frame.dungeons
  dungeons.text:SetText(DungeonGuide:GetActive() and L.NS_NORMAL_MODE
    or DungeonGuide:GetLast() and L.NS_DUNGEON_MODE or L.NS_DUNGEONS)
  dungeons:SetWidth(dungeons.text:GetStringWidth() + 4)
  if DungeonGuide:GetInside() then
    frame.footer.text:SetText(string.format(L.NS_FOOTER_INSIDE, stepCount))
  elseif DungeonGuide:GetActive() then
    frame.footer.text:SetText(string.format(L.NS_FOOTER_DUNGEON, stepCount))
  else
    local zone = Pathwise:GetModule("Character"):GetSnapshot().zone
    frame.footer.text:SetText(string.format(L.NS_FOOTER, stepCount, zone and zone.zone or ""))
  end
end

-- "To-do", or "Dungeon: The Deadmines" inside a dungeon or in dungeon
-- mode. (Re-skins only when it changes.)
function UpdateTitle()
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local dungeon = DungeonGuide:GetInside() or DungeonGuide:GetActive()
  local title = dungeon and string.format(L.DUNGEON_TITLE, dungeon.name) or L.NS_TITLE
  if frame.titleText ~= title then
    frame:SetTitleText(title)
  end
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

-- Flattens the items into window lines: { text, indent, item, current }.
local function BuildLines(items)
  local lines = {}
  local expanded = ExpandedItem(items)
  local Theme = Pathwise.Theme
  for _, item in ipairs(items) do
    local text = item == expanded and item.expandedText or item.text
    if item.target then
      text = text .. " " .. L.NS_HAS_LOCATION
    end
    local current = item == expanded
    lines[#lines + 1] = { text = Theme.RecolorQuestNames(text), indent = 0, item = item, current = current }
    if current then
      for _, sub in ipairs(item.subLines) do
        local subText = sub.task and (TASK_COLOR .. sub.text .. "|r") or Theme.RecolorQuestNames(sub.text)
        lines[#lines + 1] = { text = subText, indent = sub.level * INDENT, item = item, current = true }
      end
    end
  end
  return lines
end

function NextStepsFrame:Render()
  if not frame or not frame:IsShown() then
    return
  end
  local items = Pathwise:GetModule("NextSteps"):GetItems()
  UpdateFooter(#items)
  local lines = BuildLines(items)
  -- With a player-chosen height, show as many rows as fit.
  local capacity = frame:GetContentCapacity()
  local maxRows = capacity and math.max(math.floor(capacity / ROW_HEIGHT), 1) or MAX_ROWS
  if #lines == 0 then
    lines[1] = { text = L.NS_EMPTY, indent = 0 }
  elseif #lines > maxRows then
    -- The last row becomes "... and N more" (N = steps that don't fit), or
    -- just "..." when only the current step's detail lines are cut off.
    local hidden = 0
    for i = maxRows, #lines do
      if lines[i].indent == 0 then
        hidden = hidden + 1
      end
    end
    for i = #lines, maxRows, -1 do
      lines[i] = nil
    end
    local text = hidden > 0 and string.format(L.NS_MORE, hidden) or L.NS_MORE_DETAILS
    lines[maxRows] = { text = text, indent = 0 }
  end

  local textColor = frame.textColor or { 1, 1, 1 }
  local firstCurrent, lastCurrent
  for i, line in ipairs(lines) do
    local row = GetRow(i)
    row.item = line.item
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", line.indent, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetTextColor(textColor[1], textColor[2], textColor[3])
    row.text:SetText(line.text)
    row:Show()
    if line.current then
      firstCurrent = firstCurrent or row
      lastCurrent = row
    end
  end
  for i = #lines + 1, #rows do
    rows[i]:Hide()
  end
  frame:SetHighlightRow(firstCurrent, lastCurrent)
  frame:SetContentHeight(#lines * ROW_HEIGHT)
end

local function ApplySavedSize()
  local saved = Pathwise.db.nextSteps
  frame:SetWidth(saved.width or Pathwise.Theme.DEFAULT_WIDTH)
  frame.fixedHeight = saved.height
  frame:Layout()
end

local function CreateWindow()
  frame = Pathwise.Theme.CreateWindow("PathwiseNextSteps", UIParent, L.NS_TITLE)
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
  frame.close:SetScript("OnClick", function()
    NextStepsFrame:SetShown(false)
  end)

  -- Size grip: the saved size (nil height = automatic) is applied here and
  -- after every resize.
  -- (Pathwise.db.nextSteps is looked up each time: /pw reset replaces it.)
  -- While dragging (live) only re-render when the row count changes; the
  -- size and position are saved once the drag ends.
  local lastRows
  frame:EnableResizing(MIN_WIDTH, MIN_ROWS * ROW_HEIGHT, function(width, height, live)
    if live then
      local rowCount = math.floor((frame:GetContentCapacity() or 0) / ROW_HEIGHT)
      if rowCount ~= lastRows then
        lastRows = rowCount
        NextStepsFrame:Render()
      end
      return
    end
    lastRows = nil
    local saved = Pathwise.db.nextSteps
    saved.width, saved.height = width, height
    SavePosition() -- sizing from the corner can change the anchor
    NextStepsFrame:Render()
  end)
  ApplySavedSize()
  -- Re-render with the new theme's text color.
  frame.OnThemeApplied = function()
    NextStepsFrame:Render()
  end

  -- "Path: Marksmanship" in the footer - click to change path.
  local path = CreateFrame("Button", nil, frame.footer)
  path:SetHeight(16)
  -- Kept left of the size grip in the window's bottom-right corner.
  path:SetPoint("RIGHT", frame.footer, "RIGHT", -10, 0)
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

  -- The mode button left of it: a click switches between dungeon mode (the
  -- last dungeon picked) and the normal guide; right-click picks another
  -- dungeon. ("Dungeons" before any was picked: opens the list.)
  local dungeons = CreateFrame("Button", nil, frame.footer)
  dungeons:SetHeight(16)
  dungeons:SetPoint("RIGHT", path, "LEFT", -10, 0)
  dungeons.text = dungeons:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dungeons.text:SetPoint("RIGHT", dungeons, "RIGHT", 0, 0)
  dungeons:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  if dungeons.RegisterForClicks then
    dungeons:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end
  dungeons:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      Pathwise:GetModule("DungeonPicker"):Toggle()
    else
      Pathwise:GetModule("DungeonGuide"):Toggle()
    end
  end)
  dungeons:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(self.text:GetText())
    GameTooltip:AddLine(Pathwise:GetModule("DungeonGuide"):GetLast() and L.NS_MODE_TOOLTIP or L.NS_DUNGEONS_TOOLTIP,
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  dungeons:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  frame.dungeons = dungeons
  -- The step count and zone stop at the buttons ("..." when too long).
  local footerText = frame.footer.text
  footerText:SetPoint("RIGHT", dungeons, "LEFT", -8, 0)
  footerText:SetJustifyH("LEFT")
  if footerText.SetWordWrap then
    footerText:SetWordWrap(false)
  end

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

function NextStepsFrame:OnDungeonModeChanged()
  UpdateTitle()
  self:Render()
end

function NextStepsFrame:OnInitialize()
  CreateWindow()
  self:RegisterCallback("DUNGEON_MODE_CHANGED", "OnDungeonModeChanged")
  self:RegisterCallback("NEXT_STEPS_UPDATED", "OnUpdated")
  self:RegisterCallback("SPEC_CHANGED", "OnUpdated")
  self:RegisterCallback("SETTINGS_RESET", "OnSettingsReset")
end

function NextStepsFrame:OnEnable()
  -- Saved variables are loaded now: apply the saved theme (and the title of
  -- a dungeon mode left on).
  UpdateTitle()
  Pathwise.Theme.Apply(frame)
  frame:SetShown(Pathwise.db.nextSteps.shown)
  self:Render()
end

function NextStepsFrame:OnSettingsReset()
  ApplySavedSize()
  Pathwise.Theme.Apply(frame)
  RestorePosition()
  frame:SetShown(Pathwise.db.nextSteps.shown)
  self:Render()
end

-- "/pw" with no arguments toggles the window.
Pathwise:RegisterCommand("", function()
  NextStepsFrame:Toggle()
end, L.CMD_TOGGLE)
