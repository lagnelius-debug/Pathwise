local addonName, Pathwise = ...

-- Hearthstone tip: when the player has plenty to do in a zone and the
-- hearthstone is set somewhere else, suggest setting it at an inn here.
--
-- The game only gives the bind location's name ("Dolanaar"), not where it
-- is, so the zone is learned (PathwiseCharDB.bind): when the hearthstone
-- is set (HEARTHSTONE_BOUND), when the player arrives after using it, or
-- when the player is in the town of that name. Until it's known, no tip.

local L = Pathwise.L
local Platform = Pathwise.Platform

local Hearthstone = Pathwise:NewModule("Hearthstone")

-- At least this many quest steps (quests, pickups) in the zone make it
-- worth moving the hearthstone.
Hearthstone.MIN_STEPS = 4
-- Spells that take the player to the hearthstone's inn: Hearthstone, and
-- the shaman's Astral Recall.
local RECALL_SPELLS = { [Platform.HEARTHSTONE_SPELL] = true, [556] = true }
-- After such a spell, the arrival is checked every ARRIVAL_POLL seconds:
-- recorded once the map changed, or after ARRIVAL_SETTLE seconds on the same
-- map (a short trip), but never during or right after a loading screen
-- (only once PLAYER_ENTERING_WORLD came); given up after ARRIVAL_GIVE_UP.
local ARRIVAL_POLL = 2
local ARRIVAL_SETTLE = 6
local ARRIVAL_GIVE_UP = 60

local lastItems = {}
local arrival -- { startMap, started, loading, loaded } while waiting to arrive

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

local function ZoneGroup(mapID)
  return Pathwise:GetModule("Travel").ZoneGroup(mapID)
end

-- Saves the bind location as the player's current map.
local function RecordBindHere()
  local mapID = Platform.GetPlayerMapPosition()
  local name = Platform.GetBindLocation()
  if mapID and name then
    local bind = Pathwise.charDB.bind
    bind.name, bind.mapID = name, mapID
    Hearthstone:Update()
  end
end

