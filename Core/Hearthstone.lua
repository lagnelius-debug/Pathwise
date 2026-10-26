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
-- After using the hearthstone, the arrival spot is recorded this much later.
local ARRIVAL_DELAY = 5

local lastItems = {}

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
  -- In the town it's set to: that's where it is.
  local zone = GetSnapshot().zone or {}
  if not bind.mapID and (zone.subZone == name or zone.zone == name) then
    bind.mapID = Platform.GetPlayerMapPosition()
  end
  return bind.mapID
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
  local best, bestDistance
  for _, point in ipairs(Pathwise:GetModule("QuestieData"):GetInnkeepers() or {}) do
    if ZoneGroup(point.mapID) == zone then
      local distance = Waypoints.TravelDistance(mapID, x, y, point.mapID, point.x, point.y)
      if distance and (not bestDistance or distance < bestDistance) then
        best, bestDistance = point, distance
      end
    end
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
  if unit == "player" and spellID == Platform.HEARTHSTONE_SPELL then
    Platform.After(ARRIVAL_DELAY, RecordBindHere)
  end
end

function Hearthstone:OnInitialize()
  self:RegisterCallback("QUESTS_PLANNED", "OnQuestsPlanned")
end

function Hearthstone:OnEnable()
  self:RegisterEvent("HEARTHSTONE_BOUND", RecordBindHere)
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellcast")
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
