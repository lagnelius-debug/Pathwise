-- M2: gear advisor and tooltip line.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Character = Pathwise:GetModule("Character")
local GearScore = Pathwise:GetModule("GearScore")
local snapshot = Character:GetSnapshot()

local function SetLevel(level)
  snapshot.level = nil -- the tracker never lowers the level by itself
  S.level = level
  WoW.FireEvent("PLAYER_LEVEL_UP", level)
end

local function Equip(slot, itemID)
  S.inventory[slot] = itemID and { id = itemID } or nil
  WoW.FireEvent("PLAYER_EQUIPMENT_CHANGED", slot, itemID == nil)
end

---------------------------------------------------------------------------
section("M2: setup")

-- Start from no talents and the Leveling goal, so the goal picks the weights.
for tab = 1, #S.talentTabs do
  for i = 1, #S.talentTabs[tab].talents do WoW.SetTalentRank(tab, i, 0) end
end
WoW.FireEvent("CHARACTER_POINTS_CHANGED", 0)
WoW.Slash("spec leveling")
SetLevel(5)
S.inventory = {}
Equip(8, 148)    -- Rugged Trapper's Boots (no stats)
Equip(18, 2504)  -- Worn Shortbow
Equip(16, 2092)  -- Worn Dagger
Equip(5, 6123)   -- Novice's Robe
check("level 5 set", snapshot.level == 5)
check("Leveling weights in use", select(2, GearScore:GetWeights()) == "LEVELING")

---------------------------------------------------------------------------
section("M2: scoring")

local weights = GearScore:GetWeights()
check("ScoreStats armor", math.abs(GearScore.ScoreStats({ RESISTANCE0_NAME = 16 }, weights, false) - 0.16) < 1e-9)
check("ScoreStats ranged dps", GearScore.ScoreStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2 }, weights, true) == 6)
check("ScoreStats melee dps", math.abs(GearScore.ScoreStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2 }, weights, false) - 0.4) < 1e-9)
check("ScoreStats ignores unknown stats", GearScore.ScoreStats({ ITEM_MOD_FOO = 50 }, weights, false) == 0)
-- Seen in game (Pagan Belt of Healing): +healing comes without _SHORT.
local holy = Pathwise.Data.StatWeights.PRIEST.HOLY
check("ScoreStats: a key without _SHORT matches the weight", math.abs(GearScore.ScoreStats(
  { ITEM_MOD_SPELL_HEALING_DONE = 8 }, holy, false) - 8 * holy.ITEM_MOD_SPELL_HEALING_DONE_SHORT) < 1e-9)
check("ScoreStats: and the other way round", GearScore.ScoreStats({ ITEM_MOD_STAMINA = 2 }, weights, false)
  == GearScore.ScoreStats({ ITEM_MOD_STAMINA_SHORT = 2 }, weights, false))
-- Reported in game: Sleeping Robes (19 armor, +1 Stamina) showed as a
-- downgrade from Woodland Tunic (33 armor). +1 Stamina (+10 health) is worth
-- more than 14 armor on every hunter path.
for spec, specWeights in pairs(Pathwise.Data.StatWeights.HUNTER) do
  local robe = GearScore.ScoreStats({ RESISTANCE0_NAME = 19, ITEM_MOD_STAMINA_SHORT = 1 }, specWeights, false)
  local tunic = GearScore.ScoreStats({ RESISTANCE0_NAME = 33 }, specWeights, false)
  check("+1 Stamina beats 14 armor (" .. spec .. ")", robe > tunic)
  check("but armor still breaks ties between items without stats (" .. spec .. ")", tunic > 0)
end

---------------------------------------------------------------------------
section("M2: tooltip lines")

check("tooltip hook installed", GearScore and Pathwise:GetModule("Tooltip").hookMethod == "OnTooltipSetItem")

local line = WoW.HoverItem(2309)
check("armor-only boots vs no-stat boots: small upgrade (armor counts little)", line == "Pathwise: +2% upgrade")

Equip(8, 2309)
check("equipped item: no line", WoW.HoverItem(2309) == nil)
-- Swapping back is about as big a change the other way.
check("downgrade mirrors the upgrade", WoW.HoverItem(148) == "Pathwise: -2% downgrade")
line = WoW.HoverItem(9001)
check("percent upgrade", line == "Pathwise: +26% upgrade")
check("cloth boots usable for hunter", WoW.HoverItem(9002) == "Pathwise: +24% upgrade")

check("plate not usable", WoW.HoverItem(9004) == "Pathwise: not usable by your class")
check("mace not usable", WoW.HoverItem(9005) == "Pathwise: not usable by your class")
-- Reported in game: Barkmail Leggings showed "+24% upgrade at level 40" to
-- a low-level hunter. Too far away to count as an upgrade.
check("mail below 40: not an upgrade, usable much later", WoW.HoverItem(9003)
  == "Pathwise: usable at level 40 - you'll have better gear by then")
check("bow above player level", WoW.HoverItem(9006) == "Pathwise: +107% upgrade at level 8")
check("5 levels away: still an upgrade later", (WoW.HoverItem(9030) or ""):find("upgrade at level 10$") ~= nil)
check("6 levels away: too far", WoW.HoverItem(9031) == "Pathwise: usable at level 11 - you'll have better gear by then")

