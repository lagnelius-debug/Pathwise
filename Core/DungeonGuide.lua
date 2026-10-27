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

  local entrance, distance = self:EntranceTarget(dungeon)
  if entrance then
    local zone = Platform.GetMapName(entrance.mapID) or "?"
    local text = string.format(L.DUNGEON_ENTRANCE, dungeon.name, zone)
    if distance then
      text = text .. string.format(L.QA_DISTANCE, Pathwise.FormatDistance(distance))
    end
    items[#items + 1] = { id = "dungeon:entrance", priority = P.QUEST_ELSEWHERE, text = text, target = entrance,
      distance = distance }
  end

  -- The dungeon's quests the player is too low for: one line, the names in
  -- the tooltip.
  local inLog = {}
  for _, quest in ipairs(log) do
    if quest.questID then
      inLog[quest.questID] = true
    end
  end
  local level = GetSnapshot().level or 1
  local later, lowest, open = {}, nil, 0
  for _, questID in ipairs(quests.list) do
    if not Platform.IsQuestCompleted(questID) then
      open = open + 1
      local required = QuestieData:QuestInfo(questID, "requiredLevel") or 1
      if required > level and not inLog[questID] then
        later[#later + 1] = string.format(L.DUNGEON_LATER_LINE, QuestieData:QuestInfo(questID, "name") or "?", required)
        lowest = math.min(lowest or required, required)
      end
    end
  end
  if #later > 0 then
    items[#items + 1] = { id = "dungeon:later", priority = P.QUEST_LATER, detail = later,
      text = string.format(L.DUNGEON_LATER, #later, lowest) }
  end
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
