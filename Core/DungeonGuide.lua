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

-- The dungeon the player is inside, or nil.
function DungeonGuide:GetInside()
  local instanceID = Platform.GetDungeonInstanceID()
  if not instanceID then
    return nil
  end
  for _, dungeon in ipairs(Data.Dungeons) do
    if dungeon.instance == instanceID then
      return dungeon
    end
  end
end

-- A boss of a dungeon by name: its place in the order, the count, where.
function DungeonGuide.Boss(dungeon, name)
  for index, boss in ipairs(dungeon.bosses or {}) do
    if boss[1] == name then
      return index, #dungeon.bosses, boss[2]
    end
  end
end

-- The dungeon of dungeon mode, or nil.
function DungeonGuide:GetActive()
  return DungeonGuide.Get(Pathwise.charDB.dungeon)
end

-- Turns dungeon mode on for a dungeon (or off with nil). The dungeon is
-- remembered, so Toggle can switch back to it. (Chat explains it once,
-- then just says the mode.)
function DungeonGuide:SetDungeon(id)
  local dungeon = id and DungeonGuide.Get(id)
  local charDB = Pathwise.charDB
  charDB.dungeon = dungeon and dungeon.id or nil
  if dungeon then
    charDB.lastDungeon = dungeon.id
  end
  questCache = nil
  if dungeon then
    Pathwise:Printf(charDB.dungeonExplained and L.DUNGEON_SET_SHORT or L.DUNGEON_SET, dungeon.name)
    charDB.dungeonExplained = true
  else
    Pathwise:Print(L.DUNGEON_LEFT)
  end
  Pathwise:FireCallback("DUNGEON_MODE_CHANGED", dungeon)
  Pathwise:GetModule("QuestAdvisor"):Update()
end

-- The dungeon Toggle switches to: the last one picked, or nil.
function DungeonGuide:GetLast()
  return DungeonGuide.Get(Pathwise.charDB.lastDungeon)
end

