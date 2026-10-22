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
check("ScoreStats armor", math.abs(GearScore.ScoreStats({ RESISTANCE0_NAME = 16 }, weights, false) - 0.64) < 1e-9)
check("ScoreStats ranged dps", GearScore.ScoreStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2 }, weights, true) == 6)
check("ScoreStats melee dps", math.abs(GearScore.ScoreStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2 }, weights, false) - 0.4) < 1e-9)
check("ScoreStats ignores unknown stats", GearScore.ScoreStats({ ITEM_MOD_FOO = 50 }, weights, false) == 0)

---------------------------------------------------------------------------
section("M2: tooltip lines")

check("tooltip hook installed", GearScore and Pathwise:GetModule("Tooltip").hookMethod == "OnTooltipSetItem")

local line = WoW.HoverItem(2309)
check("armor-only boots vs no-stat boots: +8% of total (0.64 / 7.82)", line == "Pathwise: +8% upgrade")

Equip(8, 2309)
check("equipped item: no line", WoW.HoverItem(2309) == nil)
-- Swapping back is about as big a change the other way (0.64 / 8.46).
check("downgrade mirrors the upgrade", WoW.HoverItem(148) == "Pathwise: -8% downgrade")
line = WoW.HoverItem(9001)
check("percent upgrade", line == "Pathwise: +26% upgrade")
check("cloth boots usable for hunter", WoW.HoverItem(9002) == "Pathwise: +21% upgrade")

check("plate not usable", WoW.HoverItem(9004) == "Pathwise: not usable by your class")
check("mace not usable", WoW.HoverItem(9005) == "Pathwise: not usable by your class")
check("mail below 40: upgrade at level 40", WoW.HoverItem(9003) == "Pathwise: +38% upgrade at level 40")
check("bow above player level", WoW.HoverItem(9006) == "Pathwise: +100% upgrade at level 8")

check("ring into empty slot", WoW.HoverItem(9007) == "Pathwise: +35% upgrade (empty slot)")
Equip(11, 9007)
check("second ring still has an empty slot", WoW.HoverItem(9008) == "Pathwise: +10% upgrade (empty slot)")
Equip(12, 9009)
check("ring compared with the weaker ring", WoW.HoverItem(9008) == "Pathwise: +9% upgrade")

line = WoW.HoverItem(9011)
check("one-hander without dual wield compares main hand only", line == "Pathwise: +11% upgrade")
check("two-hander vs main + off hand", WoW.HoverItem(9010) == "Pathwise: +42% upgrade")

check("downgrade", WoW.HoverItem(2092) == nil) -- equipped
Equip(16, 9011)
check("worn dagger now a downgrade", WoW.HoverItem(2092) == "Pathwise: -10% downgrade")

SetLevel(20)
check("dual wield at 20: off hand empty", WoW.HoverItem(2092) == "Pathwise: +2% upgrade (empty slot)")
Equip(16, 9010) -- two-hander equipped
check("one-hander vs equipped two-hander", WoW.HoverItem(9011) == "Pathwise: -22% downgrade")
Equip(16, 9011)

check("chat link tooltip", WoW.HoverItem(9001, ItemRefTooltip) == "Pathwise: +17% upgrade")

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
check("debug shows scores", WoW.HoverItem(9001) == "Pathwise: +17% upgrade (2.8 vs 0.6)")
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
check("Survival verdict", WoW.HoverItem(9008) == "Pathwise: +8% upgrade")

-- A spec without weights falls back to Leveling.
local survival = Pathwise.Data.StatWeights.HUNTER.SURVIVAL
Pathwise.Data.StatWeights.HUNTER.SURVIVAL = nil
Pathwise:FireCallback("SPEC_CHANGED", {})
check("missing spec falls back to LEVELING", select(2, GearScore:GetWeights()) == "LEVELING")
Pathwise.Data.StatWeights.HUNTER.SURVIVAL = survival
WoW.Slash("spec leveling")

snapshot.class = "WARRIOR"
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
check("/pw stats header", WoW.ChatContains("[Agile Boots]: INVTYPE_FEET, class 4/2, min level 0, score 2.80"))
check("/pw stats keys", WoW.ChatContains("ITEM_MOD_AGILITY_SHORT = 2") and WoW.ChatContains("RESISTANCE0_NAME = 20"))
WoW.ClearChat()
WoW.Slash("stats")
check("/pw stats usage", WoW.ChatContains("Usage: /pw stats"))
