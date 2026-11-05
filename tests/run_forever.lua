-- WoW Forever: Pathwise_Forever.toc on the mock client turned into a
-- modern one - the Classic-only functions removed, their C_ replacements
-- added (as in Blizzard's Forever 1.60.1 API documentation). A separate
-- Lua process (tests/run.lua starts it): it needs its own fresh globals.
-- Run alone from the repository root:  lua5.1 tests/run_forever.lua

package.path = "./tests/?.lua;" .. package.path
local WoW = require("mock_wow")
local S = WoW.state
WoW.echo = os.getenv("PATHWISE_ECHO") == "1"

local passed, failed = 0, 0
local function check(description, condition)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: [Forever] " .. description)
  end
end
local function Near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-4 end

---------------------------------------------------------------------------
-- The modern client

function GetBuildInfo() return "1.60.1", "70790", "Nov 1 2026", 16001 end

local classic = {}
for _, name in ipairs({ "GetQuestLogTitle", "GetNumQuestLogEntries", "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard",
  "GetSpellInfo", "GetSpellSubtext", "GetItemInfo", "GetItemCount", "GetItemStats", "GetNumTalentTabs",
  "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo", "UnitCharacterPoints", "GetNumSkillLines", "GetSkillLineInfo",
  "GetPetHappiness", "GetPetFoodTypes", "IsSpellKnown", "IsPlayerSpell", "GetQuestGreenRange", "GetCoinTextureString",
  "IsQuestFlaggedCompleted", "GetContainerNumFreeSlots", "HasPetSpells", "GetSpellBookItemInfo",
  "GetSpellBookItemName", "GetNumCrafts", "GetCraftInfo", "GetCraftDisplaySkillLine", "InterfaceOptions_AddCategory",
  "InterfaceOptionsFrame_OpenToCategory", "GetGossipAvailableQuests", "GetGossipActiveQuests",
  "SelectGossipAvailableQuest", "SelectGossipActiveQuest" }) do
  classic[name] = _G[name]
  _G[name] = nil
end

Enum = { TooltipDataType = { Item = 0, Unit = 2 }, SpellBookSpellBank = { Player = 0, Pet = 1 } }
local completed = {}
local function Entry(questID)
  for _, e in ipairs(WoW.questLog) do
    if e.questID == questID then return e end
  end
end
C_QuestLog = {
  GetNumQuestLogEntries = function() return #WoW.questLog end,
  GetInfo = function(i)
    local e = WoW.questLog[i]
    if not e then return nil end
    return { title = e.title, level = e.level or 0, isHeader = e.header or false, isCollapsed = e.collapsed or false,
      questID = e.questID or 0, suggestedGroup = e.group or 0, isHidden = e.hidden or false }
  end,
  IsComplete = function(questID) local e = Entry(questID) return e and e.complete == 1 or false end,
  IsFailed = function(questID) local e = Entry(questID) return e and e.complete == -1 or false end,
  GetQuestObjectives = function(questID)
    local list = {}
    for i, o in ipairs(Entry(questID) and Entry(questID).objectives or {}) do
      local have, need = o.text:match("(%d+)/(%d+)")
      list[i] = { text = o.text, finished = o.finished or false, numFulfilled = tonumber(have), numRequired = tonumber(need) }
    end
    return list
  end,
  GetTrivialRange = function() return 7 end,
  IsQuestFlaggedCompleted = function(questID) return completed[questID] == true end,
}
C_Item = { GetItemInfo = classic.GetItemInfo, GetItemCount = classic.GetItemCount, GetItemStats = classic.GetItemStats }
C_Spell = {
  GetSpellName = function(id) return (classic.GetSpellInfo(id)) end,
  GetSpellInfo = function(id)
    local name, _, icon = classic.GetSpellInfo(id)
    return name and { name = name, iconID = icon } or nil
  end,
  GetSpellSubtext = function() return "" end,
}
local petBook = {}
C_SpellBook = {
  IsSpellKnown = function(id) return classic.IsSpellKnown(id) end,
  IsSpellInSpellBook = function() return false end,
  HasPetSpells = function() return #petBook > 0 and #petBook or nil, "PET" end,
  GetSpellBookItemInfo = function(i, bank) return bank == Enum.SpellBookSpellBank.Pet and petBook[i] or nil end,
}
C_SkillInfo = {
  GetNumSkillLines = function() return #S.skills end,
  GetSkillLineInfo = function(i)
    local name, isHeader, isExpanded, rank, _, modifier, maxRank, isAbandonable = classic.GetSkillLineInfo(i)
    return { name = name, isHeader = isHeader, isCollapsed = not isExpanded, rank = rank, modifier = modifier,
      maxRank = maxRank, isAbandonable = isAbandonable }
  end,
}
C_PetInfo = {
  GetPetHappiness = function() return S.pet and S.pet.happiness, 100, 0 end,
  GetPetFoodTypes = function() return S.pet and S.pet.foods or {} end,
}
C_CurrencyInfo = { GetCoinTextureString = function(copper) return "coins:" .. copper end }
C_Container = { GetContainerNumFreeSlots = function() return 8, 0 end }
C_GossipInfo = {
  GetAvailableQuests = function() return {} end, GetActiveQuests = function() return {} end,
  SelectAvailableQuest = function() end, SelectActiveQuest = function() end,
}
local tooltipPosts = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) tooltipPosts[kind] = fn end }
-- Modern tooltips have no OnTooltipSetItem/OnTooltipSetUnit: hooking them is an error.
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
  local hook = tooltip.HookScript
  tooltip.HookScript = function(self, script, fn)
    if script == "OnTooltipSetItem" or script == "OnTooltipSetUnit" then
      error(self:GetName() .. " doesn't have a \"" .. script .. "\" script")
    end
    return hook(self, script, fn)
  end
