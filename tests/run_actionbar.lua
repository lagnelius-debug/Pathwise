-- New spell ranks onto the action bars (Core/ActionBarRanks.lua).
local WoW, Pathwise, check, section = ...
local S = WoW.state

local ActionBarRanks = Pathwise:GetModule("ActionBarRanks")

---------------------------------------------------------------------------
section("Action bars: which buttons")

local function Ids(list) return table.concat(list, ",") end
local slots = {
  { slot = 1, name = "Frostbolt", rank = 4 },
  { slot = 2, name = "Frostbolt", rank = 1 },   -- kept on purpose (to slow)
  { slot = 13, name = "Frostbolt", rank = 4 },  -- on another bar too
  { slot = 3, name = "Fireball", rank = 4 },
}
local list, old = ActionBarRanks.SlotsToUpgrade("Frostbolt", 5, slots)
check("the highest lower rank's buttons, on every bar; a low rank kept on its own stays", Ids(list) == "1,13" and old == 4)
check("only Rank 1 on the bars: it's the one to change", Ids(ActionBarRanks.SlotsToUpgrade("Frostbolt", 5,
  { { slot = 2, name = "Frostbolt", rank = 1 } })) == "2")
check("a rank skipped (3 on the bars, 5 learned): changed", Ids(ActionBarRanks.SlotsToUpgrade("Frostbolt", 5,
  { { slot = 1, name = "Frostbolt", rank = 3 } })) == "1")
check("nothing of that spell, or a higher rank already: nothing", #ActionBarRanks.SlotsToUpgrade("Frostbolt", 5,
  { { slot = 3, name = "Fireball", rank = 4 }, { slot = 4, name = "Frostbolt", rank = 6 } }) == 0)

---------------------------------------------------------------------------
section("Action bars: learning a rank")

-- Frostbolt Rank 4 (8406) on slots 1 and 13, Rank 1 (116) on slot 2.
local names = { [116] = "Frostbolt", [8406] = "Frostbolt", [8407] = "Frostbolt", [143] = "Fireball" }
local ranks = { [116] = "Rank 1", [8406] = "Rank 4", [8407] = "Rank 5", [143] = "Rank 2" }
local savedNames = {}
for id, name in pairs(names) do savedNames[id] = WoW.spellNames[id]; WoW.spellNames[id] = name end
local getSubtext = GetSpellSubtext
GetSpellSubtext = function(id) return ranks[id] end
local bars = { [1] = 8406, [2] = 116, [13] = 8406, [5] = 143 }
local cursor
GetActionInfo = function(slot) if bars[slot] then return "spell", bars[slot] end end
GetCursorInfo = function() return cursor and "spell" or nil end
PickupSpell = function(id) cursor = id end
PlaceAction = function(slot) bars[slot], cursor = cursor, bars[slot] end
ClearCursor = function() cursor = nil end

WoW.ClearChat()
WoW.FireEvent("LEARNED_SPELL_IN_TAB", 8407)
check("learned Frostbolt Rank 5: on the buttons of Rank 4", bars[1] == 8407 and bars[13] == 8407)
check("... Rank 1 on its own button, and other spells, stay", bars[2] == 116 and bars[5] == 143 and cursor == nil)
check("... and chat says so", WoW.ChatContains("Frostbolt (Rank 5) is on your action bars now, in place of Rank 4."))

-- In combat: after it.
bars[1], bars[13] = 8406, 8406
S.inCombat = true
WoW.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 8407)
check("in combat: not yet", bars[1] == 8406)
S.inCombat = false
WoW.FireEvent("PLAYER_REGEN_ENABLED")
check("... after the fight", bars[1] == 8407 and bars[13] == 8407)

-- Something on the cursor: once it's empty.
bars[1] = 8406
cursor = 999
WoW.FireEvent("LEARNED_SPELL_IN_TAB", 8407)
check("something on the cursor: left alone", bars[1] == 8406 and cursor == 999)
cursor = nil
WoW.RunTimers()
check("... done once the cursor is empty", bars[1] == 8407)

-- Switched off.
bars[1] = 8406
Pathwise.db.actionBarRanks = false
WoW.FireEvent("LEARNED_SPELL_IN_TAB", 8407)
check("switched off on the Features page: nothing", bars[1] == 8406)
Pathwise.db.actionBarRanks = true

-- Clean up
GetSpellSubtext = getSubtext
GetActionInfo, GetCursorInfo, PickupSpell, PlaceAction, ClearCursor = nil, nil, nil, nil, nil
for id in pairs(names) do WoW.spellNames[id] = savedNames[id] end