check("ring into empty slot", WoW.HoverItem(9007) == "Pathwise: +38% upgrade (empty slot)")
Equip(11, 9007)
check("second ring still has an empty slot", WoW.HoverItem(9008) == "Pathwise: +11% upgrade (empty slot)")
Equip(12, 9009)
check("ring compared with the weaker ring", WoW.HoverItem(9008) == "Pathwise: +9% upgrade")

line = WoW.HoverItem(9011)
check("one-hander without dual wield compares main hand only", line == "Pathwise: +11% upgrade")
check("two-hander vs main + off hand", WoW.HoverItem(9010) == "Pathwise: +44% upgrade")

check("downgrade", WoW.HoverItem(2092) == nil) -- equipped
Equip(16, 9011)
check("worn dagger now a downgrade", WoW.HoverItem(2092) == "Pathwise: -10% downgrade")

SetLevel(20)
check("dual wield at 20: off hand empty", WoW.HoverItem(2092) == "Pathwise: +3% upgrade (empty slot)")
Equip(16, 9010) -- two-hander equipped
check("one-hander vs equipped two-hander", WoW.HoverItem(9011) == "Pathwise: -22% downgrade")
Equip(16, 9011)

-- Weapon skills: the class can use staves, but this hunter hasn't learned them
check("unlearned weapon skill: upgrade after training", (WoW.HoverItem(9013) or ""):find("(learn Staves first)", 1, true) ~= nil)
check("learned weapon skill: no training note", not (WoW.HoverItem(9015) or ""):find("learn", 1, true))
check("class can't use maces at all", WoW.HoverItem(9014) == "Pathwise: not usable by your class")
WoW.skills[227] = true
check("after learning Staves the note is gone", not (WoW.HoverItem(9013) or ""):find("learn", 1, true))
WoW.skills[227] = nil

check("chat link tooltip", WoW.HoverItem(9001, ItemRefTooltip) == "Pathwise: +16% upgrade")

-- No duplicate line when OnTooltipSetItem fires twice
WoW.HoverItem(9001)
GameTooltip._scripts.OnTooltipSetItem(GameTooltip)
local count = 0
for i = 1, GameTooltip:NumLines() do
  local text = _G["GameTooltipTextLeft" .. i]._text
  if text and text:find("Pathwise", 1, true) then count = count + 1 end
end
check("no duplicate tooltip line", count == 1)

check("ammo gets no line", WoW.HoverItem(2512) == nil)

Pathwise.db.debug = true
check("debug shows scores", WoW.HoverItem(9001) == "Pathwise: +16% upgrade (2.2 vs 0.2)")
Pathwise.db.debug = false

---------------------------------------------------------------------------
section("M2: spec change and other classes")

-- Switching goal (no talents spent) switches weights and clears the cache.
-- Stamina ring vs spirit ring: the gain differs per spec's weights.
WoW.Slash("spec bm")
check("goal BM uses BM weights", select(2, GearScore:GetWeights()) == "BEAST_MASTERY")
check("BM verdict", WoW.HoverItem(9008) == "Pathwise: +11% upgrade")
WoW.Slash("spec mm")
check("MM verdict", WoW.HoverItem(9008) == "Pathwise: +5% upgrade")
WoW.Slash("spec surv")
check("Survival verdict", WoW.HoverItem(9008) == "Pathwise: +9% upgrade")

-- A spec without weights falls back to Leveling.
local survival = Pathwise.Data.StatWeights.HUNTER.SURVIVAL
Pathwise.Data.StatWeights.HUNTER.SURVIVAL = nil
Pathwise:FireCallback("SPEC_CHANGED", {})
check("missing spec falls back to LEVELING", select(2, GearScore:GetWeights()) == "LEVELING")
Pathwise.Data.StatWeights.HUNTER.SURVIVAL = survival
WoW.Slash("spec leveling")

snapshot.class = "DEATHKNIGHT" -- a class without data
check("no weights for other classes: no line", WoW.HoverItem(9001) == nil)
WoW.ClearChat()
WoW.Slash("score")
check("/pw score without weights", WoW.ChatContains("No stat weights for"))
snapshot.class = "HUNTER"

---------------------------------------------------------------------------
section("M2: /pw score")

WoW.ClearChat()
WoW.Slash("score")
check("/pw score header", WoW.ChatContains("Gear scores (Hunter, Leveling weights):"))
check("/pw score ranged line", WoW.ChatContains("Ranged: [Worn Shortbow] 7.5"))
check("/pw score total", WoW.ChatContains("Total: "))

WoW.ClearChat()
WoW.Slash("stats " .. WoW.ItemLink(9001))
check("/pw stats header", WoW.ChatContains("[Agile Boots]: INVTYPE_FEET, class 4/2, min level 0, score 2.20"))
check("/pw stats keys", WoW.ChatContains("ITEM_MOD_AGILITY_SHORT = 2") and WoW.ChatContains("RESISTANCE0_NAME = 20"))
WoW.ClearChat()
WoW.Slash("stats")
check("/pw stats usage", WoW.ChatContains("Usage: /pw stats"))
