-- Dungeon guide (Core/DungeonGuide.lua, UI/DungeonPicker.lua): dungeon
-- mode shows a dungeon's quests and the pre-quests that lead to them.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local NextSteps = Pathwise:GetModule("NextSteps")
local QuestieData = Pathwise:GetModule("QuestieData")
local DungeonGuide = Pathwise:GetModule("DungeonGuide")
local window = _G.PathwiseNextSteps
local P = NextSteps.PRIORITY

local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end
local function UpdateLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

local completed = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return completed[id] == true end }

-- A made-up dungeon with its entrance in Teldrassil.
local L = S.level
local dungeon = { id = 9500, name = "The Test Mines", min = L - 2, max = L + 5, entrances = { { 141, 50, 80 } } }
table.insert(Pathwise.Data.Dungeons, dungeon)
local quests = {
  [9600] = { name = "Pre-quest", requiredLevel = 1, questLevel = L, zoneOrSort = 141, startedBy = { { 9701 } } },
  [9601] = { name = "Into the Mines", requiredLevel = 1, questLevel = L, zoneOrSort = 9500, preQuestSingle = { 9600 },
    startedBy = { { 9702 } } },
  [9602] = { name = "Mine Quest", requiredLevel = 1, questLevel = L, zoneOrSort = 9500, startedBy = { { 9702 } } },
  [9603] = { name = "Deep Mine Quest", requiredLevel = L + 5, questLevel = L + 6, zoneOrSort = 9500,
    startedBy = { { 9702 } } },
  [9604] = { name = "Normal Quest", requiredLevel = 1, questLevel = L, zoneOrSort = 141, startedBy = { { 9701 } } },
  -- A chain that starts at a higher level (like The Defias Brotherhood in
  -- Westfall for The Deadmines).
  [9605] = { name = "Chain Start", requiredLevel = L + 3, questLevel = L + 3, zoneOrSort = 141, startedBy = { { 9701 } } },
  [9606] = { name = "Chain End", requiredLevel = L + 3, questLevel = L + 4, zoneOrSort = 9500, preQuestSingle = { 9605 },
    startedBy = { { 9702 } } },
}
local npcs = {
  [9701] = { name = "Village Elder", spawns = { [141] = { { 58, 41 } } } },
  [9702] = { name = "Mine Foreman", spawns = { [141] = { { 60, 45 } } } },
}
local questGet, npcGet, allIds = LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Quest.GetAllIds
LibQuestieDB.Quest.Get = function(id, key)
  if quests[id] then return quests[id][key] end
  return questGet(id, key)
end
LibQuestieDB.Npc.Get = function(id, key)
  if npcs[id] then return npcs[id][key] end
  return npcGet(id, key)
end
LibQuestieDB.Quest.GetAllIds = function() return { 9600, 9601, 9602, 9603, 9604, 9605, 9606 } end
QuestieData:ResetPickups()
QuestieData:PickupsReady()
WoW.RunTimers()
S.mapID, S.mapX, S.mapY = 1438, 0.58, 0.40
UpdateLog({})

---------------------------------------------------------------------------
section("Dungeons: the list")

local names = {}
for _, d in ipairs(DungeonGuide.List()) do names[d.name] = true end
check("Alliance: no Ragefire Chasm, but The Stockade and The Deadmines", not names["Ragefire Chasm"]
  and names["The Stockade"] and names["The Deadmines"] and names["The Test Mines"])
