-- Flight paths: learning known flight points, flying when it's faster.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Travel = Pathwise:GetModule("Travel")
local Flights = Pathwise:GetModule("Flights")
local Waypoints = Pathwise:GetModule("Waypoints")
local Arrow = Pathwise:GetModule("Arrow")
local arrow = _G.PathwiseArrow

local function Near(a, b) return math.abs(a - b) < 1e-6 end
local function At(mapID, x, y) S.mapID, S.mapX, S.mapY = mapID, x, y end

-- Kalimdor map position of a zone map position (mock world, see mock_wow).
local function OnKalimdor(mapID, x, y)
  local _, north, west = Waypoints.ToWorld(mapID, x, y)
  return (14000 - west) / 20000, (12000 - north) / 20000
end

---------------------------------------------------------------------------
section("Flights: learning the known flight points")

Pathwise.charDB.flightNodes = {}
Flights:ClearCache()
WoW.ClearChat()
WoW.Slash("flights")
check("none known yet: says how to learn them", WoW.ChatContains("Talk to a flight master once"))

-- QuestieDB knows the flight master in Auberdine (not the made-up southern one)
local npcGet = LibQuestieDB.Npc.Get
local masters = {
  [9301] = { name = "Caylais Moonfeather", subName = "Hippogryph Master", friendlyToFaction = "A",
    spawns = { [148] = { { 36, 45 } } } },
}
LibQuestieDB.Npc.Get = function(id, key)
  if masters[id] then return masters[id][key] end
  return npcGet(id, key)
end
LibQuestieDB.Npc.GetAllIds = function() return { 9301 } end
Pathwise:GetModule("QuestieData"):ResetTrainers()
Pathwise:GetModule("QuestieData"):TrainersReady()
WoW.RunTimers()

local rutX, rutY = OnKalimdor(1438, 0.58, 0.93)
local aubX, aubY = OnKalimdor(1439, 0.36, 0.45)
local southX, southY = OnKalimdor(1439, 0.50, 0.97)
local taxi = {
  { "Rut'theran Village, Teldrassil", "CURRENT", rutX, rutY },
  { "Auberdine, Darkshore", "REACHABLE", aubX + 0.004, aubY - 0.003 }, -- flight map spots are rough
  { "Southern Point, Darkshore", "REACHABLE", southX, southY },
  { "Astranaar, Ashenvale", "NONE", 0.3, 0.5 },
}
function NumTaxiNodes() return #taxi end
function TaxiNodeName(i) return taxi[i][1] end
function TaxiNodeGetType(i) return taxi[i][2] end
function TaxiNodePosition(i) return taxi[i][3], taxi[i][4] end

At(1438, 0.58, 0.93)
S.npcName = "Vesprystus"
WoW.FireEvent("TAXIMAP_OPENED")
S.npcName = nil
local saved = Pathwise.charDB.flightNodes
check("only the known ones are saved", saved["Rut'theran Village, Teldrassil"] and saved["Auberdine, Darkshore"]
  and saved["Southern Point, Darkshore"] and not saved["Astranaar, Ashenvale"])
local rut = saved["Rut'theran Village, Teldrassil"]
check("the one you stand at: your spot and the flight master's name", rut.mapID == 1438 and Near(rut.x, 0.58)
  and rut.npc == "Vesprystus")
local aub = saved["Auberdine, Darkshore"]
check("others: matched to QuestieDB's flight master there", aub.mapID == 1439 and Near(aub.x, 0.36) and Near(aub.y, 0.45)
  and aub.npc == "Caylais Moonfeather")
local south = saved["Southern Point, Darkshore"]
check("no flight master known there: the flight map spot", south.mapID == 1414 and Near(south.x, southX))
WoW.ClearChat()
WoW.Slash("flights")
check("/pw flights lists them", WoW.ChatContains("Known flight points: Auberdine, Rut'theran Village, Southern Point"))

---------------------------------------------------------------------------
section("Flights: when to fly")

-- In Auberdine, going to the far south of Darkshore (about 2200 yd)
local route = Travel.Route(1439, 0.37, 0.46, 1439, 0.50, 0.99)
check("a long trip: fly from the nearest flight point", route and #route.legs == 1 and route.legs[1].flight
  and route.legs[1].text == "Fly from Auberdine to Southern Point (Caylais Moonfeather)")
local onFoot = Waypoints.Vector(1439, 0.37, 0.46, 1439, 0.50, 0.99)
check("counts as much shorter than walking", route.distance < onFoot * Travel.FLIGHT_SAVING)
check("a short trip: walk", Travel.Route(1439, 0.37, 0.46, 1439, 0.40, 0.55) == nil)

-- From the top of Teldrassil: down through the portal, then fly
route = Travel.Route(1438, 0.60, 0.50, 1439, 0.50, 0.99)
check("portal first, then the flight from Rut'theran", route and route.legs[1].label == "TRAVEL_PORTAL_TO_RUTTHERAN"
  and route.legs[2].flight and route.legs[2].text:find("^Fly from Rut'theran Village to Southern Point") ~= nil)

-- The arrow
S.facing = 0
At(1439, 0.37, 0.46)
Waypoints:SetManual({ mapID = 1439, x = 0.50, y = 0.99, label = "Far south" })
Arrow:Update()
check("arrow: fly from here, the step underneath", arrow.label:GetText()
  == "Fly from Auberdine to Southern Point (Caylais Moonfeather)\nthen: Far south")
UnitOnTaxi = function() return true end
local _, _, via = Waypoints:GetDirection()
check("in the air: straight at the target", via == nil)
UnitOnTaxi = nil
Waypoints:ClearManual()

-- Without known flight points: on foot as before
Pathwise.charDB.flightNodes = {}
Flights:ClearCache()
check("no known flight points: no flights", Travel.Route(1439, 0.37, 0.46, 1439, 0.50, 0.99) == nil)

-- Clean up
LibQuestieDB.Npc.Get, LibQuestieDB.Npc.GetAllIds = npcGet, nil
Pathwise:GetModule("QuestieData"):ResetTrainers()
NumTaxiNodes, TaxiNodeName, TaxiNodeGetType, TaxiNodePosition = nil, nil, nil, nil
At(1438, 0.58, 0.40)
