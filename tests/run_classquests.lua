-- Class quest reminders for the other classes (Classes/ClassQuests.lua).
local WoW, Pathwise, check, section = ...
local S = WoW.state

local NextSteps = Pathwise:GetModule("NextSteps")
local ClassQuests = Pathwise:GetModule("ClassQuests")
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
local P = NextSteps.PRIORITY

local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end
local function ClassItems()
  local ids = {}
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id:find("^classquest:") then ids[#ids + 1] = item.id:sub(12) end
  end
  table.sort(ids)
  return table.concat(ids, ",")
end
local function Become(class, race, level)
  S.class, S.race = class, race
  snapshot.level = nil
  S.level = level
  WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
  WoW.RunTimers()
end
local function Refresh()
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

local saved = { class = S.class, race = S.race, level = S.level, faction = S.faction, skills = S.skills }
local savedCompleted, savedQuestLog = C_QuestLog, WoW.questLog
local completed = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return completed[id] == true end }
WoW.questLog = {}
Pathwise.charDB.classQuestsReminded = {}

-- QuestieDB: Elanaria in Darnassus starts the Night Elf warrior quest; the
-- other Alliance starts are on another map.
local q, n = LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get
LibQuestieDB.Quest.Get = function(id, key)
  if key == "startedBy" and id == 1684 then return { { 4088 } } end
  if key == "startedBy" and (id == 1638 or id == 1679) then return { { 4089 } } end
  return q(id, key)
end
LibQuestieDB.Npc.Get = function(id, key)
  if id == 4088 then return ({ name = "Elanaria", spawns = { [141] = { { 57, 60 } } } })[key] end
  if id == 4089 then return ({ name = "Far Away", spawns = { [1] = { { 50, 50 } } } })[key] end
  return n(id, key)
end
S.mapID, S.mapX, S.mapY = 1438, 0.56, 0.60

---------------------------------------------------------------------------
section("Class quests: warrior")

WoW.ClearChat()
Become({ "Warrior", "WARRIOR", 1 }, { "Night Elf", "NightElf", 4 }, 9)
check("level 9: no class quest yet", ClassItems() == "")
Become({ "Warrior", "WARRIOR", 1 }, { "Night Elf", "NightElf", 4 }, 10)
local item = Item("classquest:DEFENSIVE_STANCE")
check("level 10: Defensive Stance quest, a nearby step with its distance (" .. tostring(item and item.text) .. ")",
  item and item.text:find("^Learn Defensive Stance: warrior quest %- %d+ m$") ~= nil
  and item.priority == P.QUEST_NEAR and item.kind == "pickup" and item.detail[1]:find("From level 10", 1, true))
check("arrow on the nearest giver for your race", item.target and item.target.label == "Class quest (Elanaria)")
check("said once in chat", WoW.ChatContains("Class quest: Learn Defensive Stance: warrior quest."))
check("quest pickups leave the start out", ClassQuests:Covers(1684) and not ClassQuests:Covers(1505))
WoW.ClearChat()
Refresh()
check("not said again", not WoW.ChatContains("Class quest"))

WoW.questLog = { { title = "Vorlus Vilehoof", level = 10, questID = 1683, objectives = {} } }
Refresh()
check("a quest of the chain in the log: the quest is the step", Item("classquest:DEFENSIVE_STANCE") == nil)
WoW.questLog = {}
WoW.knownSpells[71] = true
Refresh()
check("Defensive Stance known: done", ClassItems() == "")
Become({ "Warrior", "WARRIOR", 1 }, { "Night Elf", "NightElf", 4 }, 30)
check("level 30: Berserker Stance", ClassItems() == "BERSERKER_STANCE")
completed[1719] = true
Refresh()
check("last quest completed: done", ClassItems() == "")
WoW.knownSpells[71], completed[1719] = nil, nil

---------------------------------------------------------------------------
section("Class quests: race, ranks, items and skills")

WoW.spellNames[2652] = "Touch of Weakness"
Become({ "Priest", "PRIEST", 5 }, { "Undead", "Scourge", 5 }, 10)
item = Item("classquest:TOUCH_OF_WEAKNESS")
check("Undead priest: Touch of Weakness only (" .. ClassItems() .. ")", ClassItems() == "TOUCH_OF_WEAKNESS"
  and item.text == "Learn Touch of Weakness: priest quest for your race" and item.priority == P.CLASS_QUEST_OPTIONAL)
