-- Boats and zeppelins: between the continents, Feathermoon, and the
-- faction's own docks and towers (Data/Classic/Travel.lua).
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Travel = Pathwise:GetModule("Travel")
local Flights = Pathwise:GetModule("Flights")
local Waypoints = Pathwise:GetModule("Waypoints")
local Arrow = Pathwise:GetModule("Arrow")
local arrow = _G.PathwiseArrow
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()

local function At(mapID, x, y) S.mapID, S.mapX, S.mapY = mapID, x, y end
local function Labels(route)
  local labels = {}
  for _, leg in ipairs(route and route.legs or {}) do labels[#labels + 1] = leg.label or "flight" end
  return table.concat(labels, ", ")
end

local savedFaction, savedNodes = snapshot.faction, Pathwise.charDB.flightNodes
Pathwise.charDB.flightNodes = {}
Flights:ClearCache()

---------------------------------------------------------------------------
section("Boats: Alliance")

snapshot.faction = "Alliance"
local route = Travel.Route(1439, 0.40, 0.40, 1437, 0.50, 0.50)
check("Darkshore to the Wetlands: the Auberdine boat to Menethil (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_BOAT_AUBERDINE_TO_MENETHIL")
route = Travel.Route(1445, 0.70, 0.50, 1437, 0.10, 0.60)
check("Dustwallow Marsh to Menethil: the Theramore boat (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_BOAT_THERAMORE_TO_MENETHIL")
route = Travel.Route(1413, 0.60, 0.40, 1434, 0.30, 0.70)
check("the Barrens to Booty Bay: the Ratchet boat (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_BOAT_RATCHET_TO_BOOTY_BAY")
route = Travel.Route(1437, 0.10, 0.60, 1439, 0.40, 0.40)
check("and back from Menethil to Auberdine", Labels(route) == "TRAVEL_BOAT_MENETHIL_TO_AUBERDINE")
route = Travel.Route(1411, 0.50, 0.50, 1420, 0.60, 0.60)
check("no zeppelins for the Alliance (" .. Labels(route) .. ")", route and not Labels(route):find("ZEPPELIN"))
check("a trip across the sea has a distance on foot too",
  (Waypoints.TravelDistance(1439, 0.40, 0.40, 1437, 0.50, 0.50, true) or 0) > 1500)

-- Feathermoon Stronghold is on an island off Feralas.
check("Feathermoon is its own region", Travel.RegionOf(1444, 0.30, 0.43) == "FEATHERMOON"
  and Travel.RegionOf(1444, 0.50, 0.50) == "KALIMDOR")
route = Travel.Route(1444, 0.50, 0.50, 1444, 0.30, 0.43)
check("Feralas to Feathermoon: the ferry", Labels(route) == "TRAVEL_BOAT_TO_FEATHERMOON")

-- With flight points known on the other side: boat, then fly on.
Pathwise.charDB.flightNodes = {
  ["Menethil Harbor, Wetlands"] = { continent = 0, mapID = 1437, x = 0.10, y = 0.60, npc = "Shellei Brondir" },
  ["Stormwind, Elwynn"] = { continent = 0, mapID = 1429, x = 0.50, y = 0.50, npc = "Dungar Longdrink" },
}
Flights:ClearCache()
route = Travel.Route(1439, 0.40, 0.40, 1429, 0.50, 0.50)
check("Darkshore to Elwynn: the boat to Menethil, then the flight to Stormwind (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_BOAT_AUBERDINE_TO_MENETHIL, flight" and route.legs[2].text:find("Menethil Harbor", 1, true))
Pathwise.charDB.flightNodes = {}
Flights:ClearCache()

-- The arrow leads to the dock and says which boat.
S.facing = 0
At(1439, 0.40, 0.40)
Waypoints:SetManual({ mapID = 1437, x = 0.50, y = 0.50, label = "Wetlands quest" })
Arrow:Update()
check("arrow: to the Menethil boat first", arrow.label:GetText()
  == "Take the boat to Menethil Harbor (Auberdine docks)\nthen: Wetlands quest")
Waypoints:ClearManual()

---------------------------------------------------------------------------
section("Zeppelins: Horde")

snapshot.faction = "Horde"
route = Travel.Route(1411, 0.50, 0.50, 1420, 0.60, 0.60)
check("Durotar to Tirisfal: the zeppelin to Undercity (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_ZEPPELIN_ORGRIMMAR_TO_UNDERCITY")
route = Travel.Route(1411, 0.50, 0.50, 1434, 0.30, 0.30)
check("Durotar to Grom'gol: the zeppelin to Grom'gol (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_ZEPPELIN_ORGRIMMAR_TO_GROMGOL")
route = Travel.Route(1420, 0.60, 0.60, 1434, 0.30, 0.30)
check("Tirisfal to Stranglethorn: the zeppelin beats the long walk (" .. Labels(route) .. ")",
  Labels(route) == "TRAVEL_ZEPPELIN_UNDERCITY_TO_GROMGOL")
route = Travel.Route(1420, 0.60, 0.60, 1420, 0.40, 0.40)
check("a short trip in Tirisfal: no zeppelin", route == nil)
route = Travel.Route(1439, 0.40, 0.40, 1437, 0.50, 0.50)
check("no Alliance boats for the Horde (" .. Labels(route) .. ")", route and not Labels(route):find("MENETHIL")
  and not Labels(route):find("FEATHERMOON"))
route = Travel.Route(1444, 0.50, 0.50, 1444, 0.30, 0.43)
check("no Feathermoon ferry for the Horde", route == nil)

snapshot.faction = savedFaction
Pathwise.charDB.flightNodes = savedNodes
Flights:ClearCache()
At(1438, 0.5, 0.5)
