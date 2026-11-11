-- The area to quest in (Core/QuestAdvisor.lua): with nothing left in the
-- player's zone, the guide picks one area and leads there, instead of
-- single quests and turn-ins scattered over the map (reported in Duskwood
-- at level 26: a turn-in in Ironforge, a pickup in Westfall, two in
-- Ratchet, one in Darnassus).
local WoW, Pathwise, check, section = ...
local S = WoW.state

local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local P = Pathwise:GetModule("NextSteps").PRIORITY

---------------------------------------------------------------------------
section("Focus: choosing the area")

-- Zone groups: 1438 Teldrassil (with Darnassus 1457), 1439 Darkshore, 1437
-- Wetlands.
local focus, nextZone = QuestAdvisor.FocusZone({
  { zone = 1438, value = 1, distance = 100 },
  { zone = 1439, value = 9, distance = 500 },
}, 1438)
check("anything worth doing here: this zone first", focus == 1438 and nextZone == 1439)

focus = QuestAdvisor.FocusZone({ { zone = 1438, value = 0.3, distance = 100 }, { zone = 1439, value = 2, distance = 900 } }, 1438)
check("only a grey dead end here: on to the next area", focus == 1439)

focus, nextZone = QuestAdvisor.FocusZone({
  { zone = 1439, value = 1, distance = 600 },     -- one quest close by
  { zone = 1437, value = 1.5, distance = 3000 },  -- a cluster further away
  { zone = 1437, value = 1.5, distance = 3100 },
  { zone = 1437, value = 1, distance = 3200 },
  { zone = 1437, value = 1, distance = 3300 },
}, 1438)
check("nothing here: the area with the most to do for the way there", focus == 1437 and nextZone == 1439)

focus = QuestAdvisor.FocusZone({ { zone = 1439, value = 1, distance = 600 }, { zone = 1437, value = 2, distance = 9000 } }, 1438)
check("a little close by beats a little far away", focus == 1439)
check("nothing anywhere: no focus", QuestAdvisor.FocusZone({}, 1438) == nil)

---------------------------------------------------------------------------
section("Focus: what's worth something")

