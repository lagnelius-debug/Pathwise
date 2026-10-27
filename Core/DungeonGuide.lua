local addonName, Pathwise = ...

-- Dungeon guide: the player picks a dungeon (UI/DungeonPicker.lua or
-- /pw dungeon) and the To-do list switches to "dungeon mode" - only that
-- dungeon's quests and the quests that lead to them (Core/QuestAdvisor.lua
-- asks this module what belongs to the dungeon):
--   - quests to pick up: the dungeon's own, and the pre-quests whose chains
--     unlock them (whatever their level or zone);
--   - pre-quests in the log, with their objectives;
--   - the dungeon's quests in the log, with the arrow on the entrance;
--   - a step to the entrance, and the quests that come at a higher level.
-- The dungeon's quests are the ones QuestieDB tags with its area
-- (Data/Classic/Dungeons.lua); the pre-quests follow preQuestSingle /
-- preQuestGroup back from them. Needs QuestieDB.

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local DungeonGuide = Pathwise:NewModule("DungeonGuide")

-- How deep pre-quest chains are followed back.
local MAX_CHAIN_DEPTH = 20
-- The entrance is a step to go to from this many levels below the
-- dungeon's range; before that it waits at the bottom of the list.
local ENTRANCE_LEVELS_BELOW = 2

local questCache -- { dungeonID, list, quests } for the active dungeon

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

-- A dungeon by its ID, or nil.
function DungeonGuide.Get(id)
  for _, dungeon in ipairs(Data.Dungeons) do
    if dungeon.id == id then
      return dungeon
    end
  end
end

