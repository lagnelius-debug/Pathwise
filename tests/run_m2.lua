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

SetLevel(5)
S.inventory = {}
Equip(8, 148)    -- Rugged Trapper's Boots (no stats)
Equip(18, 2504)  -- Worn Shortbow
Equip(16, 2092)  -- Worn Dagger
Equip(5, 6123)   -- Novice's Robe
check("level 5 set", snapshot.level == 5)
check("weights fall back to LEVELING", select(2, GearScore:GetWeights()) == "LEVELING")

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
check("armor-only boots vs no-stat boots: upgrade", line == "Pathwise: upgrade")

Equip(8, 2309)
check("equipped item: no line", WoW.HoverItem(2309) == nil)
line = WoW.HoverItem(9001)
check("percent upgrade", line == "Pathwise: +337% upgrade")
check("cloth boots usable for hunter", WoW.HoverItem(9002) == "Pathwise: +275% upgrade")

check("plate not usable", WoW.HoverItem(9004) == "Pathwise: not usable by your class")
check("mace not usable", WoW.HoverItem(9005) == "Pathwise: not usable by your class")
check("mail below 40: upgrade at level 40", WoW.HoverItem(9003) == "Pathwise: upgrade at level 40")
check("bow above player level", WoW.HoverItem(9006) == "Pathwise: +113% upgrade at level 8")

check("ring into empty slot", WoW.HoverItem(9007) == "Pathwise: upgrade (empty slot)")
Equip(11, 9007)
check("second ring still has an empty slot", WoW.HoverItem(9008) == "Pathwise: upgrade (empty slot)")
Equip(12, 9009)
check("ring compared with the weaker ring", WoW.HoverItem(9008) == "Pathwise: +500% upgrade")

line = WoW.HoverItem(9011)
check("one-hander without dual wield compares main hand only", line == "Pathwise: +400% upgrade")
check("two-hander vs main + off hand", WoW.HoverItem(9010) == "Pathwise: +1525% upgrade")

check("downgrade", WoW.HoverItem(2092) == nil) -- equipped
Equip(16, 9011)
check("worn dagger now a downgrade", WoW.HoverItem(2092) == "Pathwise: -80% downgrade")

SetLevel(20)
check("dual wield at 20: off hand empty", WoW.HoverItem(2092) == "Pathwise: upgrade (empty slot)")
Equip(16, 9010) -- two-hander equipped
check("one-hander vs equipped two-hander", WoW.HoverItem(9011) == "Pathwise: -69% downgrade")
Equip(16, 9011)

check("chat link tooltip", WoW.HoverItem(9001, ItemRefTooltip) == "Pathwise: +337% upgrade")

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
check("debug shows scores", WoW.HoverItem(9001) == "Pathwise: +337% upgrade (2.8 vs 0.6)")
Pathwise.db.debug = false

---------------------------------------------------------------------------
section("M2: spec change and other classes")

Pathwise.Data.StatWeights.HUNTER.BEAST_MASTERY = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_STAMINA_SHORT = 2 }
Pathwise:FireCallback("SPEC_CHANGED", {})
-- spirit has no BM weight here, so the weaker ring scores 0
check("cache cleared on spec change", WoW.HoverItem(9008) == "Pathwise: upgrade")
Pathwise.Data.StatWeights.HUNTER.BEAST_MASTERY = nil
Pathwise:FireCallback("SPEC_CHANGED", {})

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
