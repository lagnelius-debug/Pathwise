local addonName, Pathwise = ...

-- Optional integration with the QuestieDB addon (the quest database that
-- Questie ships as a separate addon). When it is installed, the arrow can
-- point at quest turn-in NPCs and at the nearest spawn of what a quest still
-- needs, from the moment the quest is accepted.
--
-- Uses only QuestieDB's documented public API (LibQuestieDB, see
-- https://github.com/Questie/QuestieDB/blob/master/docs/api.md). Nothing is
-- copied; data is read at runtime. Every call is protected, so a QuestieDB
-- change can only switch the integration off, never break Pathwise.

local L = Pathwise.L
local Platform = Pathwise.Platform

local QuestieData = Pathwise:NewModule("QuestieData")

-- We only use Get(id, key) and Support.Get("ZoneDB"), available since
-- contract 1.
local REQUIRED_CONTRACT = 1

local lib            -- LibQuestieDB once loaded, false if unusable
local areaToUiMap    -- [AreaId] = UiMapId

-- Merges a QuestieDB zone table (a Lua source string or a table) into target.
local function MergeZoneTable(target, source)
  if type(source) == "string" then
    local chunk = loadstring(source)
    source = chunk and chunk()
  end
  if type(source) == "table" then
    for areaId, uiMapId in pairs(source) do
      target[areaId] = uiMapId
    end
  end
end

-- Returns LibQuestieDB if it is loaded and compatible. A missing library is
-- checked again next time; an incompatible one disables the integration.
local function Load()
  if lib ~= nil then
    return lib or nil
  end
  local candidate = _G.LibQuestieDB
  if type(candidate) ~= "table" then
    return nil
  end
  local ok = pcall(function()
    if candidate.RequireContract and not candidate.RequireContract(REQUIRED_CONTRACT) then
      error("contract")
    end
    local zoneDB = candidate.Support.Get("ZoneDB")
    local mapping = {}
    MergeZoneTable(mapping, zoneDB.private.areaIdToUiMapId)
    MergeZoneTable(mapping, zoneDB.private.areaIdToUiMapIdOverride)
    areaToUiMap = mapping
    assert(candidate.Quest.Get and candidate.Npc.Get and candidate.Item.Get and candidate.Object.Get)
  end)
  if ok then
    lib = candidate
    QuestieData:Debug("QuestieDB found; using it for quest locations.")
  else
    lib = false
    QuestieData:Debug("QuestieDB found but not compatible; integration off.")
  end
  return lib or nil
end

function QuestieData:IsAvailable()
  return Load() ~= nil
end

---------------------------------------------------------------------------
-- Spawns
---------------------------------------------------------------------------

