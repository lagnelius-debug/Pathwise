-- Navigation arrow, waypoints and learned quest locations.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Waypoints = Pathwise:GetModule("Waypoints")
local arrow = _G.PathwiseArrow

local function Tick()
  arrow._scripts.OnUpdate(arrow, 0.1)
end

local function Near(a, b)
  return math.abs(a - b) < 1e-6
end

---------------------------------------------------------------------------
section("Arrow: math")

-- Teldrassil test map is 3000 x 3000 yards.
local distance, bearing = Waypoints.Vector(1438, 0.5, 0.5, 1438, 0.5, 0.4)
check("north: 300 yd, bearing 0", Near(distance, 300) and Near(bearing, 0))
distance, bearing = Waypoints.Vector(1438, 0.5, 0.5, 1438, 0.4, 0.5)
check("west: bearing +90 degrees (counterclockwise)", Near(distance, 300) and Near(bearing, math.pi / 2))
distance, bearing = Waypoints.Vector(1438, 0.5, 0.5, 1438, 0.6, 0.5)
check("east: bearing -90 degrees", Near(bearing, -math.pi / 2))
-- Teldrassil (0.5, 1.0) is at the same world spot as Darkshore (0.0, 0.0).
distance = Waypoints.Vector(1438, 0.5, 1.0, 1439, 0.0, 0.0)
check("across maps on the same continent", distance ~= nil and Near(distance, 1500))
check("different continents: nil", Waypoints.Vector(1438, 0.5, 0.5, 1429, 0.5, 0.5) == nil)

---------------------------------------------------------------------------
section("Arrow: manual waypoint")

S.mapID, S.mapX, S.mapY, S.facing = 1438, 0.5, 0.5, 0
Pathwise.db.arrowAuto = false -- isolate manual behaviour first
WoW.ClearChat()
WoW.Slash("way 50 40 Test spot")
check("waypoint set", WoW.ChatContains("Arrow pointing to Test spot."))
Tick()
check("arrow shown with label and distance", arrow:IsShown() and arrow.label:GetText() == "Test spot"
  and arrow.distance:GetText() == "300 yd")
local function Frame() return table.concat(arrow.arrow._texcoord or {}, ",") end
check("3D arrow texture, 64x64", arrow.arrow._texture:find("Media\\Arrow\\arrow3d$") ~= nil and arrow.arrow._width == 64)
check("facing the target: straight-ahead frame, green", Frame() == "0,0.125,0,0.125"
  and arrow.arrow._color[1] == 0.2 and arrow.arrow._color[2] == 1)

S.facing = math.pi / 2 -- facing west; target is north, so to the right
Tick()
-- 270 degrees counterclockwise = frame 48: row 6, column 0
check("target to the right: frame turned 270 degrees, yellow", Frame() == "0,0.125,0.75,0.875"
  and arrow.arrow._color[1] == 1 and Near(arrow.arrow._color[2], 0.85))

S.facing = math.pi / 4 -- target 45 degrees to the right: frame 56
Tick()
check("45 degrees right: frame 56, between green and yellow", Frame() == "0,0.125,0.875,1"
  and arrow.arrow._color[1] > 0.2 and arrow.arrow._color[1] < 1)

S.facing = math.pi -- target behind: frame 32, red
Tick()
check("target behind: frame 32, red", Frame() == "0,0.125,0.5,0.625" and arrow.arrow._color[1] == 1
  and Near(arrow.arrow._color[2], 0.25))
S.facing = math.pi / 2
Tick()

S.mapY = 0.401
WoW.ClearChat()
Tick()
check("arrived", arrow.distance:GetText() == "You are here" and WoW.ChatContains("Arrived at Test spot."))
Tick()
check("arrow hides after arriving", not arrow:IsShown())

WoW.Slash("way 101 5")
check("bad coordinates: usage", WoW.ChatContains("Usage: /pw way"))
WoW.Slash("way 20,30")
check("comma-separated coordinates work", Waypoints:GetTarget() and Near(Waypoints:GetTarget().x, 0.2))
WoW.Slash("way clear")
check("way clear", Waypoints:GetTarget() == nil)

S.mapID = 1429
WoW.Slash("way 50 50")
S.mapID = 1438
Tick()
check("other continent: can't point", arrow.distance:GetText() == "Can't point from here" and not arrow.arrow:IsShown())
WoW.Slash("way clear")

---------------------------------------------------------------------------
section("Arrow: learned quest locations")

