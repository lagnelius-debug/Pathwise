-- "On the way" hints (QuestAdvisor.AddOnTheWay): another quest's mobs near
-- the straight line to a step's target.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local P = Pathwise:GetModule("NextSteps").PRIORITY

-- Teldrassil is 3000 x 3000 yd: 0.01 = 30 yd. The player at the middle,
-- the turn-in 600 yd north.
local here = { mapID = 1438, x = 0.5, y = 0.5 }
local function Spawn(x, y, task) return { mapID = 1438, x = x, y = y, task = task } end
local function Items(threatSpawns)
  local turnIn = { id = "quest:1", priority = P.QUEST_FAR, kind = "turnIn", title = "Mail Delivery", distance = 600,
    target = { mapID = 1438, x = 0.5, y = 0.3, label = "Turn in: Mail Delivery" },
    subLines = { { text = "Turn in at Talin", level = 1, task = true } } }
  local threat = { id = "quest:2", priority = P.QUEST_FAR, kind = "do", title = "A New Threat", distance = 900,
    target = { mapID = 1438, x = 0.8, y = 0.5, spawnPoints = threatSpawns } }
  return { turnIn, threat }, turnIn, threat
end

---------------------------------------------------------------------------
section("On the way")

-- The "On the way" lines added under a step.
local function Hints(item)
  local hints = {}
  for _, line in ipairs(item.subLines or {}) do
    if line.onTheWay then hints[#hints + 1] = line.text end
  end
  return table.concat(hints, "\n")
end

local items, turnIn, threat = Items({ Spawn(0.51, 0.40, "Kill Rockjaw Trogg"), Spawn(0.49, 0.35, "Kill Rockjaw Trogg"),
  Spawn(0.505, 0.45, "Kill Burly Rockjaw Trogg"), Spawn(0.8, 0.5, "Kill Rockjaw Trogg") })
QuestAdvisor.AddOnTheWay(items, here)
check("spawns near the line: named once each, with the quest (" .. Hints(turnIn) .. ")",
  Hints(turnIn) == "On the way: Kill Rockjaw Trogg, Kill Burly Rockjaw Trogg (A New Threat)")
check("under the step's own lines", turnIn.subLines[1].task and turnIn.subLines[2].onTheWay and turnIn.subLines[2].level == 1)
check("not for the quest's own step", Hints(threat) == "")

items, turnIn = Items({ Spawn(0.6, 0.4, "Kill Rockjaw Trogg"), Spawn(0.5, 0.2, "Kill Rockjaw Trogg") })
QuestAdvisor.AddOnTheWay(items, here)
check("300 yd to the side, or 300 yd past the target: not on the way", #turnIn.subLines == 1)

items, turnIn = Items({ Spawn(0.5, 0.4, "Kill Rockjaw Trogg") })
turnIn.distance = 1500
QuestAdvisor.AddOnTheWay(items, here)
check("the route goes around something (much longer than the line): no hint", Hints(turnIn) == "")

items, turnIn, threat = Items({ Spawn(0.5, 0.4, "Kill Rockjaw Trogg") })
threat.priority = P.QUEST_LATER
QuestAdvisor.AddOnTheWay(items, here)
check("a quest for later (too hard): no hint", Hints(turnIn) == "")

items, turnIn = Items({ Spawn(0.5, 0.49, "Kill Rockjaw Trogg") })
turnIn.target.y, turnIn.distance = 0.49, 30
QuestAdvisor.AddOnTheWay(items, here)
check("a target right here: no hint", Hints(turnIn) == "")

-- A "do together" step brings its quests' spawns along, each by name.
items, turnIn = Items({ Spawn(0.5, 0.4, "Kill Rockjaw Trogg") })
local together = { id = "quest:2+quest:3", priority = P.QUEST_FAR, kind = "do", target = { mapID = 1438, x = 0.8, y = 0.5 },
  members = { items[2], { title = "Beer Basted Boar Ribs", target = { spawnPoints = { Spawn(0.5, 0.35, "Kill Crag Boar") } } } } }
items[2] = together
QuestAdvisor.AddOnTheWay(items, here)
check("a \"do together\" step: each quest of it", Hints(turnIn)
  == "On the way: Kill Rockjaw Trogg (A New Threat)\nOn the way: Kill Crag Boar (Beer Basted Boar Ribs)")

---------------------------------------------------------------------------
section("On the way: To-do list only")

local Waypoints = Pathwise:GetModule("Waypoints")
local arrow = _G.PathwiseArrow
S.mapID, S.mapX, S.mapY = 1438, 0.5, 0.5
Waypoints:SetManual(turnIn.target)
arrow._scripts.OnUpdate(arrow, 0.1)
check("the arrow keeps its short label (" .. tostring(arrow.label:GetText()) .. ")",
  arrow.label:GetText() == "Turn in: Mail Delivery")
Waypoints:ClearManual()
