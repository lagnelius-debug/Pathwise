-- M5 talent advisor and M6 hunter module.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Talents = Pathwise:GetModule("Talents")
local NextSteps = Pathwise:GetModule("NextSteps")
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()

local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end

local function SetLevel(level)
  snapshot.level = nil
  S.level = level
  WoW.FireEvent("PLAYER_LEVEL_UP", level)
  WoW.RunTimers()
end

-- Real hunter talent layout (1.12) for the trees the builds use.
S.talentTabs = {
  { name = "Beast Mastery", talents = {
    { "Improved Aspect of the Hawk", 1, 2, 0, 5 }, { "Endurance Training", 1, 3, 0, 5 },
    { "Improved Eyes of the Beast", 2, 1, 0, 2 }, { "Improved Aspect of the Monkey", 2, 2, 0, 5 },
    { "Thick Hide", 2, 3, 0, 3 }, { "Improved Revive Pet", 2, 4, 0, 2 },
    { "Pathfinding", 3, 1, 0, 2 }, { "Bestial Swiftness", 3, 2, 0, 1 }, { "Unleashed Fury", 3, 3, 0, 5 },
    { "Improved Mend Pet", 4, 2, 0, 2 }, { "Ferocity", 4, 3, 0, 5 },
    { "Spirit Bond", 5, 1, 0, 2 }, { "Intimidation", 5, 2, 0, 1 }, { "Bestial Discipline", 5, 4, 0, 2 },
    { "Frenzy", 6, 3, 0, 5 }, { "Bestial Wrath", 7, 2, 0, 1 },
  } },
  { name = "Marksmanship", talents = {
    { "Improved Concussive Shot", 1, 2, 0, 5 }, { "Efficiency", 1, 3, 0, 5 },
    { "Improved Hunter's Mark", 2, 2, 0, 5 }, { "Lethal Shots", 2, 3, 0, 5 },
    { "Aimed Shot", 3, 1, 0, 1 }, { "Improved Arcane Shot", 3, 2, 0, 5 }, { "Hawk Eye", 3, 4, 0, 3 },
    { "Improved Serpent Sting", 4, 2, 0, 5 }, { "Mortal Shots", 4, 3, 0, 5 },
    { "Scatter Shot", 5, 1, 0, 1 }, { "Barrage", 5, 2, 0, 3 }, { "Improved Scorpid Sting", 5, 3, 0, 3 },
    { "Ranged Weapon Specialization", 6, 3, 0, 5 }, { "Trueshot Aura", 7, 2, 0, 1 },
  } },
  { name = "Survival", talents = {
    { "Monster Slaying", 1, 1, 0, 3 }, { "Humanoid Slaying", 1, 2, 0, 3 }, { "Deflection", 1, 3, 0, 5 },
  } },
}
local function Rank(tab, name, rank)
  for _, t in ipairs(S.talentTabs[tab].talents) do
    if t[1] == name then t[4] = rank end
  end
  WoW.FireEvent("CHARACTER_POINTS_CHANGED", -1)
  WoW.RunTimers()
end

---------------------------------------------------------------------------
section("M5: talent advisor")

WoW.Slash("spec leveling")
Pathwise.charDB.talentAnnouncedLevel = nil
S.inventory = { [18] = { id = 2504 }, [0] = { id = 2512, count = 1000 } }
WoW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 18, false)
SetLevel(9)
check("no talent step before level 10", Item("talent") == nil)

WoW.ClearChat()
SetLevel(10)
local item = Item("talent")
check("level 10: spend a point", item and item.text == "Spend 1 talent point: Improved Aspect of the Hawk (1/5)")
check("chat reminder", WoW.ChatContains("Next talent point: Improved Aspect of the Hawk (1/5)."))
check("detail shows the build", item.detail[1] == "Beast Mastery leveling (31/20/0)")

Rank(1, "Improved Aspect of the Hawk", 1)
check("point spent: step gone", Item("talent") == nil)
WoW.ClearChat()
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
WoW.RunTimers()
check("no repeat reminder at the same level", not WoW.ChatContains("Next talent point"))

