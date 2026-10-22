-- M1: character tracker, spec detection, goal prompt.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Character = Pathwise:GetModule("Character")
local Talents = Pathwise:GetModule("Talents")
local snapshot = Character:GetSnapshot()

---------------------------------------------------------------------------
section("M1: snapshot after login")

check("class token", snapshot.class == "HUNTER")
check("race/faction", snapshot.race == "NightElf" and snapshot.faction == "Alliance")
check("level", snapshot.level == 1)
check("zone", snapshot.zone.zone == "Teldrassil" and snapshot.zone.subZone == "Shadowglen")
check("three talent trees", #snapshot.talents.trees == 3 and snapshot.talents.trees[1].name == "Beast Mastery")
check("no talent points at level 1", snapshot.talents.spent == 0 and snapshot.talents.unspent == 0)
check("skills read", #snapshot.skills == 3 and snapshot.skills[1].header == "Professions")
check("snapshot persisted", PathwiseCharDB.lastSnapshot == snapshot)

---------------------------------------------------------------------------
section("M1: one-time goal prompt")

local prompt = _G.PathwiseGoalPrompt
check("prompt not shown before delay", prompt == nil or not prompt:IsShown())
WoW.RunTimers()
prompt = _G.PathwiseGoalPrompt
check("prompt shown after delay", prompt ~= nil and prompt:IsShown())
check("goalPrompted saved", PathwiseCharDB.goalPrompted == true)

WoW.ClearChat()
prompt:Hide()
check("dismiss message", WoW.ChatContains("No goal chosen, using Leveling"))
check("default goal active", Talents:GetSpecInfo().active == "LEVELING" and Talents:GetSpecInfo().source == "default")

-- Re-login: prompt must not show again
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
WoW.RunTimers()
check("prompt not repeated", not prompt:IsShown())

-- /pw spec opens it; clicking a button sets the goal
WoW.Slash("spec")
check("/pw spec opens prompt", prompt:IsShown())
local mmButton
for _, frame in ipairs(WoW.frames) do
  if frame._template == "UIPanelButtonTemplate" and frame.goalKey == "MARKSMANSHIP" then
    mmButton = frame
  end
end
check("hunter goal buttons exist", mmButton ~= nil)
WoW.ClearChat()
mmButton:Click()
check("button sets goal", PathwiseCharDB.goal == "MARKSMANSHIP" and not prompt:IsShown())
check("no dismiss message after choosing", not WoW.ChatContains("No goal chosen"))
check("goal used without talents", Talents:GetSpecInfo().active == "MARKSMANSHIP" and Talents:GetSpecInfo().source == "goal")

---------------------------------------------------------------------------
section("M1: /pw spec parsing")

check("parse alias bm", Talents:ParseGoal("bm") == "BEAST_MASTERY")
check("parse name", Talents:ParseGoal("Beast Mastery") == "BEAST_MASTERY")
check("parse prefix", Talents:ParseGoal("surv") == "SURVIVAL")
check("parse key", Talents:ParseGoal("leveling") == "LEVELING")
check("parse unknown", Talents:ParseGoal("healer") == nil)
WoW.ClearChat()
WoW.Slash("spec tank")
check("unknown goal lists options", WoW.ChatContains("Options: Leveling, Beast Mastery, Marksmanship, Survival"))
WoW.Slash("spec lvl")
check("/pw spec lvl", PathwiseCharDB.goal == "LEVELING")

---------------------------------------------------------------------------
section("M1: leveling, gear and talents")

S.level = 12
S.xp, S.xpMax, S.rested = 1500, 7000, 3200
WoW.FireEvent("PLAYER_LEVEL_UP", 12)
check("level from event", snapshot.level == 12)
check("unspent points", snapshot.talents.unspent == 3)

-- UnitLevel lagging behind the event must not lower the level
S.level = 11
WoW.FireEvent("PLAYER_XP_UPDATE", "player")
WoW.FireEvent("PLAYER_LEVEL_UP", 12)
check("level never decreases", snapshot.level == 12)
S.level = 12

S.inventory[5] = { id = 6123, name = "Novice's Robe" }
S.inventory[18] = { id = 2504, name = "Worn Shortbow" }
S.inventory[0] = { id = 2512, name = "Rough Arrow" }
S.inventory[16] = { id = 12345, name = "Uncached Axe", uncached = true }
WoW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 5, false)
check("chest item", snapshot.equipment[5] and snapshot.equipment[5].name == "Novice's Robe" and snapshot.equipment[5].itemID == 6123)
check("ranged item", snapshot.equipment[18] and snapshot.equipment[18].name == "Worn Shortbow")
check("ammo slot 0 (link via GetItemInfo)", snapshot.equipment[0] and snapshot.equipment[0].name == "Rough Arrow" and not snapshot.equipment[0].pending)
check("uncached item pending", snapshot.equipment[16] and snapshot.equipment[16].pending == true)
S.inventory[16].uncached = nil
WoW.RunTimers()
check("pending item resolved by retry", snapshot.equipment[16].pending == false and snapshot.equipment[16].name == "Uncached Axe")

-- Spend 3 points in Beast Mastery
WoW.SetTalentRank(1, 1, 3)
WoW.FireEvent("CHARACTER_POINTS_CHANGED", -1)
local info = Talents:GetSpecInfo()
check("BM detected from talents", info.detected == "BEAST_MASTERY" and info.active == "BEAST_MASTERY" and info.source == "talents")
check("unspent decreased", snapshot.talents.unspent == 0 and snapshot.talents.spent == 3)

-- Hybrid: BM 3 / MM 2
S.level = 14
WoW.FireEvent("PLAYER_LEVEL_UP", 14)
WoW.SetTalentRank(2, 1, 2)
WoW.FireEvent("CHARACTER_POINTS_CHANGED", -1)
info = Talents:GetSpecInfo()
check("hybrid detected", info.hybrid and info.detected == nil and info.active == "LEVELING" and info.source == "goal")

-- Clear lead: BM 7 / MM 2
S.level = 18
WoW.FireEvent("PLAYER_LEVEL_UP", 18)
WoW.SetTalentRank(1, 1, 5)
WoW.SetTalentRank(1, 2, 2)
WoW.FireEvent("CHARACTER_POINTS_CHANGED", -1)
info = Talents:GetSpecInfo()
check("clear lead wins over goal", info.detected == "BEAST_MASTERY" and not info.hybrid)

check("DetectSpec: all zero", Talents.DetectSpec("HUNTER", { { index = 1, points = 0 }, { index = 2, points = 0 } }) == nil)
check("DetectSpec: margin counts as hybrid", select(2, Talents.DetectSpec("HUNTER", { { index = 1, points = 5 }, { index = 2, points = 8 } })) == true)
check("DetectSpec: MM", Talents.DetectSpec("HUNTER", { { index = 1, points = 0 }, { index = 2, points = 4 }, { index = 3, points = 0 } }) == "MARKSMANSHIP")
check("DetectSpec: unknown class", Talents.DetectSpec("DEATHKNIGHT", { { index = 2, points = 4 } }) == "TREE2")

---------------------------------------------------------------------------
section("M1: /pw status")

WoW.ClearChat()
WoW.Slash("status")
check("status identity", WoW.ChatContains("Testhunter-Mockrealm: level 18 Night Elf Hunter (Alliance)"))
check("status xp with rested", WoW.ChatContains("XP: 1,500 / 7,000 (21%), rested 3,200"))
check("status zone", WoW.ChatContains("Zone: Teldrassil - Shadowglen (map 1438)"))
check("status spec", WoW.ChatContains("Spec: Beast Mastery (from talents 7/2/0) - goal: Leveling"))
check("status talents", WoW.ChatContains("Talents: Beast Mastery 7 / Marksmanship 2 / Survival 0 - unspent"))
check("status talent ranks", WoW.ChatContains("Improved Aspect of the Hawk 5/5, Endurance Training 2/5"))
check("status gear", WoW.ChatContains("Ranged: [Worn Shortbow]") and WoW.ChatContains("Ammo: [Rough Arrow]"))
check("status empty slots", WoW.ChatContains("Empty: Head, Neck"))
check("status skills", WoW.ChatContains("Weapon Skills: Bows 5/5, Daggers 1/5"))
check("status client", WoW.ChatContains("Client 1.15.9 (interface 11509)"))

-- Max level
S.level = 60
WoW.FireEvent("PLAYER_LEVEL_UP", 60)
WoW.ClearChat()
WoW.Slash("status")
check("status at max level", WoW.ChatContains("XP: max level"))

---------------------------------------------------------------------------
section("M1: prompt waits for combat to end")

S.inCombat = true
WoW.Slash("spec")
check("not shown in combat", not _G.PathwiseGoalPrompt:IsShown())
S.inCombat = false
WoW.FireEvent("PLAYER_REGEN_ENABLED")
check("shown after combat", _G.PathwiseGoalPrompt:IsShown())
_G.PathwiseGoalPrompt:Hide()

---------------------------------------------------------------------------
section("M1: /pw reset char")

WoW.Slash("reset char")
check("goal cleared by reset char", PathwiseCharDB.goal == nil and PathwiseCharDB.goalPrompted == false)
check("spec falls back to talents", Talents:GetSpecInfo().active == "BEAST_MASTERY")
