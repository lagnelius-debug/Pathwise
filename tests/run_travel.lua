-- Travel routes through portals and boats (Core/Travel.lua).
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Travel = Pathwise:GetModule("Travel")
local Waypoints = Pathwise:GetModule("Waypoints")
local arrow = _G.PathwiseArrow
local Arrow = Pathwise:GetModule("Arrow")

local function Near(a, b) return math.abs(a - b) < 1e-6 end
local function At(mapID, x, y) S.mapID, S.mapX, S.mapY = mapID, x, y end

---------------------------------------------------------------------------
section("Travel: regions")

check("Rut'theran Village is its own region", Travel.RegionOf(1438, 0.56, 0.92) == "RUTTHERAN")
check("the top of Teldrassil", Travel.RegionOf(1438, 0.597, 0.657) == "TELDRASSIL")
check("Darnassus belongs to the top", Travel.RegionOf(1457, 0.5, 0.5) == "TELDRASSIL")
check("other maps: their continent", Travel.RegionOf(1439, 0.5, 0.5) == "KALIMDOR")
check("unknown map: no region", Travel.RegionOf(99999, 0.5, 0.5) == nil)

---------------------------------------------------------------------------
section("Travel: routes")

-- Reported in game: at 59.7, 65.7 in Teldrassil, turning in to Nessa
-- Shadowsong (56, 92 - Rut'theran Village) the arrow pointed straight down.
local route = Travel.Route(1438, 0.597, 0.657, 1438, 0.56, 0.92)
check("to Rut'theran from the top: through the Darnassus portal", route and #route.legs == 1
  and route.legs[1].label == "TRAVEL_PORTAL_TO_RUTTHERAN")
local straight = Waypoints.Vector(1438, 0.597, 0.657, 1438, 0.56, 0.92)
check("the route is longer than the straight line", route.distance > straight + 500)
check("TravelDistance uses the route", Near(Waypoints.TravelDistance(1438, 0.597, 0.657, 1438, 0.56, 0.92), route.distance))
check("same region: no route, straight distance", Travel.Route(1438, 0.597, 0.657, 1438, 0.40, 0.40) == nil
  and Near(Waypoints.TravelDistance(1438, 0.597, 0.657, 1438, 0.40, 0.40), Waypoints.Vector(1438, 0.597, 0.657, 1438, 0.40, 0.40)))
route = Travel.Route(1438, 0.56, 0.92, 1457, 0.5, 0.5)
check("from Rut'theran up to Darnassus: the portal up", route and route.legs[1].label == "TRAVEL_PORTAL_TO_DARNASSUS")
route = Travel.Route(1439, 0.4, 0.4, 1438, 0.56, 0.92)
check("from Darkshore to Rut'theran: the boat", route and #route.legs == 1 and route.legs[1].label == "TRAVEL_BOAT_TO_RUTTHERAN")
route = Travel.Route(1439, 0.4, 0.4, 1438, 0.4, 0.4)
check("from Darkshore to the top of Teldrassil: boat, then portal", route and #route.legs == 2
  and route.legs[1].label == "TRAVEL_BOAT_TO_RUTTHERAN" and route.legs[2].label == "TRAVEL_PORTAL_TO_DARNASSUS")

---------------------------------------------------------------------------
section("Travel: the arrow")

S.facing = 0
At(1438, 0.597, 0.657)
Waypoints:SetManual({ mapID = 1438, x = 0.56, y = 0.92, label = "Turn in: Nessa Shadowsong" })
Arrow:Update()
check("arrow leads to the portal first, the destination underneath", arrow.label:GetText()
  == "Take the portal to Rut'theran Village (in Darnassus)\nthen: Turn in: Nessa Shadowsong")
local toPortal = Waypoints.Vector(1438, 0.597, 0.657, 1457, 0.30, 0.41)
check("distance is to the portal", arrow.distance:GetText() == Pathwise.FormatDistance(toPortal))
-- The portal is north-west of the player: the arrow turns left, not down.
local _, relative = Waypoints:GetDirection()
check("pointing towards the portal (north-west), not south", relative > 0 and relative < math.pi / 2)

At(1457, 0.30, 0.41)
WoW.ClearChat()
Arrow:Update()
check("at the portal: take it here, waypoint kept", arrow.distance:GetText() == "Take it here"
  and Waypoints:GetTarget() ~= nil and not WoW.ChatContains("Arrived"))

At(1438, 0.56, 0.895) -- arrived in Rut'theran
Arrow:Update()
check("after the portal: straight to the destination", arrow.label:GetText() == "Turn in: Nessa Shadowsong"
  and arrow.distance:GetText():find("m$") ~= nil)
Waypoints:ClearManual()

-- Ordering: a quest in Rut'theran counts as far from the top of the tree
local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local spots = { [1] = { mapID = 1438, x = 0.56, y = 0.92, label = "Rut" }, [2] = { mapID = 1438, x = 0.597, y = 0.35, label = "Top" } }
-- (Straight line: Up Here 920 yd, In Rut'theran 800 yd - only the route makes Rut'theran farther.)
local function Quest(id, title)
  return { questID = id, title = title, level = 10, zone = "Teldrassil", suggestedGroup = 0, objectives = { { text = "x: 0/1" } } }
end
local items = QuestAdvisor.Plan({ Quest(1, "In Rut'theran"), Quest(2, "Up Here") }, 10, 4,
  { zone = "Teldrassil", mapID = 1438, x = 0.597, y = 0.657 }, function(q) return spots[q.questID] end)
check("a quest straight below but behind a portal comes after one that's walkable",
  items[1].title == "Up Here" and items[2].title == "In Rut'theran", items[1].title)

---------------------------------------------------------------------------
section("Travel: finish the zone before leaving")

-- Reported in game: in Rut'theran Village with turn-ins still waiting up on
-- Teldrassil, the guide went on towards Darkshore (the boat and "Flight to
-- Auberdine" from Vesprystus).
local function Done(id, title) local q = Quest(id, title); q.complete = 1; q.objectives = {}; return q end
local places = {
  [10] = { mapID = 1438, x = 0.58, y = 0.93, label = "Vesprystus" },    -- 60 yd away
  [11] = { mapID = 1438, x = 0.90, y = 0.10, label = "Up the tree" },    -- through the portal, far
  [12] = { mapID = 1439, x = 0.33, y = 0.45, label = "Darkshore" },      -- by boat: closer than that
}
local pickups = { { questID = 13, title = "Flight to Auberdine", level = 10, giver = "Vesprystus", distance = 60,
  target = { mapID = 1438, x = 0.58, y = 0.93, label = "Pick up" }, finishMapID = 1439 } }
local here = { zone = "Teldrassil", mapID = 1438, x = 0.562, y = 0.922 }
local function Titles(list)
  local titles = {}
  for _, item in ipairs(list) do titles[#titles + 1] = item.title end
  return table.concat(titles, ", ")
end
local plan = QuestAdvisor.Plan({ Done(10, "The Bounty of Teldrassil"), Done(11, "Teldrassil Turn-in"), Quest(12, "Darkshore Quest") },
  10, 4, here, function(q) return places[q.questID] end, pickups)
check("nearby turn-in first, then the rest of Teldrassil, then Darkshore and the flight",
  Titles(plan):find("^The Bounty of Teldrassil, Teldrassil Turn%-in, ") ~= nil, Titles(plan))
local flight
for _, item in ipairs(plan) do if item.id == "pickup:13" then flight = item end end
check("a pickup turned in in another zone waits, and says why", flight.priority == Pathwise:GetModule("NextSteps").PRIORITY.QUEST_FAR
  and flight.leadsAway and flight.detail[2]:find("comes after the steps in this zone", 1, true))
plan = QuestAdvisor.Plan({ Quest(12, "Darkshore Quest") }, 10, 4, here, function(q) return places[q.questID] end, pickups)
check("with nothing left in the zone: on to Darkshore", Titles(plan) ~= "" and plan[1].title ~= nil)
check("a capital counts as its zone", Travel.ZoneGroup(1457) == 1438 and Travel.ZoneGroup(1439) == 1439)

At(1438, 0.58, 0.40)