SetLevel(15)
Rank(1, "Improved Aspect of the Hawk", 5)
-- 1 point left at 15 (6 points earned, 5 spent)
check("after Hawk 5/5: Endurance Training", Item("talent") and Item("talent").text:find("Endurance Training (1/5)", 1, true))

-- Deviation: the player put the point in Thick Hide instead; no nagging
Rank(1, "Thick Hide", 1)
SetLevel(16)
check("deviation: still suggests the next build talent", Item("talent").text:find("Endurance Training (1/5)", 1, true))

-- Goal Marksmanship (no clear spec yet? BM has 6 points -> BM detected)
check("BM points: BM build", Talents:GetBuild().name:find("Beast Mastery", 1, true))

-- Upcoming list respects tiers: with 0 MM points, MM build starts at tier 1
local MM = Pathwise.Data.TalentBuilds.HUNTER.builds.MM_LEVELING
local upcoming = Talents.UpcomingPoints(snapshot.talents.trees, MM, 12)
check("MM build: Efficiency first", upcoming[1].name == "Efficiency" and upcoming[1].rank == 1)
check("MM build: Lethal Shots after 5 Efficiency", upcoming[6].name == "Lethal Shots")
check("MM build: Aimed Shot at point 11", upcoming[11].name == "Aimed Shot")

WoW.ClearChat()
WoW.Slash("talents")
check("/pw talents lists next points", WoW.ChatContains("Beast Mastery leveling (31/20/0) - unspent points: 1. Next:")
  and WoW.ChatContains("1. Endurance Training (1/5)"))
WoW.ClearChat()
WoW.Slash("talents check")
check("/pw talents check: all match", WoW.ChatContains("Checked 16 talent picks: 0 mismatches."))
S.talentTabs[1].talents[2][3] = 4 -- move Endurance Training in the "client"
WoW.FireEvent("CHARACTER_POINTS_CHANGED", -1)
WoW.ClearChat()
WoW.Slash("talents check")
check("/pw talents check reports a mismatch", WoW.ChatContains("Endurance Training expected at tree 1, tier 1, column 3"))
S.talentTabs[1].talents[2][3] = 3
WoW.FireEvent("CHARACTER_POINTS_CHANGED", -1)

---------------------------------------------------------------------------
section("M6: ammo")

local H = Pathwise:GetModule("Hunter")
check("ammo states", H.AmmoState(500, true, 200, 50) == "ok" and H.AmmoState(150, true, 200, 50) == "low"
  and H.AmmoState(10, true, 200, 50) == "critical" and H.AmmoState(0, false, 200, 50) == "none")

local function Ammo(count)
  S.inventory[0] = count and { id = 2512, count = count } or nil
  WoW.FireEvent("BAG_UPDATE_DELAYED")
  WoW.RunTimers()
end

WoW.ClearChat()
Ammo(1000)
check("plenty of ammo: no step", Item("ammo") == nil and not WoW.ChatContains("ammo"))
Ammo(140)
check("low ammo step", Item("ammo") and Item("ammo").text == "Low ammo: 140 arrows left")
check("low ammo chat once", WoW.ChatContains("Low ammo: 140 arrows left."))
WoW.ClearChat()
Ammo(120)
check("no repeat chat while still low", not WoW.ChatContains("Low ammo"))
Ammo(30)
check("critical ammo", Item("ammo").text == "Almost out of ammo: 30 arrows left!" and WoW.ChatContains("Almost out of ammo"))
check("critical ammo is urgent", Item("ammo").priority == NextSteps.PRIORITY.AMMO_CRITICAL)
Ammo(nil)
check("no ammo equipped", Item("ammo").text == "No ammo equipped! Put arrows in your ammo slot.")
WoW.ClearChat()
WoW.Slash("ammo 300 100")
check("/pw ammo sets thresholds", Pathwise.db.ammoWarn == 300 and Pathwise.db.ammoCritical == 100)
WoW.Slash("ammo 50 100")
check("/pw ammo rejects critical >= warn", WoW.ChatContains("Usage: /pw ammo"))
Pathwise.db.ammoWarn, Pathwise.db.ammoCritical = 200, 50
-- Thrown weapon: no ammo needed
S.inventory[18] = { id = 9017 }
WoW.items[9017] = { name = "Throwing Knife", equipLoc = "INVTYPE_THROWN", classID = 2, subclassID = 16, stats = {} }
WoW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 18, false)
WoW.RunTimers()
check("thrown weapon: no ammo step", Item("ammo") == nil)
S.inventory[18] = { id = 2504 }
WoW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 18, false)
Ammo(1000)

