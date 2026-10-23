-- Optional QuestieDB integration: arrow targets from Questie's database.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local QuestieData = Pathwise:GetModule("QuestieData")
local NextSteps = Pathwise:GetModule("NextSteps")

local function Near(a, b) return math.abs(a - b) < 1e-6 end
local function Strip(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function Item(questID)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == "quest:" .. questID then return item end
  end
end

local function UpdateLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

---------------------------------------------------------------------------
section("QuestieDB: not installed")

check("not available without LibQuestieDB", not QuestieData:IsAvailable())

---------------------------------------------------------------------------
section("QuestieDB: targets")

-- Minimal LibQuestieDB with the documented Get(id, key) shape.
local db = {
  Quest = {
    [916] = { finishedBy = { { 1234 } }, objectives = { nil, nil, { { 5166, nil, 1 } } } },  -- Webwood Venom
    [917] = { finishedBy = { { 1235 } }, objectives = { nil, nil, {                         -- Iverron's Antidote
      { 10639, nil, 1 }, { 10641, nil, 2 }, { 10640, nil, 3 } } } },
    [999] = { finishedBy = {}, objectives = { { { 2031, nil, 1 } } } },                       -- kill quest
  },
  Npc = {
    [1986] = { name = "Webwood Spider", spawns = { [141] = { { 57, 30 }, { 58, 36 }, { 80, 80 } } } },
    [1994] = { name = "Githyiss the Vile", spawns = { [141] = { { 56, 26 } } } },
    [1234] = { name = "Gilshalan Windwalker", spawns = { [141] = { { 55, 50 } } } },
    [1235] = { name = "Iverron", spawns = { [141] = { { 51, 50 } } } },
    [2031] = { name = "Young Nightsaber", spawns = { [141] = { { 45, 40 } }, [9999] = { { 1, 1 } } } },
  },
  Item = {
    [5166] = { name = "Webwood Venom Sac", npcDrops = { 1986 } },
    [10639] = { name = "Hyacinth Mushroom", objectDrops = { 500 } },
    [10641] = { name = "Moonpetal Lily", objectDrops = { 501 } },
    [10640] = { name = "Webwood Ichor", npcDrops = { 1994 } },
  },
  Object = {
    [500] = { name = "Hyacinth Mushroom", spawns = { [141] = { { 50, 31 } } } },
    [501] = { name = "Moonpetal Lily", spawns = { [141] = { { 61, 32 } } } },
  },
}
local function Entity(rows)
  return { Get = function(id, key) local row = rows[id]; return row and row[key] end }
end
LibQuestieDB = {
  RequireContract = function(version) return version <= 4 end,
  Support = { Get = function(name)
    return { private = {
      areaIdToUiMapId = "return { [141] = 1438, [148] = 1439, [1] = 1426 }",
      areaIdToUiMapIdOverride = "return { [0] = 0 }",
    } }
  end },
  Quest = Entity(db.Quest), Npc = Entity(db.Npc), Item = Entity(db.Item), Object = Entity(db.Object),
}
check("available once LibQuestieDB is loaded", QuestieData:IsAvailable())

-- Standing in Aldrassil: zone Teldrassil, subzone Aldrassil, quests under "Shadowglen".
Pathwise.db.questLocations = {}
S.mapID, S.mapX, S.mapY, S.facing = 1438, 0.58, 0.40, 0
S.zone, S.subZone = "Teldrassil", "Aldrassil"
WoW.FireEvent("ZONE_CHANGED")
UpdateLog({
  { header = true, title = "Shadowglen" },
  { title = "Webwood Venom", level = 4, questID = 916, objectives = { { text = "Webwood Venom Sac: 0/10" } } },
  { title = "Iverron's Antidote", level = 4, questID = 917, objectives = {
    { text = "Hyacinth Mushroom: 0/7" }, { text = "Moonpetal Lily: 0/4" }, { text = "Webwood Ichor: 0/1" } } },
})
local venom = Item(916)
check("quest under a subzone header counts as here, with distance", Strip(venom.text) == "Do: [4] Webwood Venom - 120 yd")
check("item objective: nearest dropping NPC", venom.target and Near(venom.target.x, 0.58) and Near(venom.target.y, 0.36)
  and venom.target.label == "Webwood Venom Sac (Webwood Spider)")
local antidote = Item(917)
check("several objectives: nearest of all", antidote.target and Near(antidote.target.x, 0.61) and Near(antidote.target.y, 0.32))
check("item dropped by a same-named object: name not repeated", antidote.target.label == "Moonpetal Lily")
check("arrow follows a QuestieDB target right after accepting", Pathwise:GetModule("Waypoints"):GetTarget() ~= nil)

-- Reaching a spawn keeps the arrow there until progress happens.
local arrow = _G.PathwiseArrow
local Waypoints = Pathwise:GetModule("Waypoints")
local function Same(a, b) return a and b and Near(a.x, b.x) and Near(a.y, b.y) end
local first = Waypoints:GetTarget()
S.mapX, S.mapY = first.x, first.y
arrow._scripts.OnUpdate(arrow, 0.1)
WoW.FireEvent("QUEST_LOG_UPDATE") -- e.g. an unrelated update while standing there
WoW.RunTimers()
check("arriving alone doesn't move the arrow", Same(Waypoints:GetTarget(), first)
  and arrow.distance:GetText() == "You are here")

-- Looting there (progress) moves it on
local objective = WoW.questLog[3].objectives[2] -- Moonpetal Lily, the nearest target
objective.text = "Moonpetal Lily: 1/4"
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
local second = Waypoints:GetTarget()
check("progress moves the arrow to the next spawn", second and not Same(second, first))
check("looted spot remembered", Waypoints:IsVisited(first))
WoW.now = WoW.now + 301
check("visited spot forgotten after 5 minutes", not Waypoints:IsVisited(first))

-- Right-click skips an empty spawn
local current = Waypoints:GetTarget()
WoW.ClearChat()
arrow._scripts.OnMouseUp(arrow, "RightButton")
WoW.RunTimers()
check("right-click skips to the next spawn", not Same(Waypoints:GetTarget(), current)
  and WoW.ChatContains("Skipped that spot") and Pathwise.db.arrowAuto == true)

-- The Next button, /pw next and the key binding do the same
current = Waypoints:GetTarget()
arrow.next:Click()
WoW.RunTimers()
check("Next button skips", not Same(Waypoints:GetTarget(), current))
current = Waypoints:GetTarget()
WoW.Slash("next")
WoW.RunTimers()
check("/pw next skips", not Same(Waypoints:GetTarget(), current))
current = Waypoints:GetTarget()
PathwiseBinding_Next()
WoW.RunTimers()
check("key binding skips", not Same(Waypoints:GetTarget(), current))

WoW.now = WoW.now + 301
objective.text = "Moonpetal Lily: 0/4"
S.mapX, S.mapY = 0.58, 0.40
UpdateLog(WoW.questLog)

-- Finished objectives are skipped
WoW.questLog[3].objectives[2] = { text = "Moonpetal Lily: 4/4", finished = true }
UpdateLog(WoW.questLog)
antidote = Item(917)
check("finished objective skipped", antidote.target and not Near(antidote.target.x, 0.61))

-- Turn-in goes to the NPC that finishes the quest
WoW.questLog[2].complete = 1
WoW.questLog[2].objectives[1] = { text = "Webwood Venom Sac: 10/10", finished = true }
UpdateLog(WoW.questLog)
venom = Item(916)
check("turn-in at the finishing NPC", venom.target and Near(venom.target.x, 0.55) and Near(venom.target.y, 0.50)
  and venom.target.label == "Turn in: Webwood Venom (Gilshalan Windwalker)")
check("turn-in hint", venom.target.tasks[1] == "Turn in at Gilshalan Windwalker")

-- Talk-to quest (no objectives): arrow goes to the NPC that finishes it
db.Quest[3116] = { finishedBy = { { 1235 } }, objectives = {} }
UpdateLog({ { header = true, title = "Shadowglen" },
  { title = "Tenaron's Summons", level = 5, questID = 3116, objectives = {} } })
check("talk-to quest: arrow to the finishing NPC", Item(3116).target and Near(Item(3116).target.x, 0.51)
  and Item(3116).target.label == "Turn in: Tenaron's Summons (Iverron)")

-- Distance decides: south of Dolanaar, the Timberling quests just picked
-- up come before a far turn-in and a far quest.
-- Seeds drop from Timberlings; Sprouts are picked up from the ground.
db.Quest[918] = { finishedBy = { { 1240 } }, objectives = { nil, nil, { { 5168, nil, 1 } } } } -- Timberling Seeds
db.Quest[919] = { finishedBy = { { 1240 } }, objectives = { nil, nil, { { 5169, nil, 1 } } } } -- Timberling Sprouts
db.Item[5168] = { name = "Timberling Seed", npcDrops = { 2022 } }
db.Item[5169] = { name = "Timberling Sprout", objectDrops = { 600 } }
db.Object[600] = { name = "Timberling Sprout", spawns = { [141] = { { 59.5, 67.5 }, { 61, 69 } } } }
db.Quest[920] = { finishedBy = { { 1234 } }, objectives = {} }                       -- far turn-in
db.Quest[921] = { finishedBy = { { 1234 } }, objectives = { { { 1986, nil, 1 } } } } -- far quest
db.Npc[2022] = { name = "Timberling", spawns = { [141] = { { 57, 65 }, { 60, 68 } } } }
db.Npc[1240] = { name = "Denalan", spawns = { [141] = { { 60, 68 } } } }
S.mapX, S.mapY = 0.58, 0.66 -- south of Dolanaar
UpdateLog({
  { header = true, title = "Teldrassil" },
  { title = "Far Turn-in", level = 5, questID = 920, objectives = {} },
  { title = "Far Quest", level = 5, questID = 921, objectives = { { text = "Webwood Spider slain: 0/5" } } },
  { title = "Timberling Seeds", level = 5, questID = 918, objectives = { { text = "Timberling Seed: 0/8" } } },
  { title = "Timberling Sprouts", level = 6, questID = 919, objectives = { { text = "Timberling Sprout: 0/12" } } },
})
local order = {}
for _, item in ipairs(NextSteps:GetItems()) do
  if item.id:find("^quest:") then order[#order + 1] = Strip(item.text) end
end
check("nearby quests done together", order[1] == "Do together: [5] Timberling Seeds + [6] Timberling Sprouts - 42 yd")
check("far turn-in after nearby quests", order[2]:find("Turn in: [5] Far Turn-in", 1, true))
check("far quest last", order[3]:find("Far Quest", 1, true))
local together = Pathwise:GetModule("Waypoints"):GetTarget()
check("short arrow label: nearest target plus quest count", together.label == "Timberling Seed (Timberling) +1 quest")
check("target macro gets the mobs", together.names[1] == "Timberling")

-- The Next Steps window lists each quest with its tasks under the current step
Pathwise:GetModule("NextStepsFrame"):SetShown(true)
local lines = {}
for _, f in ipairs(WoW.frames) do
  if f.text and f._parent == _G.PathwiseNextSteps and f._shown then
    lines[#lines + 1] = Strip(f.text:GetText())
  end
end
local joined = table.concat(lines, "\n")
check("current step expanded", joined:find("Do together (2 quests) - 42 yd *", 1, true) ~= nil)
check("each quest with its tasks underneath", joined:find(
  "[5] Timberling Seeds\nKill Timberling for Timberling Seed\n[6] Timberling Sprouts\nCollect Timberling Sprout", 1, true) ~= nil)
check("other steps stay one line", joined:find("Turn in: [5] Far Turn-in - 488 yd *", 1, true) ~= nil
  and not joined:find("Turn in at Gilshalan", 1, true))
local arrow = _G.PathwiseArrow
check("no task text on the arrow", arrow.hint == nil)
check("single quest keeps its own line", order[3]:find("Do: [5] Far Quest", 1, true))

-- Walking to the far area re-sorts by itself
S.mapX, S.mapY = 0.56, 0.36
WoW.RunTickers()
order = {}
for _, item in ipairs(NextSteps:GetItems()) do
  if item.id:find("^quest:") then order[#order + 1] = Strip(item.text) end
end
check("after moving, the far quest is near", order[1]:find("Far Quest", 1, true) ~= nil)
S.mapX, S.mapY = 0.56, 0.361
WoW.RunTickers()
check("small moves don't re-plan", #WoW.timers == 0)

-- Kill quest; unknown area IDs are ignored
UpdateLog({ { header = true, title = "Teldrassil" },
  { title = "Kill quest", level = 4, questID = 999, objectives = { { text = "Young Nightsaber slain: 0/7" } } } })
local kill = Item(999)
check("kill objective: creature spawns", kill.target and Near(kill.target.x, 0.45) and kill.target.label == "Young Nightsaber")

-- Unknown quest: falls back to learned locations
Pathwise.db.questLocations[4242] = { pickup = { mapID = 1438, x = 0.1, y = 0.2 } }
UpdateLog({ { header = true, title = "Teldrassil" },
  { title = "Unknown", level = 4, questID = 4242, complete = 1, objectives = {} } })
check("not in QuestieDB: learned location used", Item(4242).target and Near(Item(4242).target.x, 0.1))

-- A failing QuestieDB call never breaks Pathwise
local get = LibQuestieDB.Quest.Get
LibQuestieDB.Quest.Get = function() error("broken") end
UpdateLog({ { header = true, title = "Teldrassil" },
  { title = "Webwood Venom", level = 4, questID = 916, objectives = { { text = "Webwood Venom Sac: 0/10" } } } })
-- (falls back to the spot learned when Webwood Venom progressed above)
check("errors are contained: learned location used instead", Item(916) ~= nil and Item(916).target ~= nil
  and Item(916).target.label == "Webwood Venom")
LibQuestieDB.Quest.Get = get

UpdateLog({})
