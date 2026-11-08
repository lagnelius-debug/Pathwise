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

-- The UiMap ID of a QuestieDB area ID (zone), or nil.
function QuestieData:AreaToUiMap(areaId)
  if not Load() then
    return nil
  end
  local uiMapId = areaToUiMap[areaId]
  return uiMapId ~= 0 and uiMapId or nil
end

-- A field of a quest (Get(id, key)), or nil.
function QuestieData:QuestInfo(questID, key)
  if not Load() then
    return nil
  end
  local ok, value = pcall(lib.Quest.Get, questID, key)
  return ok and value or nil
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
    local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
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
-- Custom objective texts (e.g. "Tame a Webwood Lurker" for the hunter
-- taming quests) mention the name somewhere else, but never say "slain".
local function IsCustomText(text, name)
  return text:sub(1, #name) ~= name and text:find(name, 1, true) ~= nil and not text:find(" slain", 1, true)
end

local function IsFinished(quest, name)
  if not name then
    return false
  end
  for _, objective in ipairs(quest.objectives) do
    local text = objective.text or ""
    if objective.finished and (text:sub(1, #name) == name or IsCustomText(text, name)) then
      return true
    end
  end
  return false
end

-- The client's own wording of a creature objective when it isn't the usual
-- "<name> slain: 3/10" (taming quests: "Tame a Webwood Lurker"), without
-- the count; nil otherwise.
local function CustomObjectiveText(quest, name)
  if not name then
    return nil
  end
  for _, objective in ipairs(quest.objectives) do
    local text = (objective.text or ""):gsub(":%s*%d+%s*/%s*%d+%s*$", "")
    if IsCustomText(text, name) then
      return text
    end
  end
end

-- QuestieDB's icon on a creature objective that isn't a kill: an event (be
-- somewhere or do something there - the "creature" is an invisible credit
-- marker, often just named "Credit"), an object, talking, interacting.
local NOT_A_KILL = { [3] = true, [4] = true, [5] = true, [17] = true }

-- The quest log objective for creature objective k of count (kills and kill
-- credits, in QuestieDB's order): the log's creature objectives in turn,
-- or nil when the counts don't line up.
local function CreatureLogObjective(quest, k, count)
  for _, types in ipairs({ { monster = true }, { monster = true, event = true } }) do
    local list = {}
    for _, objective in ipairs(quest.objectives) do
      if types[objective.type] then
        list[#list + 1] = objective
      end
    end
    if #list == count then
      return list[k]
    end
  end
end

-- A creature objective that isn't a kill: what to do (the quest log's
-- words without the count, else QuestieDB's, else "talk to <NPC>" or "go to
-- the marked spot") and whether it's done. Talk to: a talk objective, or an
-- event at a real NPC - one with a role (trainer, vendor, gossip: npcFlags),
-- not an invisible credit marker.
local ICON_TALK = 5

-- Invisible quest-credit markers ("Credit", "... Kill Credit", "... Bunny",
-- "... Trigger"): nothing to target there. Other NPCs of such objectives
-- are real (a beast to tame, someone to talk to): the target macro gets
-- them.
local MARKER_WORDS = { "Credit", "Bunny", "Trigger", "Invisible", "Marker" }
local function IsMarker(name)
  for _, word in ipairs(MARKER_WORDS) do
    if name:find(word, 1, true) then
      return true
    end
  end
  return false
end

local function EventObjective(quest, k, count, text, npcId, icon)
  local npcName = lib.Npc.Get(npcId, "name")
  local talk = icon == ICON_TALK
  if not talk and npcName then
    local flagsOk, flags = pcall(lib.Npc.Get, npcId, "npcFlags")
    talk = flagsOk and type(flags) == "number" and flags > 0
  end
  local logObjective = CreatureLogObjective(quest, k, count)
  local logText = logObjective and (logObjective.text or ""):gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
  if logText and (logText == "" or logText == npcName or logText:find(" slain$")) then
    logText = nil
  end
  local finished
  if logObjective then
    finished = logObjective.finished
  else
    finished = IsFinished(quest, text)
  end
  local fallback = talk and npcName and string.format(L.TASK_TALK, npcName) or L.TASK_EVENT
  return logText or text or fallback, finished
end

-- The name for the target macro of an objective's NPC, or nil for a marker.
local function TargetName(npcId)
  local name = lib.Npc.Get(npcId, "name")
  if name and not IsMarker(name) then
    return name
  end
end

-- NPC names for the target macro: the chosen point's NPC first, then the
-- other NPCs of the step in the same zone.
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
  -- Only the mobs of the zone the arrow is in: an item many creatures drop
  -- (spider meat) lists them all over the world, and the macro has room
  -- for ten.
  for _, point in ipairs(points) do
    if point.mapID == best.mapID then
      Add(point.npcName)
    end
  end
  best.names = names
  return best
end

-- "What to do here" lines for the arrow, e.g. "Kill Timberling".
local MAX_DROPPER_NAMES = 2

local function AddTask(tasks, text)
  for _, existing in ipairs(tasks) do
    if existing == text then
      return
    end
  end
  tasks[#tasks + 1] = text
end

-- Up to MAX_DROPPER_NAMES NPC names, e.g. "Timberling" or "A, B".
-- Faction letter QuestieDB uses in friendlyToFaction ("A", "H" or "AH").
local function FactionLetter()
  local faction = Pathwise:GetModule("Character"):GetSnapshot().faction
  return faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
end

-- Splits the NPCs an item comes from: droppers (mobs to kill), the item's
-- vendors (of the player's faction or neutral), and other NPCs friendly to
-- the player, who hand it out (QuestieDB lists some vendors as droppers too:
-- an innkeeper "dropping" Rhapsody Malt). Returns droppers, vendors, givers.
local function DroppersAndSellers(itemId, npcIds)
  local letter = FactionLetter()
  local droppers, sellers, givers, seen = {}, {}, {}, {}
  local function Friendly(npcId)
    local friendly = lib.Npc.Get(npcId, "friendlyToFaction")
    return type(friendly) == "string" and letter ~= nil and friendly:find(letter, 1, true) ~= nil
  end
  -- (An older QuestieDB may not know "vendors".)
  local ok, vendors = pcall(lib.Item.Get, itemId, "vendors")
  for _, npcId in ipairs(ok and type(vendors) == "table" and vendors or {}) do
    local friendly = lib.Npc.Get(npcId, "friendlyToFaction")
    -- (The other faction's vendors are no use.)
    if not seen[npcId] and (type(friendly) ~= "string" or Friendly(npcId)) then
      seen[npcId] = true
      sellers[#sellers + 1] = npcId
    end
  end
  -- A friendly NPC hands the item out only if it's more than a creature:
  -- some neutral mobs you can attack (and loot) count as friendly to both
  -- factions, but have no NPC role (npcFlags 0: no vendor, gossip, ...).
  -- Without the flags, only an NPC of the player's own faction counts.
  local function Giver(npcId)
    if not Friendly(npcId) then
      return false
    end
    local flagsOk, flags = pcall(lib.Npc.Get, npcId, "npcFlags")
    if flagsOk and type(flags) == "number" then
      return flags > 0
    end
    return lib.Npc.Get(npcId, "friendlyToFaction") == letter
  end
  for _, npcId in ipairs(npcIds or {}) do
    if not seen[npcId] then
      seen[npcId] = true
      local list = Giver(npcId) and givers or droppers
      list[#list + 1] = npcId
    end
  end
  return droppers, sellers, givers
end

local function NpcNames(npcIds)
  local names = {}
  for _, npcId in ipairs(npcIds or {}) do
    local name = lib.Npc.Get(npcId, "name")
    if name and #names < MAX_DROPPER_NAMES then
      AddTask(names, name)
    end
  end
  return table.concat(names, ", ")
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
      local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
      if distance and distance < bestDistance then
        best, bestDistance = point, distance
      end
    end
  end
  best = WithNames(best, points)
  if best and best.npcName then
    best.tasks = { string.format(L.TASK_TURN_IN, best.npcName) }
  end
  return best
end

-- What's left of a quest log entry, as tasks (the guide inside dungeons):
-- list of { kind = "kill" | "loot" | "use" | "event", npcs = { names }, item,
-- object, text } - "kill": one of npcs; "loot": item from npcs (can be
-- empty); "use": object; "event": text says what to do. nil without
-- QuestieDB (or a quest it doesn't know).
function QuestieData:QuestTasks(quest)
  if not Load() or not quest.questID then
    return nil
  end
  local ok, tasks = pcall(function()
    local objectives = lib.Quest.Get(quest.questID, "objectives") or {}
    local tasks = {}
    local creatures = #(objectives[1] or {}) + #(objectives[5] or {})
    for k, objective in ipairs(objectives[1] or {}) do
      local npcName = lib.Npc.Get(objective[1], "name")
      if NOT_A_KILL[objective[3]] then
        local text, finished = EventObjective(quest, k, creatures, objective[2], objective[1], objective[3])
        if not finished then
          tasks[#tasks + 1] = { kind = "event", text = text }
        end
      elseif not IsFinished(quest, objective[2] or npcName) then
        tasks[#tasks + 1] = { kind = "kill", npcs = { npcName or objective[2] or "?" } }
      end
    end
    for _, objective in ipairs(objectives[2] or {}) do
      local name = lib.Object.Get(objective[1], "name")
      if not IsFinished(quest, objective[2] or name) then
        tasks[#tasks + 1] = { kind = "use", object = name or objective[2] or "?" }
      end
    end
    for _, objective in ipairs(objectives[3] or {}) do
      local itemName = lib.Item.Get(objective[1], "name")
      if not IsFinished(quest, objective[2] or itemName) then
        local npcs = {}
        for _, npcId in ipairs(lib.Item.Get(objective[1], "npcDrops") or {}) do
          npcs[#npcs + 1] = lib.Npc.Get(npcId, "name")
        end
        tasks[#tasks + 1] = { kind = "loot", item = itemName or objective[2] or "?", npcs = npcs }
      end
    end
    -- [5] kill credit: { { npcIds }, rootNpcId, text?, icon }
    for j, objective in ipairs(objectives[5] or {}) do
      local npcName = lib.Npc.Get(objective[2], "name")
      if NOT_A_KILL[objective[4]] then
        local text, finished = EventObjective(quest, #(objectives[1] or {}) + j, creatures, objective[3], objective[2],
          objective[4])
        if not finished then
          tasks[#tasks + 1] = { kind = "event", text = text }
        end
      elseif not IsFinished(quest, objective[3] or npcName) then
        tasks[#tasks + 1] = { kind = "kill", npcs = { npcName or objective[3] or "?" } }
      end
    end
    return tasks
  end)
  return ok and tasks or nil
end

-- Each spawn point added since index `first` gets the task it's for (the
-- "on the way" hints say what to do there).
local function MarkTask(points, first, task)
  for i = first, #points do
    points[i].task = task
  end
end

local function DoTarget(quest)
  local objectives = lib.Quest.Get(quest.questID, "objectives") or {}
  local points, tasks = {}, {}
  local creatures = #(objectives[1] or {}) + #(objectives[5] or {})

  -- A spot to go to: the credit marker's spawns, with no NPC name (nothing
  -- to target there).
  local function EventSpots(k, npcIds, text, npcId, icon)
    local task, finished = EventObjective(quest, k, creatures, text, npcId, icon)
    if not finished then
      for _, npcId in ipairs(npcIds) do
        local first = #points + 1
        AddSpawns(points, lib.Npc.Get(npcId, "spawns"), task, TargetName(npcId))
        MarkTask(points, first, task)
      end
      AddTask(tasks, task)
    end
  end

  -- [1] creatures to kill: { npcId, text?, icon }
  for k, objective in ipairs(objectives[1] or {}) do
    local name = objective[2] or lib.Npc.Get(objective[1], "name")
    if NOT_A_KILL[objective[3]] then
      EventSpots(k, { objective[1] }, objective[2], objective[1], objective[3])
    elseif not IsFinished(quest, name) then
      local first = #points + 1
      NpcPoints(points, { objective[1] })
      local npcName = lib.Npc.Get(objective[1], "name") or name
      local task = CustomObjectiveText(quest, npcName) or string.format(L.TASK_KILL, npcName or "?")
      AddTask(tasks, task)
      MarkTask(points, first, task)
    end
  end
  -- [2] objects to use: { objectId, text?, index }
  for _, objective in ipairs(objectives[2] or {}) do
    local name = objective[2] or lib.Object.Get(objective[1], "name")
    if not IsFinished(quest, name) then
      local first = #points + 1
      ObjectPoints(points, { objective[1] })
      local task = string.format(L.TASK_USE, lib.Object.Get(objective[1], "name") or name or "?")
      AddTask(tasks, task)
      MarkTask(points, first, task)
    end
  end
  -- [3] items to collect: { itemId, text?, index }, from NPCs or objects
  for _, objective in ipairs(objectives[3] or {}) do
    local itemName = lib.Item.Get(objective[1], "name")
    if not IsFinished(quest, objective[2] or itemName) then
      local npcDrops, sellers, givers = DroppersAndSellers(objective[1], lib.Item.Get(objective[1], "npcDrops"))
      local objectDrops = lib.Item.Get(objective[1], "objectDrops")
      local first = #points + 1
      NpcPoints(points, npcDrops, nil, itemName)
      if #npcDrops > 0 then
        local task = string.format(L.TASK_LOOT, NpcNames(npcDrops), itemName or "?")
        AddTask(tasks, task)
        MarkTask(points, first, task)
      end
      first = #points + 1
      NpcPoints(points, sellers, nil, itemName)
      if #sellers > 0 then
        local task = string.format(L.TASK_BUY, itemName or "?", NpcNames(sellers))
        AddTask(tasks, task)
        MarkTask(points, first, task)
      end
      local firstGiver = #points + 1
      NpcPoints(points, givers, nil, itemName)
      if #givers > 0 then
        local task = string.format(L.TASK_GET, itemName or "?", NpcNames(givers))
        AddTask(tasks, task)
        MarkTask(points, firstGiver, task)
      end
      -- (Vendors and other friendly NPCs stand still: the arrow keeps the
      -- distance.)
      for i = first, #points do
        points[i].vendor = true
      end
      first = #points + 1
      ObjectPoints(points, objectDrops, nil, itemName)
      if objectDrops and #objectDrops > 0 then
        local task = string.format(L.TASK_COLLECT, itemName or "?")
        AddTask(tasks, task)
        MarkTask(points, first, task)
      end
    end
  end
  -- [5] kill credit: { { npcIds }, rootNpcId, text?, icon }
  for j, objective in ipairs(objectives[5] or {}) do
    local name = objective[3] or lib.Npc.Get(objective[2], "name")
    if NOT_A_KILL[objective[4]] then
      EventSpots(#(objectives[1] or {}) + j, objective[1] or {}, objective[3], objective[2], objective[4])
    elseif not IsFinished(quest, name) then
      local first = #points + 1
      NpcPoints(points, objective[1])
      local task = string.format(L.TASK_KILL, lib.Npc.Get(objective[2], "name") or name or "?")
      AddTask(tasks, task)
      MarkTask(points, first, task)
    end
  end
  local best = WithNames(Nearest(points), points)
  if best then
    best.tasks = tasks
    -- Every spawn of what's left (the "on the way" hints for other steps).
    best.spawnPoints = points
  end
  return best
end

-- Returns a target at the nearest NPC that gives quest questID, or any
-- quest of a list of IDs (e.g. a class quest not yet in the log), labelled
-- `label`, or nil.
function QuestieData:GetQuestGiverTarget(questID, label)
  if not Load() then
    return nil
  end
  local ok, target = pcall(function()
    local points = {}
    -- (One quest, or a list: the nearest giver of any of them.)
    for _, id in ipairs(type(questID) == "table" and questID or { questID }) do
      local startedBy = lib.Quest.Get(id, "startedBy") or {}
      NpcPoints(points, startedBy[1], label .. " (%s)")
    end
    for _, point in ipairs(points) do
      point.spawn = nil -- a destination, never skipped as visited
    end
    local best, bestDistance = points[1], math.huge
    local mapID, x, y = Platform.GetPlayerMapPosition()
    if mapID then
      local Waypoints = Pathwise:GetModule("Waypoints")
      for _, point in ipairs(points) do
        local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
        if distance and distance < bestDistance then
          best, bestDistance = point, distance
        end
      end
    end
    return WithNames(best, points)
  end)
  return ok and target or nil
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

---------------------------------------------------------------------------
-- Profession trainers
---------------------------------------------------------------------------

-- QuestieDB has no search by NPC title, so the NPC list is scanned once
-- for trainer titles ("Skinning Trainer", "Artisan Leatherworker", ...),
-- a chunk per frame so logging in doesn't stutter. Fires
-- QUESTIE_TRAINERS_READY when done.
local TRAINER_SCAN_CHUNK = 400
local trainerIndex -- [title] = { npcIds }, once scanned
local trainerScan  -- in progress: { ids, next }

-- Flight masters' titles, per faction's mount, and the innkeepers'.
local FLIGHT_TITLES = { "Gryphon Master", "Hippogryph Master", "Wind Rider Master", "Bat Handler", "Flight Master" }
local INNKEEPER_TITLES = { "Innkeeper" }
local OTHER_TITLES = {}
for _, list in ipairs({ FLIGHT_TITLES, INNKEEPER_TITLES }) do
  for _, title in ipairs(list) do
    OTHER_TITLES[title] = true
  end
end

local function IsTrainerTitle(title)
  return title:find(" Trainer$") ~= nil or title:find("^Journeyman ") ~= nil
    or title:find("^Expert ") ~= nil or title:find("^Artisan ") ~= nil or title:find("^Master ") ~= nil
    or OTHER_TITLES[title] ~= nil
end

local function ScanTrainerChunk()
  local scan = trainerScan
  local ok = pcall(function()
    local last = math.min(scan.next + TRAINER_SCAN_CHUNK - 1, #scan.ids)
    for i = scan.next, last do
      local id = scan.ids[i]
      local title = lib.Npc.Get(id, "subName")
      if type(title) == "string" and IsTrainerTitle(title) then
        scan.index[title] = scan.index[title] or {}
        table.insert(scan.index[title], id)
      end
    end
    scan.next = last + 1
  end)
  if ok and scan.next <= #scan.ids then
    Platform.After(0, ScanTrainerChunk)
    return
  end
  trainerIndex = ok and scan.index or {}
  trainerScan = nil
  Pathwise:FireCallback("QUESTIE_TRAINERS_READY")
end

-- True once the trainer list is ready; starts the scan if needed.
function QuestieData:TrainersReady()
  if trainerIndex then
    return true
  end
  if not trainerScan and Load() then
    local ok, ids = pcall(lib.Npc.GetAllIds)
    if ok and type(ids) == "table" then
      trainerScan = { ids = ids, next = 1, index = {} }
      Platform.After(0, ScanTrainerChunk)
    else
      trainerIndex = {} -- older QuestieDB without GetAllIds: no trainers
    end
  end
  return false
end

-- Forgets the trainer list so the next lookup scans again.
function QuestieData:ResetTrainers()
  trainerIndex, trainerScan = nil, nil
end

-- Returns a target at the nearest trainer (same continent, friendly) with
-- one of the given titles, labelled "<label> (<name>)", or nil (no
-- QuestieDB, list not scanned yet, or none on this continent).
function QuestieData:GetTrainerTarget(titles, label)
  if not self:TrainersReady() then
    return nil
  end
  local ok, target = pcall(function()
    local letter = FactionLetter()
    local points = {}
    for _, title in ipairs(titles) do
      for _, npcId in ipairs(trainerIndex[title] or {}) do
        local friendly = lib.Npc.Get(npcId, "friendlyToFaction")
        if not letter or type(friendly) ~= "string" or friendly:find(letter, 1, true) then
          NpcPoints(points, { npcId }, label .. " (%s)")
        end
      end
    end
    local mapID, x, y = Platform.GetPlayerMapPosition()
    if not mapID then
      return nil
    end
    local Waypoints = Pathwise:GetModule("Waypoints")
    local best, bestDistance
    for _, point in ipairs(points) do
      point.spawn = nil -- a destination, never skipped as visited
      local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
      if distance and (not bestDistance or distance < bestDistance) then
        best, bestDistance = point, distance
      end
    end
    -- (Only this trainer's name for the target macro.)
    return best and WithNames(best, { best })
  end)
  return ok and target or nil
end

-- Every friendly spawn of NPCs with one of the titles: list of { mapID, x,
-- y, npcName }, or nil while the NPC list isn't scanned yet (or no
-- QuestieDB). Built once per title list (and faction).
local titleCache = {} -- [titles table] = { letter, list }
local function NpcsWithTitles(titles)
  if not QuestieData:TrainersReady() then
    return nil
  end
  local cached = titleCache[titles]
  if cached and cached.letter == FactionLetter() and cached.index == trainerIndex then
    return cached.list
  end
  local ok, points = pcall(function()
    local letter = FactionLetter()
    local list = {}
    for _, title in ipairs(titles) do
      for _, npcId in ipairs(trainerIndex[title] or {}) do
        local friendly = lib.Npc.Get(npcId, "friendlyToFaction")
        if not letter or type(friendly) ~= "string" or friendly:find(letter, 1, true) then
          NpcPoints(list, { npcId })
        end
      end
    end
    return list
  end)
  if ok then
    titleCache[titles] = { letter = FactionLetter(), index = trainerIndex, list = points }
  end
  return ok and points or nil
end

function QuestieData:GetFlightMasters()
  return NpcsWithTitles(FLIGHT_TITLES)
end

function QuestieData:GetInnkeepers()
  return NpcsWithTitles(INNKEEPER_TITLES)
end

---------------------------------------------------------------------------
-- Quests to pick up
---------------------------------------------------------------------------

-- The quest list is scanned once (in chunks, like the trainers) for the
-- quests this character could ever get: race and class allowed, started by
-- an NPC or object, not repeatable, not a profession/reputation/holiday
-- quest. GetPickups then checks what's available right now. Fires
-- QUESTIE_PICKUPS_READY when the scan is done.
local PICKUP_SCAN_CHUNK = 100
local REPEATABLE_FLAG = 1 -- specialFlags bit
-- Negative zoneOrSort values are quest categories; only the class quest
-- ones are wanted (the rest are holidays, events, professions, ...).
local CLASS_SORTS = {
  [-81] = true, [-141] = true, [-261] = true, [-162] = true, [-262] = true,
  [-82] = true, [-161] = true, [-61] = true, [-263] = true,
}

-- Givers whose quests are only handed in with an item the player finds
-- (WoW Forever's libraries: Garion Wendell in Stormwind, Owen Thadd in
-- the Undercity take the books). QuestieDB doesn't say which item, so
-- their quests are suggested only while the player carries the quest's
-- item - never the donation quests without one ("Friend of the Library").
local HAND_IN_GIVERS = { [211022] = true, [211033] = true }

local pickupCandidates -- list once scanned; false: can't scan (old QuestieDB)
local pickupScan       -- in progress: { ids, next, list, raceBit, classBit }
local candidateIndex   -- the candidates by ID and by title (WouldSuggest)
local dungeonQuests = {} -- [dungeon ID] = { questIDs } (for the player's race and class)

-- bit: a power of two. Works without the bit library (and in tests).
local function HasBit(mask, bit)
  return math.floor(mask / bit) % 2 == 1
end

-- An empty mask (nil or 0) allows everyone.
local function MaskAllows(mask, bit)
  return type(mask) ~= "number" or mask == 0 or not bit or HasBit(mask, bit)
end

local function NonEmpty(value)
  return type(value) == "table" and next(value) ~= nil
end

-- Battleground areas (Warsong Gulch, Arathi Basin, Alterac Valley): their
-- quests are done in the battleground, not where the guide could lead.
local BATTLEGROUND_SORTS = { [3277] = true, [3358] = true, [2597] = true }

local function ScanQuest(id, scan)
  local Get = lib.Quest.Get
  if not MaskAllows(Get(id, "requiredRaces"), scan.raceBit)
    or not MaskAllows(Get(id, "requiredClasses"), scan.classBit) then
    return nil
  end
  if NonEmpty(Get(id, "requiredSkill")) or NonEmpty(Get(id, "requiredMinRep")) then
    return nil
  end
  local parent = Get(id, "parentQuest")
  local special = Get(id, "specialFlags")
  local sort = Get(id, "zoneOrSort")
  if (type(parent) == "number" and parent ~= 0)
    or (type(special) == "number" and HasBit(special, REPEATABLE_FLAG))
    or (type(sort) == "number" and sort < 0 and not CLASS_SORTS[sort]) or BATTLEGROUND_SORTS[sort or 0] then
    return nil
  end
  -- Dungeon quests (tagged with the dungeon's area) for the dungeon guide -
  -- also the ones an item starts. (Not repeatable ones like Dire Maul's
  -- tributes: they never count as done.)
  local dungeon = scan.dungeonAreas[sort or 0]
  if dungeon then
    scan.dungeons[dungeon] = scan.dungeons[dungeon] or {}
    table.insert(scan.dungeons[dungeon], id)
  end
  local startedBy = Get(id, "startedBy") or {}
  if not NonEmpty(startedBy[1]) and not NonEmpty(startedBy[2]) then
    return nil -- started by an item (or nothing): not a place to go
  end
  local needsItem
  if NonEmpty(startedBy[1]) and not NonEmpty(startedBy[2]) then
    local handIn = true
    for _, npcId in ipairs(startedBy[1]) do
      handIn = handIn and HAND_IN_GIVERS[npcId] == true
    end
    if handIn then
      needsItem = {}
      for _, objective in ipairs((Get(id, "objectives") or {})[3] or {}) do
        needsItem[#needsItem + 1] = objective[1]
      end
      if #needsItem == 0 then
        return nil -- a donation: nothing says what to bring
      end
    end
  end
  local requiredLevel = Get(id, "requiredLevel") or 1
  return {
    id = id,
    needsItem = needsItem,
    name = Get(id, "name"),
    requiredLevel = requiredLevel,
    level = Get(id, "questLevel") or requiredLevel,
    preSingle = Get(id, "preQuestSingle"),
    preGroup = Get(id, "preQuestGroup"),
    exclusive = Get(id, "exclusiveTo"),
    nextInChain = Get(id, "nextQuestInChain"),
    breadcrumbFor = Get(id, "breadcrumbForQuestId"),
    npcs = startedBy[1],
    objects = startedBy[2],
    dungeon = dungeon, -- a dungeon's quest (its ID), for normal mode to leave out
  }
end

local function ScanPickupChunk()
  local scan = pickupScan
  local ok = pcall(function()
    local last = math.min(scan.next + PICKUP_SCAN_CHUNK - 1, #scan.ids)
    for i = scan.next, last do
      local okQuest, candidate = pcall(ScanQuest, scan.ids[i], scan)
      if okQuest and candidate and candidate.name then
        scan.list[#scan.list + 1] = candidate
      end
    end
    scan.next = last + 1
  end)
  if ok and scan.next <= #scan.ids then
    Platform.After(0, ScanPickupChunk)
    return
  end
  pickupCandidates = ok and scan.list or false
  dungeonQuests = ok and scan.dungeons or {}
  pickupScan, candidateIndex = nil, nil
  Pathwise:FireCallback("QUESTIE_PICKUPS_READY")
end

-- True once the quest list is scanned; starts the scan if needed.
function QuestieData:PickupsReady()
  if pickupCandidates ~= nil then
    return pickupCandidates ~= false
  end
  if not pickupScan and Load() then
    local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
    local ok, ids = pcall(lib.Quest.GetAllIds)
    if ok and type(ids) == "table" then
      -- Race and class bits as in the client's masks (race 4 = 8, ...);
      -- QuestieDB's own race masks when it has them.
      local raceBit = snapshot.raceID and 2 ^ (snapshot.raceID - 1)
      local enum = lib.Enum
      if enum and type(enum.raceMaskById) == "table" and enum.raceMaskById[snapshot.raceID] then
        raceBit = enum.raceMaskById[snapshot.raceID]
      end
      -- Area ID -> dungeon ID, for the dungeon quests (Data/Classic/Dungeons.lua).
      local dungeonAreas = {}
      for _, dungeon in ipairs(Pathwise.Data.Dungeons) do
        dungeonAreas[dungeon.id] = dungeon.id
        for _, area in ipairs(dungeon.alt or {}) do
          dungeonAreas[area] = dungeon.id
        end
      end
      pickupScan = {
        ids = ids, next = 1, list = {}, dungeonAreas = dungeonAreas, dungeons = {},
        raceBit = raceBit,
        classBit = snapshot.classID and 2 ^ (snapshot.classID - 1),
      }
      Platform.After(0, ScanPickupChunk)
    else
      pickupCandidates = false -- older QuestieDB without GetAllIds
    end
  end
  return false
end

-- Forgets the scanned quest list (tests; another character's data).
function QuestieData:ResetPickups()
  pickupCandidates, pickupScan, candidateIndex, dungeonQuests = nil, nil, nil, {}
end

-- Where a candidate is started: points with .giver (NPC or object name),
-- labelled "Pick up: <quest> (<giver>)". Built once per candidate.
local function GiverPoints(candidate)
  if candidate.points then
    return candidate.points
  end
  local points = {}
  local labelFormat = string.format(L.ARROW_PICKUP, (candidate.name:gsub("%%", "%%%%")))
  for _, npcId in ipairs(candidate.npcs or {}) do
    local first = #points + 1
    NpcPoints(points, { npcId }, labelFormat)
    for i = first, #points do
      points[i].giver = points[i].npcName
    end
  end
  for _, objectId in ipairs(candidate.objects or {}) do
    local first = #points + 1
    ObjectPoints(points, { objectId }, labelFormat)
    local name = lib.Object.Get(objectId, "name")
    for i = first, #points do
      points[i].giver = name
    end
  end
  for _, point in ipairs(points) do
    point.spawn = nil -- a destination, never skipped as visited
    point.names = point.npcName and { point.npcName } or nil
  end
  candidate.points = points
  return points
end

-- The map where a candidate is turned in (its first finisher's spawn), or
-- false when unknown. Worked out once per candidate.
local function FinishMap(candidate)
  if candidate.finishMapID == nil then
    candidate.finishMapID = false
    local finishedBy = lib.Quest.Get(candidate.id, "finishedBy") or {}
    local points = {}
    NpcPoints(points, finishedBy[1])
    ObjectPoints(points, finishedBy[2])
    if points[1] then
      candidate.finishMapID = points[1].mapID
    end
  end
  return candidate.finishMapID or nil
end

-- (Negative IDs in preQuestGroup mean the same quest, without its
-- exclusive alternatives.)
local function AllCompleted(list, isCompleted)
  for _, questID in ipairs(list) do
    if not isCompleted(math.abs(questID)) then
      return false
    end
  end
  return true
end

local function AnyCompleted(list, isCompleted)
  for _, questID in ipairs(list) do
    if isCompleted(questID) then
      return true
    end
  end
  return false
end

-- Questie's own "can this character take this quest" check, when the full
-- Questie addon is loaded: it knows much more than the fields above (its
-- blacklist of quests that aren't really in the game, breadcrumbs,
-- reputation, events, ...). true/false, or nil when it can't be asked (not
-- installed, not set up yet, or changed). It's Questie's internal module,
-- not a public API, so it's only ever called protected.
local function QuestieIsDoable(questID)
  local loader = _G.QuestieLoader
  if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then
    return nil
  end
  local ok, result = pcall(function()
    return loader:ImportModule("QuestieDB").IsDoable(questID)
  end)
  if ok and type(result) == "boolean" then
    return result
  end
  return nil
end

-- True when the player hid the quest in Questie (its quest menu).
-- Questie's internal saved data, read protected.
local function QuestieHidden(questID)
  local ok, hidden = pcall(function()
    return _G.Questie.db.char.hidden[questID]
  end)
  return ok and hidden and true or false
end

local function DoneOrInLog(questID, isCompleted, inLog)
  return type(questID) == "number" and questID ~= 0 and (isCompleted(questID) or inLog[questID] == true)
end

-- Quests the player can pick up now, nearest giver first (same continent
-- only), at most `limit`:
--   { questID, title, level, target, giver, distance, finishMapID }
-- Returns nil while the quest list isn't scanned yet (or no QuestieDB).
-- ctx: { level, inLog = { [questID] = true }, outOfRange(questLevel) - true
--        for quests too easy or too hard to suggest,
--        skip(questID) - true for quests to leave out (e.g. not offered) }
-- Whether the player's race and class can take a quest at all.
function QuestieData:IsForPlayer(questID)
  if not Load() then
    return false
  end
  local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
  local ok, allowed = pcall(function()
    local Get = lib.Quest.Get
    return MaskAllows(Get(questID, "requiredRaces"), snapshot.raceID and 2 ^ (snapshot.raceID - 1))
      and MaskAllows(Get(questID, "requiredClasses"), snapshot.classID and 2 ^ (snapshot.classID - 1))
  end)
  return ok and allowed
end

-- Who starts a quest: the first giver's name and the map it stands on
-- (nil, nil when unknown, e.g. started by an item).
function QuestieData:GiverInfo(questID)
  if not Load() then
    return nil
  end
  local ok, name, mapID = pcall(function()
    local startedBy = lib.Quest.Get(questID, "startedBy") or {}
    local npcId = startedBy[1] and startedBy[1][1]
    local objectId = startedBy[2] and startedBy[2][1]
    local entity = npcId and lib.Npc or objectId and lib.Object
    local id = npcId or objectId
    if not entity then
      return nil
    end
    local map
    for areaId in pairs(entity.Get(id, "spawns") or {}) do
      map = map or areaToUiMap[areaId]
    end
    return entity.Get(id, "name"), map ~= 0 and map or nil
  end)
  if not ok then
    return nil
  end
  return name, mapID
end

-- The item that starts a quest, if an item does and no NPC or object
-- does: its name ("?" when QuestieDB doesn't know it), else nil.
function QuestieData:StarterItem(questID)
  if not Load() then
    return nil
  end
  local ok, name = pcall(function()
    local startedBy = lib.Quest.Get(questID, "startedBy") or {}
    if NonEmpty(startedBy[1]) or NonEmpty(startedBy[2]) or not NonEmpty(startedBy[3]) then
      return nil
    end
    return lib.Item.Get(startedBy[3][1], "name") or "?"
  end)
  return ok and name or nil
end

-- Whether a quest is picked up inside a dungeon (areaId: the dungeon's
-- area): no NPC or object starts it (an item does, or nobody knows yet -
-- Forever's new dungeons), or each one that does stands in the dungeon -
-- in its area, or in an instance (QuestieDB's -1, -1 spot: e.g. Kharan
-- Mighthammer, in another of Blackrock Depths' areas). nil without
-- QuestieDB.
function QuestieData:StartsInside(questID, areaId)
  if not Load() then
    return nil
  end
  local ok, inside = pcall(function()
    local startedBy = lib.Quest.Get(questID, "startedBy") or {}
    for index, entity in ipairs({ lib.Npc, lib.Object }) do
      for _, id in ipairs(startedBy[index] or {}) do
        for area, spots in pairs(entity.Get(id, "spawns") or {}) do
          if area ~= areaId then
            for _, spot in ipairs(spots) do
              if type(spot[1]) == "number" and spot[1] >= 0 then
                return false
              end
            end
          end
        end
      end
    end
    return true
  end)
  return ok and inside or nil
end

-- True when QuestieDB can't list its quests (an older version): no
-- pickups, no dungeon guide.
function QuestieData:PickupsUnavailable()
  return pickupCandidates == false
end

-- The quests of a dungeon (Data/Classic/Dungeons.lua) the player's race and
-- class can do, or nil while the quest list isn't scanned.
function QuestieData:GetDungeonQuests(dungeonID)
  if not self:PickupsReady() then
    return nil
  end
  return dungeonQuests[dungeonID] or {}
end

-- Why a scanned quest can't be suggested now (ctx as for GetPickups): a
-- reason ("level", "inLog", "range", "done", "dungeon", "pre", "exclusive",
-- "chain", "skip", "questie"), or nil when it can. (/pw why shows these.)
local function NotEligibleReason(candidate, ctx)
  local isCompleted = Platform.IsQuestCompleted
  local level = candidate.level == -1 and ctx.level or candidate.level
  if candidate.requiredLevel > ctx.level then
    return "level"
  elseif ctx.inLog[candidate.id] then
    return "inLog"
  elseif ctx.outOfRange(level, candidate.id) then
    return "range"
  elseif isCompleted(candidate.id) then
    return "done"
  -- A dungeon's quest: dungeon mode suggests it (ctx.noDungeon: normal mode).
  elseif ctx.noDungeon and candidate.dungeon then
    return "dungeon"
  elseif candidate.needsItem and not AnyCompleted(candidate.needsItem, function(item)
    return (Platform.GetItemCount(item) or 0) > 0
  end) then
    return "item"
  elseif (NonEmpty(candidate.preGroup) and not AllCompleted(candidate.preGroup, isCompleted))
    or (NonEmpty(candidate.preSingle) and not AnyCompleted(candidate.preSingle, isCompleted)) then
    return "pre"
  elseif NonEmpty(candidate.exclusive) and (AnyCompleted(candidate.exclusive, isCompleted)
    or AnyCompleted(candidate.exclusive, function(id) return ctx.inLog[id] end)) then
    return "exclusive"
  -- A later quest of the chain (or the quest a breadcrumb leads to) is
  -- already done or in the log: this one is no longer offered.
  elseif DoneOrInLog(candidate.nextInChain, isCompleted, ctx.inLog)
    or DoneOrInLog(candidate.breadcrumbFor, isCompleted, ctx.inLog) then
    return "chain"
  elseif ctx.skip and ctx.skip(candidate.id) then
    return "skip"
  -- (Questie's own check uses the player's level as it is now - older
  -- versions reject quests that need a higher one - so it's only asked
  -- about now, not about a level the player hasn't reached: ctx.future.
  -- A quest hidden in Questie stays hidden either way.)
  elseif (not ctx.future and QuestieIsDoable(candidate.id) == false) or QuestieHidden(candidate.id) then
    return "questie"
  end
  return nil
end

-- Whether a scanned quest can be suggested now (ctx as for GetPickups).
local function Eligible(candidate, ctx)
  return NotEligibleReason(candidate, ctx) == nil
end

-- Whether the guide would suggest picking up a quest now (by its ID, or by
-- its title when the client gives no ID): the same rules as GetPickups,
-- wherever the giver is. nil while the quest list isn't scanned.
local function CandidateIndex()
  if not candidateIndex then
    candidateIndex = { byId = {}, byTitle = {} }
    for _, candidate in ipairs(pickupCandidates) do
      candidateIndex.byId[candidate.id] = candidate
      local list = candidateIndex.byTitle[candidate.name] or {}
      list[#list + 1] = candidate
      candidateIndex.byTitle[candidate.name] = list
    end
  end
  return candidateIndex
end

function QuestieData:WouldSuggest(questID, title, ctx)
  if not self:PickupsReady() then
    return nil
  end
  CandidateIndex()
  local list = questID and { candidateIndex.byId[questID] } or candidateIndex.byTitle[title or ""] or {}
  for _, candidate in ipairs(list) do
    -- (ctx.only: just these quests, as in GetPickups.)
    local ok, eligible = pcall(Eligible, candidate, ctx)
    if ok and eligible and (not ctx.only or ctx.only[candidate.id]) then
      return true
    end
  end
  return false
end

-- Why the guide doesn't suggest picking up a quest now (ctx as for
-- GetPickups): a reason as NotEligibleReason gives, "unknown" for a quest
-- it never suggests (started by an item, repeatable, ...), or nil when it
-- does. nil too while the quest list isn't scanned.
function QuestieData:WhyNotSuggested(questID, ctx)
  if not self:PickupsReady() then
    return nil
  end
  local candidate = CandidateIndex().byId[questID]
  if not candidate then
    return "unknown"
  end
  local ok, reason = pcall(NotEligibleReason, candidate, ctx)
  if not ok then
    return "error"
  end
  return reason
end

-- The nearest giver spot of a quest from the player (of the spots keep
-- allows, if given), or nil: point, distance.
local function NearestGiver(candidate, mapID, x, y, keep)
  local Waypoints = Pathwise:GetModule("Waypoints")
  local ok, points = pcall(GiverPoints, candidate)
  local best, bestDistance
  for _, point in ipairs(ok and points or {}) do
    if not keep or keep(point) then
      local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
      if distance and (not bestDistance or distance < bestDistance) then
        best, bestDistance = point, distance
      end
    end
  end
  return best, bestDistance
end

-- Where a quest is picked up, as an arrow target: its giver's spot
-- nearest to the player (a pickup's target), or nil (not a quest the guide
-- knows a giver for, or the quest list isn't scanned).
function QuestieData:GiverTarget(questID)
  if not self:PickupsReady() then
    return nil
  end
  local candidate = CandidateIndex().byId[questID]
  if not candidate then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  local best, distance
  if mapID then
    best, distance = NearestGiver(candidate, mapID, x, y)
  end
  if not best then
    local ok, points = pcall(GiverPoints, candidate)
    best = ok and points and points[1] or nil
  end
  return best, distance
end

-- Quests the guide would suggest a few levels from now but not yet: they
-- need a higher level, or are still far too hard (red) at this one. The
-- same rules as GetPickups, at each level up to toLevel: { questID, title,
-- level, atLevel (the first level it's suggested at), target, giver,
-- distance }, lowest atLevel first, then nearest. nil while the quest list
-- isn't scanned. ctxFor(level): the pickup context at that level;
-- keep(target): only givers where this says so (e.g. this zone).
function QuestieData:GetUpcoming(fromLevel, toLevel, ctxFor, limit, keep)
  if not self:PickupsReady() then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return {}
  end
  local contexts, found = {}, {}
  for _, candidate in ipairs(pickupCandidates) do
    if candidate.requiredLevel <= toLevel then
      for atLevel = fromLevel + 1, toLevel do
        contexts[atLevel] = contexts[atLevel] or ctxFor(atLevel)
        local ok, eligible = pcall(Eligible, candidate, contexts[atLevel])
        if ok and eligible then
          local best, distance = NearestGiver(candidate, mapID, x, y, keep)
          if best then
            found[#found + 1] = { questID = candidate.id, title = candidate.name, atLevel = atLevel,
              level = candidate.level == -1 and atLevel or candidate.level,
              target = best, giver = best.giver, distance = distance }
          end
          break
        end
      end
    end
  end
  table.sort(found, function(a, b)
    if a.atLevel ~= b.atLevel then
      return a.atLevel < b.atLevel
    end
    return a.distance < b.distance
  end)
  for i = #found, limit + 1, -1 do
    found[i] = nil
  end
  return found
end

-- /pw why: the scanned quests matching an ID or (part of) a title, each
-- as { id, title, level, requiredLevel, giver, mapID, distance, reasons =
-- { [level] = reason or false } } for the levels fromLevel..toLevel (false:
-- suggested at that level). nil while the quest list isn't scanned.
function QuestieData:Explain(query, fromLevel, toLevel, ctxFor)
  if not self:PickupsReady() then
    return nil
  end
  local id = tonumber(query)
  local text = query:lower()
  local mapID, x, y = Platform.GetPlayerMapPosition()
  local results = {}
  for _, candidate in ipairs(pickupCandidates) do
    if (id and candidate.id == id) or (not id and candidate.name and candidate.name:lower():find(text, 1, true)) then
      local entry = { id = candidate.id, title = candidate.name, level = candidate.level,
        requiredLevel = candidate.requiredLevel, reasons = {} }
      for atLevel = fromLevel, toLevel do
        local ok, reason = pcall(NotEligibleReason, candidate, ctxFor(atLevel))
        if not ok then
          reason = "error"
        end
        entry.reasons[atLevel] = reason or false
      end
      local best, distance
      if mapID then
        best, distance = NearestGiver(candidate, mapID, x, y)
      end
      if not best then
        local ok, points = pcall(GiverPoints, candidate)
        best = ok and points and points[1]
      end
      entry.giver = best and best.giver
      entry.mapID = best and best.mapID
      entry.distance = distance
      entry.questieDoable = QuestieIsDoable(candidate.id)
      results[#results + 1] = entry
      if #results >= 5 then
        break
      end
    end
  end
  return results
end

-- Quests whose giver is within maxYards (straight line) that the guide
-- doesn't suggest now, and why: list of { id, title, level, giver,
-- distance, reason }, nearest first. (/pw why here, the bug report.)
function QuestieData:NearbyNotSuggested(ctx, maxYards, limit)
  if not self:PickupsReady() then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return {}
  end
  local Waypoints = Pathwise:GetModule("Waypoints")
  local list = {}
  for _, candidate in ipairs(pickupCandidates) do
    local ok, points = pcall(GiverPoints, candidate)
    local best, bestDistance
    for _, point in ipairs(ok and points or {}) do
      local distance = point.mapID == mapID and Waypoints.Vector(mapID, x, y, point.mapID, point.x, point.y)
      if distance and distance <= maxYards and (not bestDistance or distance < bestDistance) then
        best, bestDistance = point, distance
      end
    end
    if best then
      local okReason, reason = pcall(NotEligibleReason, candidate, ctx)
      reason = okReason and reason or (not okReason and "error") or nil
      if reason then
        local level = candidate.level == -1 and ctx.level or candidate.level
        list[#list + 1] = { id = candidate.id, title = candidate.name, level = level, giver = best.giver,
          distance = bestDistance, reason = reason }
      end
    end
  end
  table.sort(list, function(a, b) return a.distance < b.distance end)
  for i = #list, (limit or #list) + 1, -1 do
    list[i] = nil
  end
  return list
end

function QuestieData:GetPickups(ctx, limit)
  if not self:PickupsReady() then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return {}
  end
  local Waypoints = Pathwise:GetModule("Waypoints")
  local found = {}
  for _, candidate in ipairs(pickupCandidates) do
    local level = candidate.level == -1 and ctx.level or candidate.level
    -- (ctx.only: just these quests, e.g. a dungeon's.)
    if (not ctx.only or ctx.only[candidate.id]) and Eligible(candidate, ctx) then
      local ok, points = pcall(GiverPoints, candidate)
      local best, bestDistance
      for _, point in ipairs(ok and points or {}) do
        local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
        if distance and (not bestDistance or distance < bestDistance) then
          best, bestDistance = point, distance
        end
      end
      if best then
        local okFinish, finishMapID = pcall(FinishMap, candidate)
        found[#found + 1] = { questID = candidate.id, title = candidate.name, level = level,
          target = best, giver = best.giver, distance = bestDistance, finishMapID = okFinish and finishMapID or nil }
      end
    end
  end
  table.sort(found, function(a, b) return a.distance < b.distance end)
  for i = #found, limit + 1, -1 do
    found[i] = nil
  end
  return found
end