WoW.knownSpells[19261] = true -- rank 2 (the client may not report rank 1 any more)
Refresh()
check("a higher rank known: done", ClassItems() == "")
WoW.knownSpells[19261] = nil
Become({ "Priest", "PRIEST", 5 }, { "Troll", "Troll", 8 }, 10)
check("Troll priest: Hex of Weakness, not Touch of Weakness (" .. ClassItems() .. ")", ClassItems() == "HEX_OF_WEAKNESS")

Become({ "Shaman", "SHAMAN", 7 }, { "Orc", "Orc", 2 }, 30)
check("level 30 shaman without totems: at most 3, by level (" .. ClassItems() .. ")",
  ClassItems() == "EARTH_TOTEM,FIRE_TOTEM,WATER_TOTEM")
WoW.knownSpells[8071], WoW.knownSpells[3599] = true, true
Refresh()
check("then the Air Totem", ClassItems() == "AIR_TOTEM,WATER_TOTEM")
WoW.bagCounts[5178] = 1
Refresh()
check("Air Totem in the bags: done", ClassItems() == "WATER_TOTEM")
WoW.bagCounts[5178], WoW.knownSpells[8071], WoW.knownSpells[3599] = nil, nil, nil

Become({ "Rogue", "ROGUE", 4 }, { "Human", "Human", 1 }, 20)
check("level 20 rogue: Poisons", ClassItems() == "POISONS")
S.skills = { { "Secondary Skills", true, true }, { "Poisons", false, false, 1, 300 } }
WoW.FireEvent("SKILL_LINES_CHANGED")
WoW.RunTimers()
check("Poisons skill there: done", ClassItems() == "")
S.skills = saved.skills

Become({ "Paladin", "PALADIN", 2 }, { "Human", "Human", 1 }, 40)
check("no giver known: own steps after the quests nearby, the important ones first (" .. ClassItems() .. ")",
  Item("classquest:WARHORSE").priority == P.QUEST_FAR
  and Item("classquest:TOME_OF_VALOR").priority == P.CLASS_QUEST_OPTIONAL)

-- Reported in game: a level 1 warlock in Coldridge Valley got "Get your
-- Imp" with the arrow on the trainer 173 m away, while a quest giver stood
-- 23 m away. Class quests are ordered by distance like other pickups.
local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local here = { zone = "Dun Morogh", mapID = 1426, x = 0.30, y = 0.70 }
local plan = QuestAdvisor.Plan({}, 1, 4, here, function() end, {
  { questID = 179, title = "Dwarven Outfitters", level = 1, giver = "Sten Stoutarm", distance = 23,
    target = { mapID = 1426, x = 0.30, y = 0.71, label = "Pick up" } },
  { classQuest = true, key = "IMP", text = "Get your Imp: warlock quest", detail = "From level 1", important = true,
    distance = 173, target = { mapID = 1426, x = 0.32, y = 0.70, label = "Class quest (Alamar Grimm)", names = { "Alamar Grimm" } } },
})
check("the quest 23 m away first, then the Imp at 173 m (" .. (plan[1] and plan[1].id or "?") .. ")",
  plan[1].id == "pickup:179" and plan[2].id == "classquest:IMP" and plan[2].priority == P.QUEST_NEAR
  and plan[2].subLines[1].text:find("Alamar Grimm", 1, true))
plan = QuestAdvisor.Plan({}, 10, 4, here, function() end, {
  { classQuest = true, key = "VOIDWALKER", text = "Get your Voidwalker: warlock quest", detail = "", important = true,
    distance = 2500, target = { mapID = 1455, x = 0.5, y = 0.5, label = "Class quest", names = { "Someone" } } },
})
check("far away: a far step on the route (never held back as 'leads away')", plan[1].priority == P.QUEST_FAR
  and plan[1].urgent == true)

Pathwise:GetModule("FeaturesPanel"):SetFeature((function()
  for i, feature in ipairs(Pathwise:GetModule("FeaturesPanel").FEATURES) do
    if feature[1] == "FEATURE_CLASS_QUESTS" then return i end
  end
end)(), false)
check("switched off on the Features page: no reminders", ClassItems() == "")
Pathwise.db.classQuests = true

Become({ "Hunter", "HUNTER", 3 }, { "Night Elf", "NightElf", 4 }, 40)
check("hunters: none here (taming is in the hunter module)", ClassItems() == "")

-- Clean up
LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get = q, n
C_QuestLog, WoW.questLog = savedCompleted, savedQuestLog
S.faction = saved.faction
Become(saved.class, saved.race, saved.level)
