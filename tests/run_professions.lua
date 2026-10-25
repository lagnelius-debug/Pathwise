-- Profession advisor: recommendations, learn/train/tool steps, trainers
-- from QuestieDB, Skinning tooltip line.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Professions = Pathwise:GetModule("Professions")
local NextSteps = Pathwise:GetModule("NextSteps")
local P = NextSteps.PRIORITY

local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end

local function SetSkills(list)
  local skills = { { "Professions", true, true } }
  for _, entry in ipairs(list) do
    skills[#skills + 1] = { entry[1], false, false, entry[2], entry[3] }
  end
  skills[#skills + 1] = { "Weapon Skills", true, true }
  skills[#skills + 1] = { "Bows", false, false, 50, 60 }
  S.skills = skills
  WoW.FireEvent("SKILL_LINES_CHANGED")
  WoW.RunTimers()
end

---------------------------------------------------------------------------
section("Professions: helpers")

check("skinning: level 5 beast needs 1", Professions.SkinningRequired(5) == 1)
check("skinning: level 15 needs 50, 20 needs 100, 30 needs 150", Professions.SkinningRequired(15) == 50
  and Professions.SkinningRequired(20) == 100 and Professions.SkinningRequired(30) == 150)
check("skinning: ?? level unknown", Professions.SkinningRequired(-1) == nil)
check("next rank after 75 is Journeyman (level 10, skill 50)", Professions.NextRank(75).name == "Journeyman"
  and Professions.NextRank(75).level == 10 and Professions.NextRank(75).skill == 50)
check("nothing after Artisan", Professions.NextRank(300) == nil)
check("hunter advice: Skinning + Leatherworking", table.concat(Professions.GetAdvice("HUNTER").leveling, "+")
  == "Skinning+Leatherworking")
local known, primaries = Professions.Known({ { name = "Skinning", rank = 10, maxRank = 75 }, { name = "Bows", rank = 5, maxRank = 5 } })
check("known professions only", known.Skinning and not known.Bows and primaries == 1)
check("to learn: the other half of the pair and First Aid",
  table.concat(Professions.ToLearn("HUNTER", known, primaries), ",") == "Leatherworking,First Aid")
known, primaries = Professions.Known({ { name = "Mining" }, { name = "Herbalism" } })
check("two other primaries: the player's choice wins, only First Aid",
  table.concat(Professions.ToLearn("HUNTER", known, primaries), ",") == "First Aid")

---------------------------------------------------------------------------
section("Professions: steps")

Pathwise.charDB.professionAdvice = false
WoW.ClearChat()
SetSkills({})
check("chat advice once", WoW.ChatContains("Professions for a Hunter: Skinning + Leatherworking"))
local learn = Item("prof:learn")
check("learn step lists what's missing", learn and learn.text == "Learn professions: Skinning, Leatherworking, First Aid"
  and learn.priority == P.PROFESSION_LEARN)
check("learn step explains why, the gold option and how to hide it",
  learn.detail[1]:find("quivers", 1, true) and learn.detail[2] == "For gold instead: Skinning + Mining, and sell what you gather."
  and learn.detail[#learn.detail]:find("/pw professions off", 1, true))
WoW.ClearChat()
SetSkills({ { "Skinning", 1, 75 } })
check("advice not repeated", not WoW.ChatContains("Professions for a"))
check("learned ones drop out", Item("prof:learn").text == "Learn professions: Leatherworking, First Aid")

check("no knife: buy one", Item("prof:tool:Skinning") and Item("prof:tool:Skinning").text
  == "Buy a Skinning Knife (needed for Skinning)")
WoW.bagCounts[7005] = 1
WoW.FireEvent("BAG_UPDATE_DELAYED")
WoW.RunTimers()
check("knife in the bags: step gone", Item("prof:tool:Skinning") == nil)

SetSkills({ { "Skinning", 52, 75 }, { "Leatherworking", 75, 75 }, { "First Aid", 30, 75 } })
local train = Item("prof:train:Skinning")
check("skill 50+ at level 10+: train Journeyman", train and train.text == "Train Journeyman Skinning (52/75)"
  and train.priority == P.PROFESSION_TRAIN and Item("prof:learn") == nil)
check("skill at the cap: higher priority, says skill-ups are wasted", Item("prof:train:Leatherworking").priority
  == P.PROFESSION_CAPPED and Item("prof:train:Leatherworking").detail[1]:find("wasted", 1, true))
check("not enough skill yet: no training step", Item("prof:train:First Aid") == nil)
check("leatherworking needs no tool", Item("prof:tool:Leatherworking") == nil)

WoW.ClearChat()
WoW.Slash("professions")
check("/pw professions: advice and your skills", WoW.ChatContains("Professions for a Hunter")
  and WoW.ChatContains("Your professions: First Aid 30/75, Leatherworking 75/75, Skinning 52/75"))
WoW.Slash("professions off")
WoW.RunTimers()
check("/pw professions off hides the steps", Item("prof:train:Skinning") == nil and Item("prof:train:Leatherworking") == nil)
WoW.Slash("professions on")
WoW.RunTimers()
check("/pw professions on shows them again", Item("prof:train:Skinning") ~= nil)

---------------------------------------------------------------------------
section("Professions: trainers from QuestieDB")

-- Two Leatherworking trainers: a Horde one right here, an Alliance one 60 yd
-- away; plus an unrelated vendor with a similar title.
local trainers = {
  [9001] = { name = "Nadyia Maneweaver", subName = "Leatherworking Trainer", friendlyToFaction = "A",
    spawns = { [141] = { { 58, 42 } } } },
  [9002] = { name = "Horde Tanner", subName = "Leatherworking Trainer", friendlyToFaction = "H",
    spawns = { [141] = { { 58, 40.5 } } } },
  [9003] = { name = "Supply Guy", subName = "Leatherworking Supplies", friendlyToFaction = "AH",
    spawns = { [141] = { { 58, 40 } } } },
}
local npcGet = LibQuestieDB.Npc.Get
LibQuestieDB.Npc.Get = function(id, key)
  if trainers[id] then return trainers[id][key] end
  return npcGet(id, key)
end
LibQuestieDB.Npc.GetAllIds = function() return { 1986, 9001, 9002, 9003 } end
Pathwise:GetModule("QuestieData"):ResetTrainers()
S.mapID, S.mapX, S.mapY = 1438, 0.58, 0.40
SetSkills({ { "Skinning", 1, 75 } })
WoW.RunTimers()
learn = Item("prof:learn")
check("learn step points at the nearest friendly trainer", learn.target and learn.target.label
  == "Leatherworking trainer (Nadyia Maneweaver)" and learn.target.names[1] == "Nadyia Maneweaver")
check("trainer within reach: the step takes the arrow", learn.priority == P.PROFESSION_NEAR)
S.mapY = 0.70
Professions:Update()
check("far from the trainer: low priority again", Item("prof:learn").priority == P.PROFESSION_LEARN)
LibQuestieDB.Npc.Get, LibQuestieDB.Npc.GetAllIds = npcGet, nil
Pathwise:GetModule("QuestieData"):ResetTrainers()

---------------------------------------------------------------------------
section("Professions: Skinning tooltip")

local Tip = Pathwise:GetModule("ProfessionTooltip")
local unitLevel, creatureType = UnitLevel, UnitCreatureType
local mob = { level = 15, type = "Beast" }
UnitLevel = function(unit) if unit == "mouseover" then return mob.level end return S.level end
UnitCreatureType = function(unit) if unit == "mouseover" then return mob.type end end
UnitIsPlayer = function(unit) return unit == "player" end
SetSkills({ { "Skinning", 52, 75 } })
local function Strip(text) return text and (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
check("beast: needed and your skill, green", Strip(Tip.LineFor("mouseover")) == "Pathwise: Skinning 50 needed (you have 52)"
  and Tip.LineFor("mouseover"):find("^|cff20ff20"))
mob.level = 25
check("too high: red", Strip(Tip.LineFor("mouseover")) == "Pathwise: Skinning 125 needed (you have 52)"
  and Tip.LineFor("mouseover"):find("^|cffff4040"))
mob.type = "Humanoid"
check("not a beast: no line", Tip.LineFor("mouseover") == nil)
mob.type = "Beast"
SetSkills({ { "Mining", 52, 75 } })
check("no Skinning: no line", Tip.LineFor("mouseover") == nil)
SetSkills({ { "Skinning", 52, 75 } })
GameTooltip:ClearLines()
GameTooltip.GetUnit = function() return "Wolf", "mouseover" end
GameTooltip._scripts.OnTooltipSetUnit(GameTooltip)
GameTooltip._scripts.OnTooltipSetUnit(GameTooltip)
local count = 0
for _, line in ipairs(WoW.TooltipLines(GameTooltip)) do
  if line:find("Skinning", 1, true) then count = count + 1 end
end
check("tooltip hook adds the line once", count == 1)
GameTooltip.GetUnit = nil
UnitLevel, UnitCreatureType, UnitIsPlayer = unitLevel, creatureType, nil

-- Back to the default test character's skills.
SetSkills({ { "Skinning", 1, 75 } })
WoW.bagCounts = {}
