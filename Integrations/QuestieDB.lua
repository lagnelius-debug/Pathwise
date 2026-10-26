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

local function DoTarget(quest)
  local objectives = lib.Quest.Get(quest.questID, "objectives") or {}
  local points, tasks = {}, {}

  -- [1] creatures to kill: { npcId, text?, index }
  for _, objective in ipairs(objectives[1] or {}) do
    local name = objective[2] or lib.Npc.Get(objective[1], "name")
    if not IsFinished(quest, name) then
      NpcPoints(points, { objective[1] })
      local npcName = lib.Npc.Get(objective[1], "name") or name
      AddTask(tasks, CustomObjectiveText(quest, npcName) or string.format(L.TASK_KILL, npcName or "?"))
    end
  end
  -- [2] objects to use: { objectId, text?, index }
  for _, objective in ipairs(objectives[2] or {}) do
    local name = objective[2] or lib.Object.Get(objective[1], "name")
    if not IsFinished(quest, name) then
      ObjectPoints(points, { objective[1] })
      AddTask(tasks, string.format(L.TASK_USE, lib.Object.Get(objective[1], "name") or name or "?"))
    end
  end
  -- [3] items to collect: { itemId, text?, index }, from NPCs or objects
  for _, objective in ipairs(objectives[3] or {}) do
    local itemName = lib.Item.Get(objective[1], "name")
    if not IsFinished(quest, objective[2] or itemName) then
      local npcDrops = lib.Item.Get(objective[1], "npcDrops")
      local objectDrops = lib.Item.Get(objective[1], "objectDrops")
      NpcPoints(points, npcDrops, nil, itemName)
      ObjectPoints(points, objectDrops, nil, itemName)
      if npcDrops and #npcDrops > 0 then
        AddTask(tasks, string.format(L.TASK_LOOT, NpcNames(npcDrops), itemName or "?"))
      end
      if objectDrops and #objectDrops > 0 then
        AddTask(tasks, string.format(L.TASK_COLLECT, itemName or "?"))
      end
    end
  end
  -- [5] kill credit: { { npcIds }, rootNpcId, text?, index }
  for _, objective in ipairs(objectives[5] or {}) do
    local name = objective[3] or lib.Npc.Get(objective[2], "name")
    if not IsFinished(quest, name) then
      NpcPoints(points, objective[1])
      AddTask(tasks, string.format(L.TASK_KILL, lib.Npc.Get(objective[2], "name") or name or "?"))
    end
  end
  local best = WithNames(Nearest(points), points)
  if best then
    best.tasks = tasks
  end
  return best
end

-- Returns a target at the nearest NPC that gives quest questID (e.g. a
-- class quest not yet in the log), labelled `label`, or nil.
function QuestieData:GetQuestGiverTarget(questID, label)
  if not Load() then
    return nil
  end
  local ok, target = pcall(function()
    local startedBy = lib.Quest.Get(questID, "startedBy") or {}
    local points = {}
    NpcPoints(points, startedBy[1], label .. " (%s)")
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

-- Faction letter QuestieDB uses in friendlyToFaction ("A", "H" or "AH").
local function FactionLetter()
  local faction = Pathwise:GetModule("Character"):GetSnapshot().faction
  return faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
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

local pickupCandidates -- list once scanned; false: can't scan (old QuestieDB)
local pickupScan       -- in progress: { ids, next, list, raceBit, classBit }

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
    or (type(sort) == "number" and sort < 0 and not CLASS_SORTS[sort]) then
    return nil
  end
  local startedBy = Get(id, "startedBy") or {}
  if not NonEmpty(startedBy[1]) and not NonEmpty(startedBy[2]) then
    return nil -- started by an item (or nothing): not a place to go
  end
  local requiredLevel = Get(id, "requiredLevel") or 1
  return {
    id = id,
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
  pickupScan = nil
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
      pickupScan = {
        ids = ids, next = 1, list = {},
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
  pickupCandidates, pickupScan = nil, nil
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
function QuestieData:GetPickups(ctx, limit)
  if not self:PickupsReady() then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return {}
  end
  local Waypoints = Pathwise:GetModule("Waypoints")
  local isCompleted = Platform.IsQuestCompleted
  local found = {}
  for _, candidate in ipairs(pickupCandidates) do
    local level = candidate.level == -1 and ctx.level or candidate.level
    if candidate.requiredLevel <= ctx.level and not ctx.inLog[candidate.id] and not ctx.outOfRange(level)
      and not isCompleted(candidate.id)
      and (not NonEmpty(candidate.preGroup) or AllCompleted(candidate.preGroup, isCompleted))
      and (not NonEmpty(candidate.preSingle) or AnyCompleted(candidate.preSingle, isCompleted))
      and not (NonEmpty(candidate.exclusive) and (AnyCompleted(candidate.exclusive, isCompleted)
        or AnyCompleted(candidate.exclusive, function(id) return ctx.inLog[id] end)))
      -- A later quest of the chain (or the quest a breadcrumb leads to) is
      -- already done or in the log: this one is no longer offered.
      and not DoneOrInLog(candidate.nextInChain, isCompleted, ctx.inLog)
      and not DoneOrInLog(candidate.breadcrumbFor, isCompleted, ctx.inLog)
      and not (ctx.skip and ctx.skip(candidate.id))
      and QuestieIsDoable(candidate.id) ~= false then
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