-- The dungeons for the player's faction, in level order.
function DungeonGuide.List()
  local faction = GetSnapshot().faction
  local list = {}
  for _, dungeon in ipairs(Data.Dungeons) do
    if not dungeon.faction or not faction or dungeon.faction == faction then
      list[#list + 1] = dungeon
    end
  end
  return list
end

-- The dungeon of dungeon mode, or nil.
function DungeonGuide:GetActive()
  return DungeonGuide.Get(Pathwise.charDB.dungeon)
end

-- Turns dungeon mode on for a dungeon (or off with nil).
function DungeonGuide:SetDungeon(id)
  local dungeon = id and DungeonGuide.Get(id)
  Pathwise.charDB.dungeon = dungeon and dungeon.id or nil
  questCache = nil
  if dungeon then
    Pathwise:Printf(L.DUNGEON_SET, dungeon.name)
  else
    Pathwise:Print(L.DUNGEON_LEFT)
  end
  Pathwise:FireCallback("DUNGEON_MODE_CHANGED", dungeon)
  Pathwise:GetModule("QuestAdvisor"):Update()
end

-- What belongs to a dungeon: { list = its quest IDs, quests = set of them
-- plus every pre-quest of their chains }, or nil while QuestieDB's quest
-- list isn't scanned (or without QuestieDB).
function DungeonGuide:GetQuests(dungeon)
  if questCache and questCache.dungeonID == dungeon.id then
    return questCache
  end
  local QuestieData = Pathwise:GetModule("QuestieData")
  local list = QuestieData:GetDungeonQuests(dungeon.id)
  if not list then
    return nil
  end
  local quests = {}
  local function Add(questID, depth)
    if quests[questID] or depth > MAX_CHAIN_DEPTH then
      return
    end
    quests[questID] = true
    for _, key in ipairs({ "preQuestSingle", "preQuestGroup" }) do
      local before = QuestieData:QuestInfo(questID, key)
      if type(before) == "table" then
        for _, id in ipairs(before) do
          Add(id, depth + 1)
        end
      end
    end
  end
  for _, questID in ipairs(list) do
    Add(questID, 0)
  end
  local inDungeon = {}
  for _, questID in ipairs(list) do
    inDungeon[questID] = true
  end
  questCache = { dungeonID = dungeon.id, list = list, quests = quests, inDungeon = inDungeon }
  return questCache
end

-- The nearest entrance as an arrow target, or nil.
function DungeonGuide:EntranceTarget(dungeon)
  local QuestieData = Pathwise:GetModule("QuestieData")
  local mapID, x, y = Platform.GetPlayerMapPosition()
  local Waypoints = Pathwise:GetModule("Waypoints")
  local best, bestDistance
  for _, entrance in ipairs(dungeon.entrances) do
    local entranceMap = QuestieData:AreaToUiMap(entrance[1])
    if entranceMap then
      local target = { mapID = entranceMap, x = entrance[2] / 100, y = entrance[3] / 100,
        label = string.format(L.DUNGEON_ENTRANCE_LABEL, dungeon.name) }
      local distance = mapID and Waypoints.TravelDistance(mapID, x, y, target.mapID, target.x, target.y, true)
      if not best or (distance and (not bestDistance or distance < bestDistance)) then
        best, bestDistance = target, distance
      end
    end
  end
  return best, bestDistance
end

-- The quests that come next in a dungeon quest's chain: not done, every
-- pre-quest done (preQuestGroup: all of them; preQuestSingle: one of them,
-- among the ones the player's race and class can take). Adds them to
-- `next` ([questID] = true).
local function ChainNext(questID, nextSet, seen, depth)
  if seen[questID] or depth > MAX_CHAIN_DEPTH or Platform.IsQuestCompleted(questID) then
    return
  end
  seen[questID] = true
  local QuestieData = Pathwise:GetModule("QuestieData")
  local blocked = false
  local group = QuestieData:QuestInfo(questID, "preQuestGroup")
  for _, before in ipairs(type(group) == "table" and group or {}) do
    if not Platform.IsQuestCompleted(before) then
      blocked = true
      ChainNext(before, nextSet, seen, depth + 1)
    end
  end
  local single = QuestieData:QuestInfo(questID, "preQuestSingle")
  if type(single) == "table" and #single > 0 then
    local options, done = {}, false
    for _, before in ipairs(single) do
      done = done or Platform.IsQuestCompleted(before)
      if QuestieData:IsForPlayer(before) then
        options[#options + 1] = before
      end
    end
    if not done and #options > 0 then
      blocked = true
      for _, before in ipairs(options) do
        ChainNext(before, nextSet, seen, depth + 1)
      end
    end
  end
  if not blocked then
    nextSet[questID] = true
  end
end

-- How many of a dungeon's quests the player hasn't done yet, or nil while
-- the quest list isn't scanned.
function DungeonGuide:CountOpen(dungeon)
  local list = Pathwise:GetModule("QuestieData"):GetDungeonQuests(dungeon.id)
  if not list then
    return nil
  end
  local count = 0
  for _, questID in ipairs(list) do
    if not Platform.IsQuestCompleted(questID) then
      count = count + 1
    end
  end
  return count
end

-- The extra steps of dungeon mode (besides the quests): the entrance, the
-- quests that come later, and what's missing. log: the quest log.
function DungeonGuide:ExtraItems(dungeon, log)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local QuestieData = Pathwise:GetModule("QuestieData")
  local items = {}
  if not QuestieData:IsAvailable() then
    return { { id = "dungeon:questie", priority = P.QUEST_ELSEWHERE, text = L.DUNGEON_NEEDS_QUESTIE } }
  end
  local quests = self:GetQuests(dungeon)
  if not quests then
    return { { id = "dungeon:loading", priority = P.QUEST_ELSEWHERE, text = L.DUNGEON_LOADING } }
  end

  local level = GetSnapshot().level or 1
  -- The entrance: a step once the player is about the dungeon's level
  -- (after the quests and pre-quests); before that it waits at the bottom
  -- and doesn't take the arrow.
  local entrance, distance = self:EntranceTarget(dungeon)
  local entranceItem
  if entrance then
    local zone = Platform.GetMapName(entrance.mapID) or "?"
    local text = string.format(L.DUNGEON_ENTRANCE, dungeon.name, zone)
    local ready = level >= dungeon.min - ENTRANCE_LEVELS_BELOW
    if not ready then
      text = text .. string.format(L.DUNGEON_FROM_LEVEL, dungeon.min)
    elseif distance then
      text = text .. string.format(L.QA_DISTANCE, Pathwise.FormatDistance(distance))
    end
    -- (Added last: below "Later" when both wait.)
    entranceItem = { id = "dungeon:entrance", priority = ready and P.QUEST_ELSEWHERE or P.QUEST_LATER,
      text = text, target = entrance, distance = distance }
  end

  -- What comes later: where each chain goes on (its next quest) when the
  -- player is too low for it - e.g. The Defias Brotherhood in Westfall at
  -- 14 for The Deadmines. One line, the quests in the tooltip.
  local inLog = {}
  for _, quest in ipairs(log) do
    if quest.questID then
      inLog[quest.questID] = true
    end
  end
  local nextSet, seen, open = {}, {}, 0
  for _, questID in ipairs(quests.list) do
    if not Platform.IsQuestCompleted(questID) then
      open = open + 1
      ChainNext(questID, nextSet, seen, 0)
    end
  end
  local later = {}
  for questID in pairs(nextSet) do
    local required = QuestieData:QuestInfo(questID, "requiredLevel") or 1
    if required > level and not inLog[questID] then
      later[#later + 1] = { id = questID, level = required, name = QuestieData:QuestInfo(questID, "name") or "?" }
    end
  end
  table.sort(later, function(a, b)
    if a.level ~= b.level then
      return a.level < b.level
    end
    return a.name < b.name
  end)
  if #later > 0 then
    local lines = {}
    for _, quest in ipairs(later) do
      local giver, giverMap = QuestieData:GiverInfo(quest.id)
      if giver then
        lines[#lines + 1] = string.format(L.DUNGEON_LATER_GIVER, quest.name, quest.level, giver,
          giverMap and Platform.GetMapName(giverMap) or "?")
      else
        lines[#lines + 1] = string.format(L.DUNGEON_LATER_LINE, quest.name, quest.level)
      end
    end
    items[#items + 1] = { id = "dungeon:later", priority = P.QUEST_LATER, detail = lines,
      text = #later == 1 and string.format(L.DUNGEON_LATER_ONE, later[1].name, later[1].level)
        or string.format(L.DUNGEON_LATER, #later, later[1].level) }
  end
  items[#items + 1] = entranceItem
  if open == 0 then
    items[#items + 1] = { id = "dungeon:done", priority = P.QUEST_ELSEWHERE,
      text = string.format(L.DUNGEON_NONE_LEFT, dungeon.name) }
  end
  return items
end

function DungeonGuide:OnInitialize()
  -- The quest list scan finishing changes what belongs to the dungeon.
  self:RegisterCallback("QUESTIE_PICKUPS_READY", function()
    questCache = nil
  end)
end

---------------------------------------------------------------------------
-- /pw dungeon
---------------------------------------------------------------------------

local function Normalize(text)
  return (text:lower():gsub("^the ", ""):gsub("[%s'%-]", ""))
end

-- /pw dungeon          open the list
-- /pw dungeon off      leave dungeon mode
-- /pw dungeon <name>   e.g. deadmines, sfk-like prefixes ("shadow")
Pathwise:RegisterCommand("dungeon", function(args)
  args = args or ""
  if args == "" then
    Pathwise:GetModule("DungeonPicker"):Toggle()
    return
  end
  if args:lower() == "off" then
    DungeonGuide:SetDungeon(nil)
    return
  end
  local wanted = Normalize(args)
  for _, dungeon in ipairs(DungeonGuide.List()) do
    if Normalize(dungeon.name):sub(1, #wanted) == wanted then
      DungeonGuide:SetDungeon(dungeon.id)
      return
    end
  end
  Pathwise:Printf(L.DUNGEON_UNKNOWN, args)
end, L.CMD_DUNGEON)