local function At(mapID) return { mapID = mapID, x = 0.5, y = 0.5 } end
local work = QuestAdvisor.ZoneWork({
  { title = "To do", level = S.level, objectives = { { text = "x: 0/1" } }, suggestedGroup = 0, questID = 11 },
  { title = "Ready", level = S.level, objectives = {}, suggestedGroup = 0, questID = 12, complete = 1 },
}, {
  { questID = 21, level = S.level, distance = 100, target = At(1439) },
  { questID = 22, level = S.level - 4, distance = 100, target = At(1439) },
  { questID = 23, level = S.level, distance = 100, target = At(1439), finishMapID = 1437 },
}, S.level, 6, nil, function(quest) return At(quest.questID == 11 and 1438 or 1437) end)
local values = {}
for _, entry in ipairs(work) do values[#values + 1] = entry.zone .. "=" .. entry.value end
check("to do 1.5, turn in 1, pickup 1, green 0.6, an errand elsewhere 0.2 (" .. table.concat(values, " ") .. ")",
  table.concat(values, " ") == "1438=1.5 1437=1 1439=1 1439=0.6 1439=0.2")

---------------------------------------------------------------------------
section("Focus: the pickups")

local pool = {
  { questID = 1, distance = 120, target = At(1437) },   -- close by (another zone, but right here)
  { questID = 2, distance = 900, target = At(1439) },
  { questID = 3, distance = 1000, target = At(1438) },
  { questID = 4, distance = 1100, target = At(1439) },
  { questID = 5, distance = 1200, target = At(1457) },  -- Darnassus: Teldrassil's group
  { questID = 6, distance = 1300, target = At(1439) },
}
local function Ids(list)
  local ids = {}
  for _, pickup in ipairs(list) do ids[#ids + 1] = pickup.questID end
  return table.concat(ids, ",")
end
check("close ones and the focus area's, not scattered ones", Ids(QuestAdvisor.FocusPickups(pool, 1438, nil, 4)) == "1,3,5")
check("room left: the next area's", Ids(QuestAdvisor.FocusPickups(pool, 1438, 1439, 4)) == "1,2,3,5")
check("at most the limit", #QuestAdvisor.FocusPickups(pool, 1439, 1438, 3) == 3)

---------------------------------------------------------------------------
section("Focus: the route")

local function Step(id, mapID, x, kind)
  return { id = id, priority = P.QUEST_FAR, kind = kind or "do", target = { mapID = mapID, x = x, y = 0.5 } }
end
local items = {
  Step("far", 1437, 0.5, "turnIn"),
  Step("focus2", 1439, 0.9),
  Step("focus1", 1439, 0.2),
  Step("here", 1438, 0.6),
}
QuestAdvisor.RouteFar(items, { mapID = 1438, x = 0.5, y = 0.5 }, false, 1439)
local order = {}
for _, item in ipairs(items) do order[#order + 1] = item.id end
check("this zone, then the focus area as a route, then the rest (" .. table.concat(order, ",") .. ")",
  table.concat(order, ",") == "here,focus1,focus2,far")

---------------------------------------------------------------------------
section("Focus: quests under way first")

-- Reported: a list of quests to pick up "just because they're close by"
-- while the log is full of quests still to do.
local function Doing(id) return { title = "Doing " .. id, level = S.level, questID = 7000 + id, suggestedGroup = 0,
  objectives = { { text = "x: 0/1" } } } end
local function Locate(quest) return quest.questID and quest.questID >= 7000 and At(1439) or nil end
local log = { Doing(1), Doing(2), Doing(3) }
check("quests under way: those with something to do at a known place",
  QuestAdvisor.Ongoing(log, S.level, 6, Locate) == 3)
log[#log + 1] = { title = "Done", level = S.level, questID = 7010, complete = 1, objectives = {}, suggestedGroup = 0 }
log[#log + 1] = { title = "Red", level = S.level + 6, questID = 7011, objectives = { { text = "x: 0/1" } }, suggestedGroup = 0 }
check("not ready, red or grey ones", QuestAdvisor.Ongoing(log, S.level, 6, Locate) == 3)

---------------------------------------------------------------------------
section("Focus: starting areas and quests that lead away")

-- Reported: Supplies to Tannok (Coldridge Valley to Kharanos, both Dun
-- Morogh) suggested while Coldridge Valley's quests were still open.
-- Teldrassil (1438) with Shadowglen as its starting area.
check("in Shadowglen", QuestAdvisor.StartAreaAt(1438, 0.58, 0.40) ~= nil
  and QuestAdvisor.StartAreaAt(1438, 0.56, 0.60) == nil and QuestAdvisor.StartAreaAt(1439, 0.58, 0.40) == nil)
local function P(id, x, y, distance, finish)
  return { questID = id, distance = distance, target = { mapID = 1438, x = x, y = y },
    finishMapID = finish and 1438 or nil, finishPoint = finish and { mapID = 1438, x = finish[1], y = finish[2] } }
end
local breadcrumb = P(1, 0.60, 0.45, 150, { 0.56, 0.75 })   -- turned in down in Dolanaar
check("a quest turned in far away (same zone) leads away", QuestAdvisor.PickupLeadsAway(breadcrumb)
  and not QuestAdvisor.PickupLeadsAway(P(9, 0.60, 0.45, 150, { 0.61, 0.46 })))
local area = QuestAdvisor.StartAreaAt(1438, 0.58, 0.40)
local pool = {
  P(1, 0.60, 0.45, 150, { 0.56, 0.75 }),  -- the breadcrumb
  P(2, 0.57, 0.35, 400, { 0.57, 0.35 }),  -- in Shadowglen
  P(3, 0.56, 0.60, 900, { 0.56, 0.60 }),  -- Dolanaar
}
check("in a starting area: its own quests, not the town's, and the breadcrumb waits",
  Ids(QuestAdvisor.FocusPickups(pool, 1438, 1439, 4, false, area)) == "2")
pool = { P(1, 0.60, 0.45, 150, { 0.56, 0.75 }), P(3, 0.56, 0.60, 900, { 0.56, 0.60 }) }
check("nothing else to pick up, quests still under way: it still waits",
  Ids(QuestAdvisor.FocusPickups(pool, 1438, 1439, 4, true, area)) == "")
check("the starting area is done: the breadcrumb leads on",
  Ids(QuestAdvisor.FocusPickups(pool, 1438, 1439, 4, false, area)) == "1")
check("outside a starting area: the town's quests as before",
  Ids(QuestAdvisor.FocusPickups({ P(3, 0.56, 0.60, 900, { 0.56, 0.60 }) }, 1438, nil, 4, false, nil)) == "3")