end
-- Secret values (combat): a marker the mock's issecretvalue recognizes.
local SECRET = setmetatable({}, { __eq = function() error("attempt to compare a secret value") end })
function issecretvalue(value) return value == nil and false or rawequal(value, SECRET) end
-- The spellbook is the modern PlayerSpellsFrame: no SpellBookFrame (the
-- Training panel switches itself off).
SpellBookFrame = nil
Settings = {
  RegisterCanvasLayoutCategory = function(panel, name) return { GetID = function() return name end } end,
  RegisterCanvasLayoutSubcategory = function(_, panel, name) return { GetID = function() return name end } end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function() end,
}

---------------------------------------------------------------------------
-- Loading and login

local Pathwise = WoW.LoadAddon("./Pathwise_Forever.toc", "Pathwise")
WoW.FireEvent("ADDON_LOADED", "Pathwise")
WoW.FireEvent("PLAYER_LOGIN")
WoW.FireEvent("PLAYER_ENTERING_WORLD", true, false)
WoW.RunTimers()
local Platform = Pathwise.Platform
check("Platform_Forever is loaded", Platform.flavor == "Forever")
check("logged in", WoW.ChatContains("loaded"))
check("item tooltips through TooltipDataProcessor, no OnTooltipSetItem hook",
  Pathwise:GetModule("Tooltip").hookMethod == "TooltipDataProcessor" and tooltipPosts[Enum.TooltipDataType.Item] ~= nil)

---------------------------------------------------------------------------
-- Quest log (C_QuestLog)

WoW.questLog = {
  { header = true, title = "Teldrassil" },
  { title = "Webwood Venom", level = 4, questID = 916, objectives = { { text = "Webwood Venom Sac: 6/10" } } },
  { title = "The Balance of Nature", level = 5, questID = 456, complete = 1,
    objectives = { { text = "Nightsaber slain: 7/7", finished = true } } },
  { title = "A Hidden Task", level = 5, questID = 99001, hidden = true },
  { header = true, title = "Darkshore", collapsed = true },
}
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
local quests, collapsed = Platform.GetQuestLog()
check("quests read from C_QuestLog.GetInfo", #quests == 2 and quests[1].title == "Webwood Venom"
  and quests[1].zone == "Teldrassil" and quests[1].questID == 916)