-- The bind location's map, or nil while it isn't known. Forgotten when
-- the bind location's name changed (set somewhere else meanwhile).
local function BindMap()
  local bind = Pathwise.charDB.bind
  local name = Platform.GetBindLocation()
  if not name then
    return nil
  end
  if bind.name ~= name then
    bind.name, bind.mapID = name, nil
  end
  -- In the town it's set to: that's where it is. (Zone names and map read
  -- together, live, so a zone border can't mix them up.)
  local here = Platform.GetZone()
  if not bind.mapID and here.mapID and (here.subZone == name or here.zone == name) then
    bind.mapID = here.mapID
  end
  return bind.mapID
end

-- Waiting to arrive after a recall spell (see RECALL_SPELLS).
local function CheckArrival()
  if not arrival then
    return
  end
  local elapsed = Platform.GetTime() - arrival.started
  local mapID = Platform.GetPlayerMapPosition()
  local waitingForLoad = arrival.loading and not arrival.loaded
  if mapID and not waitingForLoad
    and (mapID ~= arrival.startMap or arrival.loaded or elapsed >= ARRIVAL_SETTLE) then
    arrival = nil
    RecordBindHere()
  elseif elapsed < ARRIVAL_GIVE_UP then
    Platform.After(ARRIVAL_POLL, CheckArrival)
  else
    arrival = nil
  end
end

-- Pure-ish: the hearthstone step for the planned quest items, or nil.
function Hearthstone:BuildItem(items)
  if not Pathwise.db.hearthTips then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  local bindMap = BindMap()
  if not mapID or not bindMap or ZoneGroup(bindMap) == ZoneGroup(mapID) then
    return nil
  end
  local zone = ZoneGroup(mapID)
  local steps = 0
  -- (Built from the planned quest items; see OnQuestsPlanned.)
  for _, item in ipairs(items) do
    local target = item.target
    if target and (item.kind == "do" or item.kind == "turnIn" or item.kind == "pickup")
      and ZoneGroup(target.mapID) == zone then
      -- (A combined step counts each of its quests.)
      local ids = 0
      for _ in tostring(item.id):gmatch("[^+]+") do
        ids = ids + 1
      end
      steps = steps + ids
    end
  end
  if steps < Hearthstone.MIN_STEPS then
    return nil
  end

  -- The nearest innkeeper in this zone (QuestieDB), if any.
  local Waypoints = Pathwise:GetModule("Waypoints")
  local innkeepers = Pathwise:GetModule("QuestieData"):GetInnkeepers()
  local best, bestDistance
  for _, point in ipairs(innkeepers or {}) do
    if ZoneGroup(point.mapID) == zone then
      local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y, true)
      if distance and (not bestDistance or distance < bestDistance) then
        best, bestDistance = point, distance
      end
    end
  end
  if innkeepers and not best then
    return nil -- QuestieDB knows no friendly inn in this zone
  end
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local zoneName = Platform.GetMapName(zone) or GetSnapshot().zone and GetSnapshot().zone.zone or "?"
  local item = {
    id = "hearth",
    priority = P.HEARTH,
    detail = { string.format(L.HEARTH_DETAIL, steps, Pathwise.charDB.bind.name or "?") },
  }
  if best then
    item.text = string.format(L.HEARTH_STEP, zoneName, best.npcName or "?")
    item.target = { mapID = best.mapID, x = best.x, y = best.y, label = string.format(L.HEARTH_TARGET, best.npcName or "?"),
      names = { best.npcName } }
    item.subLines = { { text = string.format(L.HEARTH_TASK, best.npcName or "?"), level = 1, task = true } }
    -- Passing by the inn: do it now.
    if bestDistance <= Pathwise:GetModule("QuestAdvisor").NEAR_YARDS then
      item.priority = P.QUEST_NEAR
    end
  else
    item.text = string.format(L.HEARTH_STEP_NO_NPC, zoneName)
  end
  return item
end

function Hearthstone:Update()
  local item = self:BuildItem(lastItems)
  Pathwise:GetModule("NextSteps"):SetItems("hearth", item and { item } or {})
end

function Hearthstone:OnQuestsPlanned(_, items)
  lastItems = items or {}
  self:Update()
end

function Hearthstone:OnSpellcast(_, unit, _, spellID)
  if unit == "player" and RECALL_SPELLS[spellID] then
    local first = not arrival
    arrival = { startMap = Platform.GetPlayerMapPosition(), started = Platform.GetTime() }
    if first then
      Platform.After(ARRIVAL_POLL, CheckArrival)
    end
  end
end

-- A loading screen (another continent): the map isn't trustworthy until
-- PLAYER_ENTERING_WORLD.
function Hearthstone:OnLoadingScreen()
  if arrival then
    arrival.loading = true
  end
end

function Hearthstone:OnEnteringWorld()
  if arrival then
    arrival.loading, arrival.loaded = true, true
  end
end

function Hearthstone:OnInitialize()
  self:RegisterCallback("QUESTS_PLANNED", "OnQuestsPlanned")
  -- The innkeepers are known once QuestieDB's NPC list is scanned.
  self:RegisterCallback("QUESTIE_TRAINERS_READY", "Update")
end

function Hearthstone:OnEnable()
  self:RegisterEvent("HEARTHSTONE_BOUND", RecordBindHere)
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellcast")
  self:RegisterEvent("LOADING_SCREEN_ENABLED", "OnLoadingScreen")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
end

-- /pw hearth on|off
Pathwise:RegisterCommand("hearth", function(args)
  args = args:lower()
  if args == "on" or args == "off" then
    Pathwise.db.hearthTips = args == "on"
    Pathwise:Print(args == "on" and L.HEARTH_ON or L.HEARTH_OFF)
    Hearthstone:Update()
  else
    Pathwise:Print(L.HEARTH_USAGE)
  end
end, L.CMD_HEARTH)
