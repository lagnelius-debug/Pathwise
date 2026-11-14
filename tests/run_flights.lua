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

-- Reported in game: at Vesprystus in Rut'theran, going to For Love Eternal
-- in Auberdine, the arrow said to take the boat - the flight is right there
-- and much faster (the boat's crossing used to count as instant).
route = Travel.Route(1438, 0.58, 0.93, 1439, 0.37, 0.44)
check("at the flight master, across the sea: fly, not the boat", route and #route.legs == 1 and route.legs[1].flight
  and route.legs[1].text == "Fly from Rut'theran Village to Auberdine (Vesprystus)")
Pathwise.charDB.flightNodes, saved = {}, Pathwise.charDB.flightNodes
Flights:ClearCache()
route = Travel.Route(1438, 0.58, 0.93, 1439, 0.37, 0.44)
check("without the flight point: the boat", route and route.legs[1].label == "TRAVEL_BOAT_TO_AUBERDINE")
Pathwise.charDB.flightNodes = saved
Flights:ClearCache()

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

---------------------------------------------------------------------------
section("Flights: the flight timer")

-- Asked for in game: a bar under the To-do window that counts down while
-- flying and ends on landing.
local FlightTimer = Pathwise:GetModule("FlightTimer")
local bar = _G.PathwiseFlightTimer
Pathwise.db.flightTimes = {}
At(1438, 0.58, 0.93)
WoW.now = 1000
TakeTaxiNode(2) -- Rut'theran Village -> Auberdine
WoW.RunTickers()
check("picked, not in the air yet: no bar", not bar:IsShown())
UnitOnTaxi = function() return true end
WoW.now = 1001
WoW.RunTickers()
local first = FlightTimer:GetFlight()
check("flying: the bar, an estimate from the distance (" .. tostring(bar.text:GetText()) .. ")", bar:IsShown()
  and first and first.estimated and first.duration > 20
  and bar.text:GetText():find("^Flying to Auberdine · ~%d+:%d%d$") ~= nil and bar._value == 1)
WoW.now = 1001 + first.duration / 2
WoW.RunTickers()
check("halfway: half full", bar._value and math.abs(bar._value - 0.5) < 0.02)
WoW.now = 1001 + first.duration + 5
WoW.RunTickers()
-- Reported: "Landing in Ironforge" while far from Ironforge - an estimate
-- that ran out isn't a landing.
check("past the estimate, still flying: how long, not \"landing\" (" .. tostring(bar.text:GetText()) .. ")",
  bar.text:GetText():find("^Flying to Auberdine · %d+:%d%d %(longer than estimated%)$") ~= nil and bar._value == 0)
UnitOnTaxi = nil
WoW.now = 1001 + 75
WoW.RunTickers()
check("landed: the bar goes, the real time is learned", not bar:IsShown()
  and Pathwise.db.flightTimes["Rut'theran Village, Teldrassil > Auberdine, Darkshore"] == 75)
WoW.now = 2000
TakeTaxiNode(2)
UnitOnTaxi = function() return true end
WoW.now = 2001
WoW.RunTickers()
check("next time: the learned time, no \"~\" (" .. tostring(bar.text:GetText()) .. ")",
  bar.text:GetText() == "Flying to Auberdine · 1:15")
WoW.now = 2001 + 80
WoW.RunTickers()
check("a learned time ran out: landing", bar.text:GetText() == "Landing in Auberdine")
UnitOnTaxi = nil
WoW.now = 2008
WoW.RunTickers()
check("a flight cut short isn't learned", Pathwise.db.flightTimes["Rut'theran Village, Teldrassil > Auberdine, Darkshore"] == 75)
-- The route on the flight map: Rut'theran to Auberdine by way of Southern
-- Point is much longer than the straight line, and the estimate says so.
function GetNumRoutes(index) return index == 2 and 2 or 1 end
function TaxiGetNodeSlot(index, route, source)
  if index ~= 2 then return source and 1 or index end
  if route == 1 then return source and 1 or 3 end
  return source and 3 or 2
end
Pathwise.db.flightTimes = {}
local straight = FlightTimer.Duration("Rut'theran Village, Teldrassil", "Auberdine, Darkshore")
WoW.now = 2500
TakeTaxiNode(2)
UnitOnTaxi = function() return true end
WoW.now = 2501
WoW.RunTickers()
local viaHops = FlightTimer:GetFlight()
check("the estimate follows the route's hops (" .. tostring(straight) .. " s straight, "
  .. tostring(viaHops and viaHops.duration) .. " s by the route)", viaHops and viaHops.estimated
  and viaHops.duration > straight * 1.5)
UnitOnTaxi = nil
WoW.now = 2600
WoW.RunTickers()
-- Recorded times (Data/Classic/FlightTimes.lua, by taxi node ID): the
-- first flight on a route counts down from what InFlight's players
-- recorded (reported: the estimate was still off, e.g. to Booty Bay).
local RecordedTime = FlightTimer.RecordedTime
Pathwise.Data.FlightTimes.Test = { [1] = { [2] = 10, [3] = 25 }, [3] = { [4] = 40 } }
local whole, partly = RecordedTime({ 1, 2 }, "Test")
check("recorded: the whole flight's time", whole == 10 and partly == false)
whole, partly = RecordedTime({ 1, 2, 3, 4 }, "Test")
check("else the recorded parts of the route, added up (an estimate)", whole == 65 and partly == true)
check("a part not recorded: nothing", RecordedTime({ 1, 5, 4 }, "Test") == nil
  and RecordedTime({ 1 }, "Test") == nil and RecordedTime(nil, "Test") == nil and RecordedTime({ 1, 2 }, "Nobody") == nil)
Pathwise.Data.FlightTimes.Test = nil
check("the real data: Stormwind to Booty Bay 4:05 (Alliance), the Horde's own",
  RecordedTime({ 2, 19 }, "Alliance") == 245 and RecordedTime({ 27, 26 }, "Horde") == nil
  and RecordedTime({ 27, 26 }, "Alliance") == 86)
local taxiIDs = { 27, 26, 999 } -- Rut'theran, Auberdine, Southern Point (none recorded)
C_TaxiMap = { GetAllTaxiNodes = function(mapID)
  local nodes = {}
  for slot, id in ipairs(taxiIDs) do nodes[#nodes + 1] = { slotIndex = slot, nodeID = id } end
  return mapID == 1414 and nodes or {}
end }
GetTaxiMapID = function() return 1414 end
-- Points not recorded (Forever's own, say): the estimate from the hops.
taxiIDs = { 27, 998, 999 }
Pathwise.db.flightTimes = {}
WoW.now = 2700
TakeTaxiNode(2)
UnitOnTaxi = function() return true end
WoW.now = 2701
WoW.RunTickers()
local f = FlightTimer:GetFlight()
check("a route not recorded: estimated from its hops (" .. tostring(f and f.duration) .. " vs " .. tostring(straight) .. ", " .. tostring(f and f.estimated) .. ")", f and f.estimated and f.duration > straight * 1.5)
UnitOnTaxi = nil
WoW.now = 2800
WoW.RunTickers()
-- Straight there: recorded, exact.
taxiIDs = { 27, 26, 999 }
Pathwise.db.flightTimes = {}
GetNumRoutes = function() return 1 end
TaxiGetNodeSlot = function(index, route, source) return source and 1 or index end
WoW.now = 2900
TakeTaxiNode(2)
UnitOnTaxi = function() return true end
WoW.now = 2901
WoW.RunTickers()
f = FlightTimer:GetFlight()
check("recorded: counts down from it, no \"~\" (" .. tostring(bar.text:GetText()) .. ")",
  f and f.duration == 86 and f.estimated == false and bar.text:GetText() == "Flying to Auberdine · 1:26")
UnitOnTaxi = nil
WoW.now = 2990
WoW.RunTickers()
check("landed: the player's own time is learned (it wins next time)",
  Pathwise.db.flightTimes["Rut'theran Village, Teldrassil > Auberdine, Darkshore"] == 89)
C_TaxiMap, GetTaxiMapID = nil, nil
GetNumRoutes, TaxiGetNodeSlot = nil, nil
WoW.now = 3000
TakeTaxiNode(3)
WoW.now = 3010
WoW.RunTickers()
check("picked but never took off: nothing", FlightTimer:GetFlight() == nil and not bar:IsShown())
Pathwise.db.flightTimer = false
TakeTaxiNode(2)
UnitOnTaxi = function() return true end
WoW.RunTickers()
check("switched off on the Features page: no bar", not bar:IsShown())
UnitOnTaxi = nil
WoW.RunTickers()
Pathwise.db.flightTimer = true

-- Without known flight points: on foot as before
Pathwise.charDB.flightNodes = {}
Flights:ClearCache()
check("no known flight points: no flights", Travel.Route(1439, 0.37, 0.46, 1439, 0.50, 0.99) == nil)

-- Clean up
LibQuestieDB.Npc.Get, LibQuestieDB.Npc.GetAllIds = npcGet, nil
Pathwise:GetModule("QuestieData"):ResetTrainers()
NumTaxiNodes, TaxiNodeName, TaxiNodeGetType, TaxiNodePosition = nil, nil, nil, nil
At(1438, 0.58, 0.40)