check("objectives with their counts", quests[1].objectives[1].have == 6 and quests[1].objectives[1].need == 10
  and not quests[1].objectives[1].finished)
check("complete from C_QuestLog.IsComplete", quests[2].complete == true and quests[1].complete == false)
check("hidden entries (tasks) left out, collapsed headers listed", collapsed[1] == "Darkshore")
local texts = {}
for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
  texts[#texts + 1] = (item.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
check("the guide shows them (" .. table.concat(texts, " / ") .. ")",
  table.concat(texts, "|"):find("Turn in: [5] The Balance of Nature", 1, true) ~= nil
  and table.concat(texts, "|"):find("Webwood Venom", 1, true) ~= nil)
check("green range from C_QuestLog.GetTrivialRange", Platform.GetQuestGreenRange(10) == 7)
completed[456] = true
check("completed quests from C_QuestLog", Platform.IsQuestCompleted(456) and not Platform.IsQuestCompleted(916))

---------------------------------------------------------------------------
-- Skills, spells, items, money

local skills = Platform.GetSkills()
check("skills from C_SkillInfo", #skills > 0 and skills[1].name ~= nil and skills[1].header ~= nil)
local someSpell, someName
for id, name in pairs(WoW.spellNames) do someSpell, someName = id, name break end
check("spell names from C_Spell", Platform.GetSpellName(someSpell) == someName
  and select(1, Platform.GetSpellDisplay(someSpell)) == someName and select(2, Platform.GetSpellDisplay(someSpell)) == nil)
WoW.knownSpells[someSpell] = true
check("known spells from C_SpellBook", Platform.IsSpellKnown(someSpell))
WoW.knownSpells[someSpell] = nil
check("unknown spells", not Platform.IsSpellKnown(someSpell))
local anyItem
for id in pairs(WoW.items) do anyItem = id break end
check("item info from C_Item", Platform.GetItemInfo(anyItem) ~= nil and Platform.GetItemInfo(anyItem).name == WoW.items[anyItem].name)
check("coin text from C_CurrencyInfo", Platform.CoinText(12345) == "coins:12345")
check("free bag slots from C_Container", Platform.GetFreeBagSlots() == 40)

---------------------------------------------------------------------------
-- Talents before the trait API is there; no Beast Training window

S.level = 20
WoW.FireEvent("PLAYER_LEVEL_UP", 20)
WoW.RunTimers()
local talentSteps = 0
for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
  if item.id:find("talent") then talentSteps = talentSteps + 1 end
end
check("no trait talent API: no talent trees and no unspent points, no talent steps", #Platform.GetTalentTrees() == 0
  and Platform.GetUnspentTalentPoints() == 0 and talentSteps == 0)
check("no Beast Training window", Platform.GetBeastTraining() == nil)

---------------------------------------------------------------------------
-- Hunter pet (C_PetInfo, the pet spellbook)

S.pet = { name = "Kitty", happiness = 3, foods = { "Meat", "Fish" } }
petBook = { { spellID = 17253, name = "Bite", subName = "Rank 2" } }
local pet = Platform.GetHunterPet()
check("pet happiness and diet from C_PetInfo", pet and pet.happiness == 3 and pet.foodTypes[2] == "Fish")
local petSpells = Platform.GetPetSpells()
check("pet spells from the pet spellbook", petSpells[1] and petSpells[1].spellID == 17253 and petSpells[1].rank == 2)
S.pet, petBook = nil, {}

---------------------------------------------------------------------------
-- Map frames: four zones differ from Classic Era

-- Caledra Dawnbreeze, Stormwind: (75.42, 28.42) on Classic Era, (78.03, 46.43) on Forever (QuestieDB).
local x, y = Platform.MapPoint(1453, 0.7542, 0.2842)
check("Stormwind point converted (" .. tostring(x) .. ", " .. tostring(y) .. ")", Near(x, 0.7803) and Near(y, 0.4643))
x, y = Platform.MapPoint(1438, 0.5, 0.25)
check("other zones unchanged", x == 0.5 and y == 0.25)
local strat
for _, dungeon in ipairs(Pathwise.Data.Dungeons) do
  if dungeon.name == "Stratholme" then strat = dungeon end
end
WoW.mapRects[1423] = { continent = 0, top = 4000, left = 4000, bottom = 1000, right = 1000 }
LibQuestieDB = nil
local QuestieData = Pathwise:GetModule("QuestieData")
local areaToUiMap = QuestieData.AreaToUiMap
QuestieData.AreaToUiMap = function(_, area) return area == 139 and 1423 or nil end
local entrance = strat and Pathwise:GetModule("DungeonGuide"):EntranceTarget(strat)
-- (Either of its two entrances, converted.)
check("Stratholme's entrance on Forever's Eastern Plaguelands map", entrance and entrance.mapID == 1423
  and (Near(entrance.x, 0.313 * 0.8997577709204458 - 0.016464926382438023)
    or Near(entrance.x, 0.479 * 0.8997577709204458 - 0.016464926382438023)))
QuestieData.AreaToUiMap = areaToUiMap

---------------------------------------------------------------------------
-- Secret values in combat

local originalUnitName = UnitName
UnitName = function(unit) if unit == "target" then return SECRET end return originalUnitName(unit) end
S.targetName = "Something"
check("a secret target name reads as unknown", Platform.GetTargetNPCName() == nil)
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
UnitName, S.targetName = originalUnitName, nil

-- Tooltips in combat: a secret line (text can't be searched) or unit.
GameTooltip:ClearLines()
GameTooltip._link = WoW.ItemLink(anyItem)
GameTooltip:AddLine("Some Item")
GameTooltip:AddLine(SECRET)
local ok, err = pcall(tooltipPosts[Enum.TooltipDataType.Item], GameTooltip)
check("item tooltip with a secret line: no error (" .. tostring(err) .. ")", ok)
GameTooltip:ClearLines()
GameTooltip.GetUnit = function() return SECRET, SECRET end
ok, err = pcall(tooltipPosts[Enum.TooltipDataType.Unit], GameTooltip)
check("unit tooltip with a secret unit: no error, no line (" .. tostring(err) .. ")", ok and GameTooltip:NumLines() == 0)
GameTooltip.GetUnit = nil

-- The target macro: Forever blocks an addon's Lua (/run) from setting raid
-- markers, and with it the whole macro; the skull goes through /tm.
local macroBody = Pathwise:GetModule("TargetMacro").BuildBody({ "Webwood Spider" })
check("target macro: skull with /tm, no /run", not macroBody:find("/run", 1, true)
  and macroBody:find("/tm [harm,nodead] !8", 1, true) ~= nil)

---------------------------------------------------------------------------
-- The Training panel on Forever's spellbook (PlayerSpellsFrame, loaded the
-- first time it's opened)

check("no Training tab before the spellbook is loaded", _G.PathwiseSpellBookTab == nil)
PlayerSpellsFrame = CreateFrame("Frame", "PlayerSpellsFrame", UIParent)
PlayerSpellsFrame:Hide()
WoW.FireEvent("ADDON_LOADED", "Blizzard_PlayerSpells")
local trainingTab, trainingPanel = _G.PathwiseSpellBookTab, _G.PathwiseTrainingPanel
check("loaded: the Training tab and panel are on PlayerSpellsFrame", trainingTab ~= nil and trainingPanel ~= nil
  and trainingTab:GetParent() == PlayerSpellsFrame and trainingPanel:GetParent() == PlayerSpellsFrame)
Pathwise.db.trainerPanel = true
PlayerSpellsFrame:Show()
WoW.RunTimers()
check("opening the spellbook shows the panel, at its right edge", trainingPanel:IsShown()
  and select(2, trainingPanel:GetPoint(1)) == PlayerSpellsFrame)
trainingTab:Click()
check("the tab closes it", not trainingPanel:IsShown() and Pathwise.db.trainerPanel == false)
trainingTab:Click()
check("and opens it again", trainingPanel:IsShown())
PlayerSpellsFrame:Hide()

---------------------------------------------------------------------------
-- Talents: a trait tree (C_ClassTalents, C_Traits), one node group per
-- talent tree. Rows and columns aren't Classic's: builds go by name.

-- nodes: { [nodeID] = { group, x, y, name, rank, max, staged, available } }
local traitNodes, unspentTalents = {}, 2
local function TraitTree(spec)
  traitNodes = {}
  for i, n in ipairs(spec) do
    traitNodes[1000 + i] = { group = n[1], x = n[2], y = n[3], name = n[4], rank = n[5] or 0, max = n[6] or 5,
      staged = n[7], available = n[8] ~= false }
  end
end
C_ClassTalents = {
  GetActiveConfigID = function() return 77 end,
  HasUnspentTalentPoints = function() return unspentTalents > 0, unspentTalents, 0 end,
}
C_Traits = {
  GetConfigInfo = function(configID) return configID == 77 and { ID = 77, treeIDs = { 900 } } or nil end,
  -- (Out of window order on purpose: orderIndex sorts them.)
  GetGroupDisplayInfoByTreeID = function()
    return { { groupID = 12, orderIndex = 2, displayName = "Marksmanship" },
      { groupID = 11, orderIndex = 1, displayName = "Beast Mastery" },
      { groupID = 13, orderIndex = 3, displayName = "Survival" } }
  end,
  GetTreeNodes = function()
    local ids = {}
    for id in pairs(traitNodes) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
  end,
  GetNodeInfo = function(_, nodeID)
    local n = traitNodes[nodeID]
    return { ID = nodeID, posX = n.x, posY = n.y, groupIDs = { 5, n.group }, entryIDs = { nodeID * 10 },
      activeRank = n.rank, ranksPurchased = n.rank, currentRank = n.rank + (n.staged or 0), maxRanks = n.max,
      isVisible = true, isAvailable = true, meetsEdgeRequirements = true,
      canPurchaseRank = n.available and n.rank < n.max }
  end,
  GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1 } end,
  GetDefinitionInfo = function(definitionID)
    return { overrideName = traitNodes[(definitionID - 1) / 10].name }
  end,
  GetTreeCurrencyInfo = function(_, _, excludeStaged)
    return { { traitCurrencyID = 1, quantity = unspentTalents, spent = 0 } }
  end,
}

-- Forever's own layout: in row 1, Endurance Training sits where Classic
-- has Improved Aspect of the Hawk; Thick Hide moved to Marksmanship.
TraitTree({
  { 11, 600, 100, "Endurance Training" }, { 11, 1200, 100, "Improved Aspect of the Hawk", 2, 5, 1 },
  { 11, 300, 100, "Improved Revive Pet", 0, 2 },
  { 11, 600, 400, "Bestial Swiftness", 0, 1, nil, false }, { 11, 1200, 400, "Unleashed Fury", 0, 5, nil, false },
  { 11, 900, 700, "Ferocity", 0, 5, nil, false }, { 11, 900, 1000, "Intimidation", 0, 1, nil, false },
  { 11, 900, 1300, "Bestial Wrath", 0, 1, nil, false },
  { 12, 600, 100, "Efficiency" }, { 12, 900, 100, "Lethal Shots" }, { 12, 300, 100, "Improved Concussive Shot" },
  { 12, 600, 400, "Thick Hide", 0, 3, nil, false },
  { 13, 600, 100, "Monster Slaying" }, { 13, 900, 100, "Humanoid Slaying" },
})
WoW.FireEvent("TRAIT_CONFIG_UPDATED", 77)
WoW.RunTimers()
local trees = Platform.GetTalentTrees()
local hawk, thickHide
for _, tree in ipairs(trees) do
  for _, talent in ipairs(tree.talents) do
    if talent.name == "Improved Aspect of the Hawk" then hawk = talent end
    if talent.name == "Thick Hide" then thickHide = talent end
  end
end
check("talent trees in the window's order", #trees == 3 and trees[1].name == "Beast Mastery"
  and trees[2].name == "Marksmanship" and trees[3].name == "Survival")
check("a talent's row and column within its tree, its applied rank (not the clicked one)", hawk and hawk.tier == 1
  and hawk.column == 4 and hawk.rank == 2 and hawk.maxRank == 5 and hawk.tab == 1 and trees[1].points == 2)
check("rows from the node height", thickHide and thickHide.tier == 2 and thickHide.tab == 2 and not thickHide.available)
check("unspent points from the tree currency", Platform.GetUnspentTalentPoints() == 2)

local Talents = Pathwise:GetModule("Talents")
local function TalentItems()
  local found = {}
  for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
    if item.id:find("talent") then found[#found + 1] = item end
  end
  return found
end
local items = TalentItems()
check("the build's next talent, found by name: " .. tostring(items[1] and items[1].text),
  #items == 1 and items[1].text:find("Improved Aspect of the Hawk (3/5)", 1, true) ~= nil)
local upcoming = Talents:GetUpcoming(5)
local upcomingNames = {}
for i, point in ipairs(upcoming) do upcomingNames[i] = point.name end
check("talents the game doesn't have are left out, ones it won't take yet come last: "
  .. table.concat(upcomingNames, ", "), upcoming[3] and upcoming[3].name == "Improved Aspect of the Hawk"
  and upcoming[4] and upcoming[4].name == "Endurance Training" and upcoming[4].open
  and not table.concat(upcomingNames, ","):find("Spirit Bond", 1, true))
local nextPoint = Talents:GetNextPoint()
check("next point: its trait node", nextPoint and nextPoint.nodeID == 1002 and nextPoint.tab == 1
  and nextPoint.rank == 3)

-- The talent window: Forever's PlayerSpellsFrame.TalentsFrame, a button per node.
local talentButtons = {}
PlayerSpellsFrame.TalentsFrame = CreateFrame("Frame", nil, PlayerSpellsFrame)
function PlayerSpellsFrame.TalentsFrame:GetTalentButtonByNodeID(nodeID)
  talentButtons[nodeID] = talentButtons[nodeID] or CreateFrame("Button", nil, self)
  return talentButtons[nodeID]
end
local createFrame, glows = CreateFrame, {}
CreateFrame = function(kind, name, parent, ...)
  local frame = createFrame(kind, name, parent, ...)
  if parent == PlayerSpellsFrame.TalentsFrame and kind == "Frame" then glows[#glows + 1] = frame end
  return frame
end
WoW.FireEvent("ADDON_LOADED", "Blizzard_PlayerSpells")
CreateFrame = createFrame
PlayerSpellsFrame:Show()
PlayerSpellsFrame.TalentsFrame:Show()
Pathwise:GetModule("TalentHighlight"):Update()
local glowOn
for _, glow in ipairs(glows) do
  if glow:IsShown() then glowOn = glow:GetParent() end
end
check("the talent window glows on the next talent's button", glowOn ~= nil and glowOn == talentButtons[1002])
PlayerSpellsFrame:Hide()

-- A tree too different from the build (or names in another language):
-- just the reminder, and no "unlearn" advice.
TraitTree({ { 11, 600, 100, "Verbesserter Aspekt des Falken" }, { 11, 900, 100, "Ausdauertraining", 3, 5 },
  { 12, 600, 100, "Effizienz", 4, 5 }, { 13, 600, 100, "Monstertöten", 5, 5 } })
WoW.FireEvent("TRAIT_CONFIG_UPDATED", 77)
WoW.RunTimers()
items = TalentItems()
check("a build that doesn't fit: \"Spend 2 talent points\", and why", #items == 1
  and items[1].text == "Spend 2 talent points" and items[1].detail[1]:find("don't match", 1, true) ~= nil)
check("a build that doesn't fit: no next point to glow", Talents:GetNextPoint() == nil)
unspentTalents = 0
WoW.FireEvent("TRAIT_CONFIG_UPDATED", 77)
check("all points spent: no talent step", #TalentItems() == 0)
C_ClassTalents, C_Traits, traitNodes = nil, nil, {}
WoW.FireEvent("TRAIT_CONFIG_UPDATED", 77)

---------------------------------------------------------------------------
-- Ammo: Forever can do without

local ammoNeeded = false
C_PaperDollInfo = { AmmoNeeded = function() return ammoNeeded end }
S.inventory[18] = { id = 2504, name = "Worn Shortbow" }
S.inventory[0] = nil
WoW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 18)
WoW.RunTimers()
local function HasAmmoStep()
  WoW.FireEvent("BAG_UPDATE_DELAYED")
  WoW.RunTimers()
  for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
    if item.id == "ammo" then return true end
  end
  return false
end
check("no ammo needed: no ammo warning for a hunter with a bow", not Platform.AmmoNeeded() and not HasAmmoStep())
ammoNeeded = true
check("ammo needed: the warning as on Classic Era", Platform.AmmoNeeded() and HasAmmoStep())
S.inventory[18] = nil

-- No ranged slot (like the modern game): ranged weapons go in the main hand.
local rangedShown = true
C_PaperDollInfo.IsRangedSlotShown = function() return rangedShown end
local bow = Platform.GetItemInfo(2504)
check("with a ranged slot: a bow goes there", bow.slots[1] == 18 and #bow.slots == 1)
rangedShown = false
bow = Platform.GetItemInfo(2504)
check("without one: main hand, two-handed", bow.slots[1] == Platform.SLOT_MAINHAND and #bow.slots == 1 and bow.isTwoHand
  and bow.isRanged)
local notRanged
for id, data in pairs(WoW.items) do
  if data.equipLoc == "INVTYPE_HEAD" then notRanged = id break end
end
check("other items unchanged", Platform.GetItemInfo(notRanged).slots[1] == 1)
rangedShown = true

---------------------------------------------------------------------------

-- Item tooltips: Forever shows the sell price itself.
local sellItem
for id, data in pairs(WoW.items) do
  if (data.sell or 1) > 0 and data.equipLoc == "INVTYPE_HEAD" then sellItem = id break end
end
local function Hover()
  GameTooltip:ClearLines()
  GameTooltip._link = WoW.ItemLink(sellItem)
  GameTooltip:AddLine(WoW.items[sellItem].name)
  tooltipPosts[Enum.TooltipDataType.Item](GameTooltip)
  return table.concat(WoW.TooltipLines(GameTooltip), "|")
end
local lines = Hover()
check("no second sell price line (" .. lines .. ")", not lines:find("Sell price", 1, true))

-- A failing tooltip line stops after 3 errors (the tooltip refreshes 5
-- times a second), with one chat line; the errors go to /pw bug.
local GearScore = Pathwise:GetModule("GearScore")
local compare = GearScore.Compare
GearScore.Compare = function() error("compare broke") end
local errorsBefore = #WoW.errors
WoW.ClearChat()
for _ = 1, 10 do Hover() end
check("errors stop after 3 (" .. (#WoW.errors - errorsBefore) .. ")", #WoW.errors == errorsBefore + 3)
check("one chat line says so", WoW.ChatContains("Pathwise's item tooltip line hit an error and is off until you /reload"))
local recent = Platform.GetRecentErrors()
check("the error is kept for /pw bug", recent[#recent].message:find("compare broke", 1, true) ~= nil)
for _ = 1, 3 do table.remove(WoW.errors) end
GearScore.Compare = compare

WoW.Slash("bug")
local bugReport = Pathwise:GetModule("BugReportFrame"):GetReportText()
check("/pw bug: the report says Forever", bugReport:find("on Forever\n", 1, true) ~= nil
  and bugReport:find("interface 16001", 1, true) ~= nil)
_G.PathwiseBugReport:Hide()

check("no errors (" .. tostring(WoW.errors[1]) .. ")", #WoW.errors == 0)
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
