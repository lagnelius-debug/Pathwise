local addonName, Pathwise = ...

-- Dungeon picker (/pw dungeon, or "Dungeons" in the To-do window): a
-- themed window listing the dungeons for the player's faction with their
-- level range and how many of their quests are left. Clicking one turns on
-- dungeon mode (Core/DungeonGuide.lua); the top row leaves it.

local L = Pathwise.L

local DungeonPicker = Pathwise:NewModule("DungeonPicker")

local ROW_HEIGHT = 18
local WIDTH = 300

local frame
local rows = {}

local function DungeonGuide()
  return Pathwise:GetModule("DungeonGuide")
end

-- Level range color: green when it fits the player, grey when it's below,
-- red-orange when it's still above.
local function RangeColor(dungeon, level)
  if level > dungeon.max then
    return "|cff808080"
  elseif level < dungeon.min - 2 then
    return "|cffff8040"
  end
  return "|cff40c040"
end

local function Row(index)
  local row = rows[index]
  if not row then
    row = CreateFrame("Button", nil, frame.content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", frame.content, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnClick", function(self)
      DungeonGuide():SetDungeon(self.dungeonID)
      DungeonPicker:Refresh()
    end)
    rows[index] = row
  end
  return row
end

function DungeonPicker:Refresh()
  if not frame or not frame:IsShown() then
    return
  end
  local level = Pathwise:GetModule("Character"):GetSnapshot().level or 1
  local active = DungeonGuide():GetActive()
  local entries = {}
  if active then
    entries[1] = { text = "|cffffd100" .. L.DUNGEON_LEAVE .. "|r", dungeonID = nil }
  end
  for _, dungeon in ipairs(DungeonGuide().List()) do
    local open = DungeonGuide():CountOpen(dungeon)
    local quests = open and (open == 1 and L.DUNGEON_ONE_QUEST or string.format(L.DUNGEON_QUESTS, open)) or ""
    local text = string.format(L.DUNGEON_ROW, RangeColor(dungeon, level), dungeon.min, dungeon.max, dungeon.name, quests)
    if active and active.id == dungeon.id then
      text = text .. " " .. L.DUNGEON_ACTIVE
    end
    entries[#entries + 1] = { text = text, dungeonID = dungeon.id }
  end
  for index, entry in ipairs(entries) do
    local row = Row(index)
    row.text:SetText(entry.text)
    row.dungeonID = entry.dungeonID
    row:Show()
  end
  for index = #entries + 1, #rows do
    rows[index]:Hide()
  end
  frame.footer.text:SetText(Pathwise:GetModule("QuestieData"):IsAvailable() and L.DUNGEON_PICKER_HINT
    or L.DUNGEON_NEEDS_QUESTIE)
  frame:SetContentHeight(#entries * ROW_HEIGHT)
end

function DungeonPicker:Toggle()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    self:Refresh()
  end
end

function DungeonPicker:IsShown()
  return frame:IsShown()
end

function DungeonPicker:OnInitialize()
  frame = Pathwise.Theme.CreateWindow("PathwiseDungeonPicker", UIParent, L.DUNGEON_PICKER_TITLE)
  frame:SetWidth(WIDTH)
  frame:SetFrameStrata("DIALOG")
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.close:SetScript("OnClick", function()
    frame:Hide()
  end)
  -- Escape closes it.
  if UISpecialFrames then
    table.insert(UISpecialFrames, "PathwiseDungeonPicker")
  end
  frame:Hide()
  self:RegisterCallback("DUNGEON_MODE_CHANGED", "Refresh")
  self:RegisterCallback("QUESTIE_PICKUPS_READY", "Refresh")
end