---------------------------------------------------------------------------
section("M6: pet")

WoW.ClearChat()
S.pet = { name = "Sabertooth", happiness = 3, foods = { "Meat", "Fish" } }
WoW.FireEvent("UNIT_PET", "player")
WoW.RunTimers()
check("happy pet: no step", Item("pet") == nil)
S.pet.happiness = 2
WoW.FireEvent("UNIT_HAPPINESS", "pet")
WoW.RunTimers()
check("content pet: feed step", Item("pet") and Item("pet").text == "Feed Sabertooth (content)"
  and Item("pet").detail[1] == "Eats: Meat, Fish")
check("content pet chat", WoW.ChatContains("Sabertooth is content - feed it. It eats: Meat, Fish."))
S.pet.happiness = 1
WoW.FireEvent("UNIT_HAPPINESS", "pet")
WoW.RunTimers()
check("unhappy pet is urgent", Item("pet").priority == NextSteps.PRIORITY.PET_UNHAPPY)
S.pet.happiness = 3
WoW.FireEvent("UNIT_HAPPINESS", "pet")
WoW.RunTimers()
check("fed: step gone", Item("pet") == nil)
S.pet = nil
WoW.FireEvent("UNIT_PET", "player")
WoW.RunTimers()

---------------------------------------------------------------------------
section("M6: taming quest")

S.race = { "Night Elf", "NightElf", 4 }
Pathwise.charDB.tamingReminded = false
WoW.knownSpells[1515] = nil
-- QuestieDB knows who gives quest 6063

local questie = Pathwise:GetModule("QuestieData")
if questie:IsAvailable() then
  -- add Dazalar and the quest to the mock database from run_questie.lua
  local q, n = LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get
  LibQuestieDB.Quest.Get = function(id, key)
    if id == 6063 and key == "startedBy" then return { { 3601 } } end
    return q(id, key)
  end
  LibQuestieDB.Npc.Get = function(id, key)
    if id == 3601 then return ({ name = "Dazalar", spawns = { [141] = { { 56.7, 59.5 } } } })[key] end
    return n(id, key)
  end
end
WoW.ClearChat()
SetLevel(10)
WoW.RunTimers()
local taming = Item("taming")
check("level 10 without Tame Beast: taming step", taming and taming.text:find("Taming the Beast", 1, true))
check("taming chat once", WoW.ChatContains("visit your hunter trainer for the Taming the Beast quests"))
check("arrow target: the trainer who gives the quest", taming.target and taming.target.label == "Taming the Beast (Dazalar)"
  and taming.target.names[1] == "Dazalar")
WoW.ClearChat()
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
WoW.RunTimers()
check("taming chat not repeated", not WoW.ChatContains("Taming the Beast"))
WoW.knownSpells[1515] = true
WoW.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 1515, 1)
WoW.RunTimers()
check("Tame Beast learned: step gone", Item("taming") == nil)

-- Not a hunter: module stays quiet
S.class = { "Warrior", "WARRIOR", 1 }
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
WoW.RunTimers()
check("other classes: no hunter steps", Item("ammo") == nil and Item("pet") == nil)
S.class = { "Hunter", "HUNTER", 3 }
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
WoW.RunTimers()