Pathwise.db.arrowAuto = true
Pathwise.db.questLocations = {}
S.mapX, S.mapY, S.facing = 0.58, 0.40, 0
WoW.questLog = {
  { header = true, title = "Teldrassil" },
  { title = "The Balance of Nature", level = 7, questID = 456, objectives = { { text = "Nightsaber slain: 0/7" } } },
}
WoW.FireEvent("QUEST_ACCEPTED", 2, 456)
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
local entry = Pathwise.db.questLocations[456]
check("pickup recorded at the quest giver", entry and entry.pickup and Near(entry.pickup.x, 0.58) and Near(entry.pickup.y, 0.40))
check("no 'do' target before any progress", Waypoints:GetTarget() == nil)

-- Kill two nightsabers at two spots
S.mapX, S.mapY = 0.60, 0.50
WoW.questLog[2].objectives[1].text = "Nightsaber slain: 1/7"
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
S.mapX, S.mapY = 0.64, 0.54
WoW.questLog[2].objectives[1].text = "Nightsaber slain: 2/7"
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("progress spots recorded", #entry.progress == 2)
local target = Waypoints:GetTarget()
check("arrow auto-follows the quest's progress area", target and Near(target.x, 0.62) and Near(target.y, 0.52)
  and target.label == "The Balance of Nature")

-- Complete it: arrow goes to the quest giver
WoW.questLog[2].objectives[1] = { text = "Nightsaber slain: 7/7", finished = true }
WoW.questLog[2].complete = 1
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
target = Waypoints:GetTarget()
check("turn-in points to where it was picked up", target and Near(target.x, 0.58)
  and target.label == "Turn in: The Balance of Nature (where you got it)")
Tick()
check("arrow shown for auto target", arrow:IsShown())

S.mapX, S.mapY = 0.59, 0.41
WoW.FireEvent("QUEST_TURNED_IN", 456, 450, 0)
check("turn-in spot recorded", entry.turnIn and Near(entry.turnIn.x, 0.59))
table.remove(WoW.questLog, 2)
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("arrow clears when nothing has a location", Waypoints:GetTarget() == nil)

-- Same quest on another character: known turn-in spot is used
WoW.questLog = {
  { header = true, title = "Teldrassil" },
  { title = "The Balance of Nature", level = 7, questID = 456, complete = 1, objectives = {} },
}
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("recorded turn-in spot preferred", Waypoints:GetTarget().label == "Turn in: The Balance of Nature")

---------------------------------------------------------------------------
section("Arrow: controls")

WoW.Slash("arrow")
check("/pw arrow turns auto-follow off", Pathwise.db.arrowAuto == false and Waypoints:GetTarget() == nil)
WoW.Slash("arrow")
check("/pw arrow turns it back on", Pathwise.db.arrowAuto == true and Waypoints:GetTarget() ~= nil)

-- Next on a step that isn't a spawn: skip the step, point at the next one
WoW.questLog[3] = { title = "Second quest", level = 7, questID = 457, complete = 1, objectives = {} }
Pathwise.db.questLocations[457] = { pickup = { mapID = 1438, x = 0.2, y = 0.2 } }
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
local before = Waypoints:GetTarget()
WoW.ClearChat()
WoW.Slash("next")
local after = Waypoints:GetTarget()
check("next skips a whole step", before and after and before.label ~= after.label
  and WoW.ChatContains("Skipped that step for 5 minutes"))
WoW.now = WoW.now + 301
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("skipped step returns after 5 minutes", Waypoints:GetTarget().label == before.label)
table.remove(WoW.questLog, 3)
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()

-- Clicking a Next Steps line sets a manual waypoint (standing away from it,
-- otherwise it would count as arrived right away)
S.mapX, S.mapY = 0.3, 0.3
local row
for _, f in ipairs(WoW.frames) do
  if f.item and f.item.target and f._shown then row = f end
end
check("next steps row has a location marker", row and row.text:GetText():find("*", 1, true))
row._scripts.OnMouseUp(row, "LeftButton")
local _, kind = Waypoints:GetTarget()
check("clicking a step sets a manual waypoint", kind == "manual")
arrow._scripts.OnMouseUp(arrow, "RightButton")
check("right-click clears a manual waypoint", select(2, Waypoints:GetTarget()) == "auto")

-- No position (instance): arrow can't point
S.mapX = nil
Tick()
check("no position: can't point", arrow.distance:GetText() == "Can't point from here")
S.mapX, S.mapY = 0.5, 0.5
WoW.questLog = {}
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