check("its quests (for this race and class)", #QuestieData:GetDungeonQuests(9500) == 4)
check("normal mode: the normal quest is suggested", Item("pickup:9604") ~= nil)

---------------------------------------------------------------------------
section("Dungeons: dungeon mode")

WoW.ClearChat()
WoW.Slash("dungeon test mines")
check("/pw dungeon <name> turns it on", DungeonGuide:GetActive() == dungeon
  and WoW.ChatContains("Dungeon mode: The Test Mines."))
check("title: Dungeon: The Test Mines", window.title:GetText() == "Dungeon: The Test Mines")
check("footer says dungeon mode", window.footer.text:GetText():find("dungeon mode", 1, true) ~= nil)
local pre, own = Item("pickup:9600"), Item("pickup:9602")
check("the pre-quest to pick up, marked as one", pre ~= nil and pre.detail[#pre.detail]:find("pre-quest", 1, true) ~= nil)
check("the dungeon's own quest to pick up", own ~= nil)
check("not the quest whose pre-quest isn't done", Item("pickup:9601") == nil)
check("no quests that don't belong to the dungeon", Item("pickup:9604") == nil)
local entrance = Item("dungeon:entrance")
check("a step to the entrance", entrance and entrance.target.mapID == 1438 and math.abs(entrance.target.x - 0.5) < 1e-9
  and math.abs(entrance.target.y - 0.8) < 1e-9 and entrance.text:find("^Go to The Test Mines %(entrance in ") ~= nil)
local later = Item("dungeon:later")
check("later: where the chains go on, not their dungeon quest (" .. tostring(later and later.text) .. ")",
  later and later.text == string.format("Later: 2 quest chains, the first from level %d", L + 3)
  and later.priority == P.QUEST_LATER
  and later.detail[1] == string.format("Chain Start (from level %d): Village Elder, Map 1438", L + 3)
  and later.detail[2]:find("^Deep Mine Quest") ~= nil and #later.detail == 2)
check("about the dungeon's level: the entrance is a step", entrance.priority == P.QUEST_ELSEWHERE)
-- Reported in game: a level 5 character got the Deadmines entrance (17-26)
-- as the first step, before the long quest chain that leads there.
dungeon.min = L + 5
UpdateLog({})
entrance = Item("dungeon:entrance")
check("far below the dungeon: the entrance waits at the bottom, without the arrow",
  entrance.priority == P.QUEST_LATER and entrance.text:find(string.format("from level %d$", L + 5)) ~= nil
  and Pathwise:GetModule("Waypoints"):GetAutoItemId() ~= "dungeon:entrance")
dungeon.min = L - 2

completed[9600] = true
UpdateLog({})
check("pre-quest done: the next one to pick up", Item("pickup:9601") ~= nil and Item("pickup:9600") == nil)

UpdateLog({ { title = "Mine Quest", level = L, questID = 9602, zone = "The Test Mines",
  objectives = { { text = "Mine Rat slain: 0/8" } } } })
local inside = Item("quest:9602")
check("a dungeon quest in the log: the arrow on the entrance", inside and inside.target
  and inside.target.label == "The Test Mines entrance")
UpdateLog({ { title = "Elsewhere Quest", level = L, questID = 9999, zone = "Teldrassil", objectives = {} } })
check("quests that don't belong to the dungeon are left out", Item("quest:9999") == nil)

---------------------------------------------------------------------------
section("Dungeons: the picker")

local Picker = Pathwise:GetModule("DungeonPicker")
Picker:Toggle()
local picker = _G.PathwiseDungeonPicker
check("the picker opens", picker:IsShown())
local rows = {}
for _, f in ipairs(WoW.frames) do
  if f._parent == picker.content and f:IsShown() and f.text then rows[#rows + 1] = f end
end
check("first row: leave dungeon mode", rows[1] and rows[1].text:GetText():find("Leave dungeon mode", 1, true))
local activeRow
for _, row in ipairs(rows) do
  if row.dungeonID == 9500 then activeRow = row end
end
check("the active dungeon is marked, with its level range and quest count", activeRow
  and activeRow.text:GetText():find("(active)", 1, true) and activeRow.text:GetText():find("The Test Mines", 1, true)
  and activeRow.text:GetText():find(string.format("%d%%-%d", L - 2, L + 5)))
WoW.ClearChat()
rows[1]:Click()
check("leaving: back to the usual guide", DungeonGuide:GetActive() == nil and window.title:GetText() == "To-do"
  and WoW.ChatContains("Dungeon mode off"))
UpdateLog({})
check("normal quests are back", Item("pickup:9604") ~= nil and Item("dungeon:entrance") == nil)
Picker:Toggle()
check("the picker closes", not picker:IsShown())

WoW.ClearChat()
WoW.Slash("dungeon atlantis")
check("unknown dungeon", WoW.ChatContains("Unknown dungeon 'atlantis'") and DungeonGuide:GetActive() == nil)

-- Clean up
table.remove(Pathwise.Data.Dungeons)
LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Quest.GetAllIds = questGet, npcGet, allIds
C_QuestLog = nil
QuestieData:ResetPickups()
UpdateLog({})