-- Adds the spawn points of a QuestieDB spawn list ({ [AreaId] = { {x, y},
-- ... } }, coordinates 0-100) as map targets.
local function AddSpawns(points, spawnList, label, npcName)
  for areaId, coordinates in pairs(spawnList or {}) do
    local uiMapId = areaToUiMap[areaId]
    if uiMapId and uiMapId ~= 0 then
      for _, coordinate in ipairs(coordinates) do
        local x, y = coordinate[1], coordinate[2]
        if x and y and x >= 0 and y >= 0 then
          points[#points + 1] = {
            mapID = uiMapId,
            x = x / 100,
            y = y / 100,
            label = label,
            spawn = true,
            npcName = npcName, -- nil for objects (they can't be targeted)
          }
        end
      end
    end
  end
end

-- The point closest to the player (same continent). Spots where quest
-- progress recently happened, or that the player skipped, are left out, so
-- after a kill or a loot the arrow moves on to the next spawn; if every
-- spawn is left out, the closest one is used anyway (it has probably
-- respawned by the time you get there).
local function Nearest(points)
  if #points == 0 then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return points[1]
  end
  local Waypoints = Pathwise:GetModule("Waypoints")
  local best, bestDistance = nil, math.huge
  local fallback, fallbackDistance = nil, math.huge
  for _, point in ipairs(points) do
    local distance = Waypoints.Vector(mapID, x, y, point.mapID, point.x, point.y)
    if distance then
      if distance < fallbackDistance then
        fallback, fallbackDistance = point, distance
      end
      if not Waypoints:IsVisited(point) and distance < bestDistance then
        best, bestDistance = point, distance
      end
    end
  end
  return best or fallback or points[1]
end

-- Arrow label for a spawn of `name` (an NPC or object).
-- labelFormat: e.g. "Turn in: Webwood Venom (%s)"; itemName: the quest item
-- it drops, shown as "Item (Dropper)", or just "Item" when both names are
-- the same (e.g. the Hyacinth Mushroom object drops Hyacinth Mushrooms).
local function Label(name, labelFormat, itemName)
  if labelFormat then
    return string.format(labelFormat, name or "?")
  elseif itemName and name and name ~= itemName then
    return itemName .. " (" .. name .. ")"
  end
  return itemName or name
end

local function NpcPoints(points, npcIds, labelFormat, itemName)
  for _, npcId in ipairs(npcIds or {}) do
    local name = lib.Npc.Get(npcId, "name")
    AddSpawns(points, lib.Npc.Get(npcId, "spawns"), Label(name, labelFormat, itemName), name)
  end
end

local function ObjectPoints(points, objectIds, labelFormat, itemName)
  for _, objectId in ipairs(objectIds or {}) do
    local name = lib.Object.Get(objectId, "name")
    AddSpawns(points, lib.Object.Get(objectId, "spawns"), Label(name, labelFormat, itemName))
  end
end

---------------------------------------------------------------------------
-- Quest targets
---------------------------------------------------------------------------

-- True if the client's objective list shows `name` as already finished.
-- Objective texts look like "Webwood Venom Sac: 6/10" or "Webwood Spider
-- slain: 3/10", so a finished objective starting with the name matches.
local function IsFinished(quest, name)
  if not name then
    return false
  end
  for _, objective in ipairs(quest.objectives) do
    local text = objective.text or ""
    if objective.finished and text:sub(1, #name) == name then
      return true
    end
  end
  return false
end

-- NPC names for the target macro: the chosen point's NPC first, then the
-- other NPCs of the step.
local function WithNames(best, points)
  if not best then
    return nil
  end
  local names, seen = {}, {}
  local function Add(name)
    if name and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  Add(best.npcName)
  for _, point in ipairs(points) do
    Add(point.npcName)
  end
  best.names = names
  return best
end

local function TurnInTarget(quest)
  local finishedBy = lib.Quest.Get(quest.questID, "finishedBy") or {}
  local points = {}
  local labelFormat = string.format(L.ARROW_QUESTIE_TURN_IN, quest.title, "%s")
  NpcPoints(points, finishedBy[1], labelFormat)
  ObjectPoints(points, finishedBy[2], labelFormat)
  -- The turn-in NPC is the destination itself: never skip it as visited.
  for _, point in ipairs(points) do
    point.spawn = nil
  end
  local best, bestDistance = points[1], math.huge
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if mapID then
    local Waypoints = Pathwise:GetModule("Waypoints")
    for _, point in ipairs(points) do
      local distance = Waypoints.Vector(mapID, x, y, point.mapID, point.x, point.y)
      if distance and distance < bestDistance then
        best, bestDistance = point, distance
      end
    end
  end
  return WithNames(best, points)
end

local function DoTarget(quest)
  local objectives = lib.Quest.Get(quest.questID, "objectives") or {}
  local points = {}

  -- [1] creatures to kill: { npcId, text?, index }
  for _, objective in ipairs(objectives[1] or {}) do
    local name = objective[2] or lib.Npc.Get(objective[1], "name")
    if not IsFinished(quest, name) then
      NpcPoints(points, { objective[1] })
    end
  end
  -- [2] objects to use: { objectId, text?, index }
  for _, objective in ipairs(objectives[2] or {}) do
    local name = objective[2] or lib.Object.Get(objective[1], "name")
    if not IsFinished(quest, name) then
      ObjectPoints(points, { objective[1] })
    end
  end
  -- [3] items to collect: { itemId, text?, index }, from NPCs or objects
  for _, objective in ipairs(objectives[3] or {}) do
    local itemName = lib.Item.Get(objective[1], "name")
    if not IsFinished(quest, objective[2] or itemName) then
      NpcPoints(points, lib.Item.Get(objective[1], "npcDrops"), nil, itemName)
      ObjectPoints(points, lib.Item.Get(objective[1], "objectDrops"), nil, itemName)
    end
  end
  -- [5] kill credit: { { npcIds }, rootNpcId, text?, index }
  for _, objective in ipairs(objectives[5] or {}) do
    local name = objective[3] or lib.Npc.Get(objective[2], "name")
    if not IsFinished(quest, name) then
      NpcPoints(points, objective[1])
    end
  end
  return WithNames(Nearest(points), points)
end

-- Returns a target { mapID, x, y, label } for a quest step, or nil.
-- kind: "turnIn" or "do".
function QuestieData:GetTarget(quest, kind)
  if not quest.questID or not Load() then
    return nil
  end
  local ok, target = pcall(kind == "turnIn" and TurnInTarget or DoTarget, quest)
  if not ok then
    self:Debugf("QuestieDB lookup failed for quest %s: %s", tostring(quest.questID), tostring(target))
    return nil
  end
  return target
end