-- Switches between dungeon mode (the last dungeon picked) and the normal
-- guide; opens the dungeon list when none was picked yet.
function DungeonGuide:Toggle()
  if self:GetActive() then
    self:SetDungeon(nil)
  elseif self:GetLast() then
    self:SetDungeon(self:GetLast().id)
  else
    Pathwise:GetModule("DungeonPicker"):Toggle()
  end
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
      -- (Entrances are written for Classic Era's maps.)
      local ex, ey = Platform.MapPoint(entranceMap, entrance[2] / 100, entrance[3] / 100)
      local target = { mapID = entranceMap, x = ex, y = ey, label = string.format(L.DUNGEON_ENTRANCE_LABEL, dungeon.name) }
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

-- At most this many quest names in the "missing" step's line.
local MISSING_NAMES = 2

-- Dungeon mode: the dungeon's quests that aren't done or in the quest log
-- yet - the player should have all of them before going in. One step that
-- names them; its details (hover) say where each is picked up, or what has
-- to come first. nil when none is missing (or without the quest list).
-- log: the quest log; ctx: the pickup context; pickups: the pickups the
-- plan suggests.
function DungeonGuide:MissingItem(dungeon, log, ctx, pickups)
  local QuestieData = Pathwise:GetModule("QuestieData")
  local quests = self:GetQuests(dungeon)
  if not quests then
    return nil
  end
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local inLog, suggested = {}, {}
  for _, quest in ipairs(log) do
    if quest.questID then
      inLog[quest.questID] = true
    end
  end
  for _, pickup in ipairs(pickups or {}) do
    suggested[pickup.questID] = true
  end
  local level = GetSnapshot().level or 1
  local function Name(questID)
    return QuestieData:QuestInfo(questID, "name") or ("#" .. questID)
  end
  local function Where(questID)
    local giver, mapID = QuestieData:GiverInfo(questID)
    return giver or "?", mapID and Platform.GetMapName(mapID) or "?"
  end
  local names, lines = {}, {}
  for _, questID in ipairs(quests.list) do
    if not inLog[questID] and not Platform.IsQuestCompleted(questID) then
      local name = Name(questID)
      names[#names + 1] = name
      -- What comes first in its chain (not this quest itself).
      local nextSet, first = {}, nil
      ChainNext(questID, nextSet, {}, 0)
      nextSet[questID] = nil
      for id in pairs(nextSet) do
        first = (not first or id < first) and id or first
      end
      local line
      if suggested[questID] then
        line = string.format(L.DUNGEON_MISSING_PICKUP, name, Where(questID))
      elseif first and inLog[first] then
        line = string.format(L.DUNGEON_MISSING_FINISH, name, Name(first))
      elseif first then
        local required = QuestieData:QuestInfo(first, "requiredLevel") or 1
        local giver, zone = Where(first)
        line = required > level and string.format(L.DUNGEON_MISSING_FIRST_LEVEL, name, Name(first), required, giver, zone)
          or string.format(L.DUNGEON_MISSING_FIRST, name, Name(first), giver, zone)
      else
        local required = QuestieData:QuestInfo(questID, "requiredLevel") or 1
        local giver, zone = Where(questID)
        local reason = QuestieData:WhyNotSuggested(questID, ctx)
        if required > level then
          line = string.format(L.DUNGEON_MISSING_LEVEL, name, required, giver, zone)
        elseif reason and reason ~= "range" then
          line = string.format(L.DUNGEON_MISSING_WHY, name, giver, zone, L["WHY_" .. reason] or reason)
        else
          line = string.format(L.DUNGEON_MISSING_PICKUP, name, giver, zone)
        end
      end
      lines[#lines + 1] = line
    end
  end
  if #names == 0 then
    return nil
  end
  local shown = {}
  for i = 1, math.min(#names, MISSING_NAMES) do
    shown[i] = names[i]
  end
  local list = table.concat(shown, ", ")
  if #names > MISSING_NAMES then
    list = list .. string.format(L.UPCOMING_MORE, #names - MISSING_NAMES)
  end
  lines[#lines + 1] = L.DUNGEON_MISSING_HINT
  return { id = "dungeon:missing", priority = P.QUEST_ELSEWHERE, detail = lines,
    text = string.format(L.DUNGEON_MISSING, #names, #quests.list, list) }
end

-- A dungeon's open quests (not done yet) and where each is picked up:
-- list of { id, title, level, giver, mapID, inLog }, in the log first, then
-- by level. nil without QuestieDB.
function DungeonGuide:OpenQuests(dungeon)
  local QuestieData = Pathwise:GetModule("QuestieData")
  local list = QuestieData:GetDungeonQuests(dungeon.id)
  if not list then
    return nil
  end
  local inLog = {}
  for _, quest in ipairs(Platform.GetQuestLog()) do
    if quest.questID then
      inLog[quest.questID] = true
    end
  end
  local open = {}
  for _, questID in ipairs(list) do
    if not Platform.IsQuestCompleted(questID) then
      local giver, mapID = QuestieData:GiverInfo(questID)
      open[#open + 1] = { id = questID, title = QuestieData:QuestInfo(questID, "name") or ("#" .. questID),
        level = QuestieData:QuestInfo(questID, "questLevel"), giver = giver, mapID = mapID,
        inLog = inLog[questID] == true }
    end
  end
  table.sort(open, function(a, b)
    if a.inLog ~= b.inLog then
      return a.inLog
    end
    return (a.level or 0) < (b.level or 0)
  end)
  return open
end

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
    return { { id = "dungeon:loading", priority = P.QUEST_ELSEWHERE,
      text = QuestieData:PickupsUnavailable() and L.DUNGEON_OLD_QUESTIE or L.DUNGEON_LOADING } }
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
  if #quests.list == 0 then
    items[#items + 1] = { id = "dungeon:done", priority = P.QUEST_ELSEWHERE,
      text = string.format(L.DUNGEON_NO_QUESTS, dungeon.name) }
  elseif open == 0 then
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
-- /pw dungeon toggle   switch between dungeon mode and the normal guide
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
  if args:lower() == "toggle" then
    DungeonGuide:Toggle()
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
