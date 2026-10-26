local addonName, Pathwise = ...

-- Known flight points. The game only tells addons which flight points a
-- character knows while a flight map is open, so they're saved per
-- character each time the player talks to a flight master
-- (PathwiseCharDB.flightNodes). The flight master the player is standing
-- at is saved at the player's position; the others at the flight master
-- QuestieDB knows near their spot on the flight map, or at that spot.
-- Core/Travel.lua uses them to suggest flying when it's clearly faster.

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local Flights = Pathwise:NewModule("Flights")

-- A flight map spot is matched to a QuestieDB flight master this close.
local MATCH_YARDS = 600

-- GetNodes results per continent; cleared whenever the saved points change.
local nodeCache = {}

local function Waypoints()
  return Pathwise:GetModule("Waypoints")
end

-- The continent a map is on (world instance ID), or nil.
local function ContinentOf(mapID)
  local rect = Platform.GetMapWorldRect(mapID)
  return rect and rect.continent
end

-- Town name from a flight point name: "Rut'theran Village, Teldrassil" ->
-- "Rut'theran Village".
function Flights.TownName(nodeName)
  return (nodeName or "?"):match("^([^,]+)") or nodeName
end

-- Nearest QuestieDB flight master to a map position (same continent, within
-- MATCH_YARDS), or nil.
local function MatchFlightMaster(mapID, x, y)
  local masters = Pathwise:GetModule("QuestieData"):GetFlightMasters()
  local best, bestDistance
  for _, point in ipairs(masters or {}) do
    local distance = Waypoints().Vector(mapID, x, y, point.mapID, point.x, point.y)
    if distance and distance <= MATCH_YARDS and (not bestDistance or distance < bestDistance) then
      best, bestDistance = point, distance
    end
  end
  return best
end

-- Saves the flight points of the open flight map.
function Flights:OnTaxiMapOpened()
  local nodes = Platform.GetTaxiNodes()
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if #nodes == 0 or not mapID then
    return
  end
  local continent = ContinentOf(mapID)
  local continentMap = continent and Data.Travel.CONTINENT_MAPS[continent]
  local saved = Pathwise.charDB.flightNodes
  local count = 0
  for _, node in ipairs(nodes) do
    if node.name and (node.state == "CURRENT" or node.state == "REACHABLE") then
      local entry
      if node.state == "CURRENT" then
        -- Standing at it: the exact spot and the flight master's name.
        entry = { mapID = mapID, x = x, y = y, npc = Platform.GetInteractionNPCName(), exact = true }
      elseif saved[node.name] and saved[node.name].exact then
        entry = saved[node.name]
      elseif continentMap and node.x and node.y then
        -- The flight map shows the continent: its spot, or better the
        -- flight master QuestieDB knows there.
        local master = MatchFlightMaster(continentMap, node.x, node.y)
        if master then
          entry = { mapID = master.mapID, x = master.x, y = master.y, npc = master.npcName, exact = true }
        else
          entry = { mapID = continentMap, x = node.x, y = node.y, taxiX = node.x, taxiY = node.y }
        end
      end
      if entry then
        entry.continent = continent
        saved[node.name] = entry
        count = count + 1
      end
    end
  end
  self:Debugf("Saved %d known flight points.", count)
  nodeCache = {}
  Pathwise:FireCallback("FLIGHTS_UPDATED")
end

-- Spots saved before QuestieDB's NPC list was ready: match them now.
function Flights:OnFlightMastersReady()
  local changed = false
  for _, entry in pairs(Pathwise.charDB.flightNodes) do
    if not entry.exact and entry.taxiX then
      local master = MatchFlightMaster(entry.mapID, entry.taxiX, entry.taxiY)
      if master then
        entry.mapID, entry.x, entry.y, entry.npc, entry.exact = master.mapID, master.x, master.y, master.npcName, true
        changed = true
      end
    end
  end
  if changed then
    nodeCache = {}
    Pathwise:FireCallback("FLIGHTS_UPDATED")
  end
end

-- Known flight points on a continent: list of { name, town, mapID, x, y, npc }.
function Flights:GetNodes(continent)
  local saved = Pathwise.charDB.flightNodes
  local cached = nodeCache[continent]
  if cached and cached.saved == saved then
    return cached.list
  end
  local list = {}
  for name, entry in pairs(saved) do
    if entry.continent == continent then
      list[#list + 1] = { name = name, town = Flights.TownName(name), mapID = entry.mapID, x = entry.x, y = entry.y,
        npc = entry.npc }
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  -- (Keyed to the saved table too: /pw reset replaces it.)
  nodeCache[continent] = { saved = saved, list = list }
  return list
end

-- Forgets the cached lists (the saved points were changed directly).
function Flights:ClearCache()
  nodeCache = {}
end

function Flights:OnInitialize()
  self:RegisterCallback("QUESTIE_TRAINERS_READY", "OnFlightMastersReady")
end

function Flights:OnEnable()
  self:RegisterEvent("TAXIMAP_OPENED", "OnTaxiMapOpened")
end

-- /pw flights: list the known flight points.
Pathwise:RegisterCommand("flights", function()
  local names = {}
  for name in pairs(Pathwise.charDB.flightNodes) do
    names[#names + 1] = Flights.TownName(name)
  end
  table.sort(names)
  if #names == 0 then
    Pathwise:Print(L.FLIGHTS_NONE)
  else
    Pathwise:Printf(L.FLIGHTS_KNOWN, table.concat(names, ", "))
  end
end, L.CMD_FLIGHTS)
