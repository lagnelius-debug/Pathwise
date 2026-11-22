-- After dying (Core/Corpse.lua): while a ghost, the arrow leads to the body.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Waypoints = Pathwise:GetModule("Waypoints")
local Corpse = Pathwise:GetModule("Corpse")
local arrow = _G.PathwiseArrow

local ghost, dead, body = false, false, nil
UnitIsGhost = function() return ghost end
UnitIsDeadOrGhost = function() return dead or ghost end
C_DeathInfo = { GetCorpseMapPosition = function(mapID)
  if body and body.mapID == mapID then return CreateVector2D(body.x, body.y) end
end }
local savedMap, savedX, savedY = S.mapID, S.mapX, S.mapY
local shown = Pathwise.db.nextSteps.shown

---------------------------------------------------------------------------
section("Corpse: the arrow to the body")

S.mapID, S.mapX, S.mapY = 1438, 0.50, 0.50
dead = true
WoW.FireEvent("PLAYER_DEAD")
check("dead, not released yet: no arrow to the body (it's right here)", select(2, Waypoints:GetTarget()) ~= "corpse")
check("where the player died is kept", Pathwise.charDB.deathSpot and Pathwise.charDB.deathSpot.mapID == 1438)
-- Released: a ghost at the graveyard, the body where the game says.
dead, ghost = false, true
body = { mapID = 1438, x = 0.55, y = 0.52 }
S.mapX, S.mapY = 0.30, 0.70
WoW.FireEvent("PLAYER_ALIVE")
local target, kind = Waypoints:GetTarget()
check("a ghost: the arrow on the body, before everything", kind == "corpse" and target.label == "Your body"
  and math.abs(target.x - 0.55) < 1e-9 and math.abs(target.y - 0.52) < 1e-9)
Pathwise.db.nextSteps.shown = false
Pathwise:FireCallback("WAYPOINT_CHANGED")
check("shown even with the To-do window closed", arrow:IsShown())
Pathwise.db.nextSteps.shown = shown
-- Far away, with flight points known: still straight, no flight (no flight
-- master serves a ghost).
local Flights = Pathwise:GetModule("Flights")
local nodes = Pathwise.charDB.flightNodes
Pathwise.charDB.flightNodes = {
  ["A, Teldrassil"] = { mapID = 1438, x = 0.30, y = 0.70, continent = 1 },
  ["B, Teldrassil"] = { mapID = 1438, x = 0.55, y = 0.52, continent = 1 },
}
Flights:ClearCache()
local _, _, via = Waypoints:GetDirection()
check("the way to the body: straight, no flight", via == nil)
Pathwise.charDB.flightNodes = nodes
Flights:ClearCache()
-- The game doesn't say: where the player died.
body = nil
Corpse:Refresh()
target = Waypoints:GetTarget()
check("the game doesn't say where: where the player died", target and target.corpse and target.x == 0.50)
-- Next: to the spirit healer instead.
WoW.ClearChat()
Waypoints:Next()
check("Next: not to the body any more", select(2, Waypoints:GetTarget()) ~= "corpse"
  and WoW.ChatContains("no longer leads to your body"))
WoW.FireEvent("ZONE_CHANGED_NEW_AREA")
check("... not even after changing zones", select(2, Waypoints:GetTarget()) ~= "corpse")
-- Resurrected: back to normal, and the next death leads to the body again.
ghost = false
WoW.FireEvent("PLAYER_UNGHOST")
check("resurrected: the death spot forgotten", Pathwise.charDB.deathSpot == nil)
dead = true
WoW.FireEvent("PLAYER_DEAD")
dead, ghost = false, true
WoW.FireEvent("PLAYER_ALIVE")
check("the next death: to the body again", select(2, Waypoints:GetTarget()) == "corpse")
ghost = false
WoW.FireEvent("PLAYER_ALIVE")
check("resurrected by a spell (PLAYER_ALIVE, not a ghost): no arrow to the body",
  select(2, Waypoints:GetTarget()) ~= "corpse")
-- Switched off.
Pathwise.db.corpseArrow = false
dead = true
WoW.FireEvent("PLAYER_DEAD")
dead, ghost = false, true
WoW.FireEvent("PLAYER_ALIVE")
check("switched off on the Features page: no arrow to the body", select(2, Waypoints:GetTarget()) ~= "corpse")
Pathwise.db.corpseArrow = true

-- Died inside a dungeon (no position there): its entrance, without errors.
local errors = #WoW.errors
Pathwise.charDB.deathSpot = { dungeon = 1581 }
local ok = pcall(Corpse.Target, Corpse)
check("died inside a dungeon: no error", ok and #WoW.errors == errors)

-- Clean up
ghost, dead = false, false
Corpse:Refresh()
UnitIsGhost, UnitIsDeadOrGhost, C_DeathInfo = nil, nil, nil
S.mapID, S.mapX, S.mapY = savedMap, savedX, savedY
