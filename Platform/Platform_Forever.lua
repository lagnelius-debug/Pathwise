local addonName, Pathwise = ...

-- Platform layer for WoW Forever (1.60, interface 16xxx): Classic Era's
-- world and quests on the modern (retail) client, so part of the game's API
-- moved to C_ namespaces or works differently. Loaded right after
-- Platform_Classic.lua by every TOC, it does nothing outside WoW Forever;
-- there it replaces just the functions that differ, everything else is
-- Platform_Classic.lua's.
--
-- Checked against Blizzard's Forever UI source and API documentation,
-- 1.60.1 (70790). Where an API might be missing, check at runtime.

local interface = select(4, GetBuildInfo())
if not interface or interface < 16000 or interface >= 17000 then
  return
end

local Platform = Pathwise.Platform

Platform.flavor = "Forever"

---------------------------------------------------------------------------
-- Talents and Beast Training
---------------------------------------------------------------------------

-- Forever's talents are a trait tree (C_Traits) with one group of nodes
-- per talent tree (Beast Mastery, Marksmanship, Survival), as the Camelot
-- ClassTalentsFrame shows them. Rows and columns aren't Classic's, so
-- Pathwise's builds find their talents by name here (TalentsMatchByName).

-- The player's talent config and its tree, as the talent window picks them.
local function TalentConfig()
  if not (C_Traits and C_Traits.GetConfigInfo) then
    return nil
  end
  local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
  if not configID and C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup then
    local group = C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup() or 1
    configID = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
  end
  local info = configID and C_Traits.GetConfigInfo(configID)
  local treeID = info and info.treeIDs and info.treeIDs[1]
  if treeID then
    return configID, treeID
  end
end

-- A node's talent name: its spell's, or the definition's own.
local function NodeName(configID, node)
  local entryID = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
  local entry = entryID and C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entryID)
  local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo
    and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not definition then
    return nil
  end
  if definition.overrideName and definition.overrideName ~= "" then
    return definition.overrideName
  end
  return definition.spellID and Platform.GetSpellName(definition.spellID)
end

local GRID_ROUNDING = 50

-- Numbers each distinct value 1, 2, ... in ascending order.
local function Ranks(values)
  local sorted, seen = {}, {}
  for _, value in ipairs(values) do
    if not seen[value] then
      seen[value] = true
      sorted[#sorted + 1] = value
    end
  end
  table.sort(sorted)
  local rank = {}
  for i, value in ipairs(sorted) do
    rank[value] = i
  end
  return rank
end

-- Same shape as Platform_Classic's: trees in the window's order, each
-- talent with its row (tier) and column within its tree, the committed
-- rank (not what's only clicked and not applied yet), its node and whether
-- the game lets it take a point now (available: with points to spend, the
-- game's own check; without, whether its row and the talents before it are
-- open).
function Platform.GetTalentTrees()
  local trees = {}
  local configID, treeID = TalentConfig()
  if not configID or not (C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then
    return trees
  end
  local hasPoints = Platform.GetUnspentTalentPoints() > 0
  local groups = {}
  for _, display in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
    groups[#groups + 1] = display
  end
  table.sort(groups, function(a, b)
    return (a.orderIndex or 0) < (b.orderIndex or 0)
  end)
  local treeOfGroup = {}
  for i, display in ipairs(groups) do
    trees[i] = { index = i, name = display.displayName, points = 0, talents = {} }
    treeOfGroup[display.groupID] = trees[i]
  end
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
    local node = C_Traits.GetNodeInfo(configID, nodeID)
    local tree
    for _, groupID in ipairs(node and node.groupIDs or {}) do
      tree = tree or treeOfGroup[groupID]
    end
    local name = tree and node.isVisible ~= false and NodeName(configID, node)
    if name then
      local rank = node.activeRank or node.ranksPurchased or 0
      local available
      if hasPoints and node.canPurchaseRank ~= nil then
        available = node.canPurchaseRank
      else
        available = node.isAvailable ~= false and node.meetsEdgeRequirements ~= false
      end
      tree.talents[#tree.talents + 1] = {
        index = #tree.talents + 1,
        name = name,
        -- (Rounded: nodes of one row or column can be a few units apart.)
        posX = math.floor((node.posX or 0) / GRID_ROUNDING + 0.5),
        posY = math.floor((node.posY or 0) / GRID_ROUNDING + 0.5),
        rank = rank,
        maxRank = node.maxRanks or 0,
        nodeID = nodeID,
        tab = tree.index,
        available = available and true or false,
      }
      tree.points = tree.points + rank
    end
  end
  for _, tree in ipairs(trees) do
    local xs, ys = {}, {}
    for _, talent in ipairs(tree.talents) do
      xs[#xs + 1], ys[#ys + 1] = talent.posX, talent.posY
    end
    local column, tier = Ranks(xs), Ranks(ys)
    for _, talent in ipairs(tree.talents) do
      talent.column, talent.tier = column[talent.posX], tier[talent.posY]
    end
  end
  return trees
end

-- The "Unspent Talents" number of the talent window (applied changes only).
function Platform.GetUnspentTalentPoints()
  local configID, treeID = TalentConfig()
  if configID and C_Traits.GetTreeCurrencyInfo then
    local currency = (C_Traits.GetTreeCurrencyInfo(configID, treeID, true) or {})[1]
    if currency and type(currency.quantity) == "number" then
      return currency.quantity
    end
  end
  if C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints then
    local _, classPoints, specPoints = C_ClassTalents.HasUnspentTalentPoints()
    return (classPoints or 0) + (specPoints or 0)
  end
  return 0
end

-- Builds find talents by name: Forever's rows and columns are its own.
function Platform.TalentsMatchByName()
  return true
end

-- Beast Training is the trainer window in pet mode (C_Trainer's trainer
-- type Pet, training points instead of money), not Classic's craft window:
-- the abilities the hunter has learned - ones the pet can learn now, can't
-- yet (its level) or already has.
Platform.BEAST_TRAINING_EVENTS = { "TRAINER_SHOW", "TRAINER_UPDATE" }

function Platform.GetBeastTraining()
  if not (C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and GetNumTrainerServices
    and GetTrainerServiceInfo) or C_Trainer.GetTrainerType() ~= Enum.TrainerType.Pet then
    return nil
  end
  local list = {}
  for i = 1, GetNumTrainerServices() or 0 do
    local name, serviceType, _, level, subText = GetTrainerServiceInfo(i)
    if name and serviceType ~= "header" then
      list[#list + 1] = {
        name = name,
        rank = tonumber((subText or ""):match("(%d+)")),
        level = level,
        cost = GetTrainerServiceCost and GetTrainerServiceCost(i),
      }
    end
  end
  return list
end

---------------------------------------------------------------------------
-- Skills (C_SkillInfo)
---------------------------------------------------------------------------

function Platform.GetSkills()
  local skills, collapsedHeaders = {}, {}
  if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo) then
    return skills, collapsedHeaders
  end
  local header
  for i = 1, C_SkillInfo.GetNumSkillLines() do
    local line = C_SkillInfo.GetSkillLineInfo(i)
    if line and line.isHeader then
      header = line.name
      if line.isCollapsed then
        collapsedHeaders[#collapsedHeaders + 1] = line.name
      end
    elseif line and line.name then
      skills[#skills + 1] = {
        name = line.name,
        rank = line.rank or 0,
        maxRank = line.maxRank or 0,
        modifier = line.modifier or 0,
        header = header,
        isAbandonable = line.isAbandonable and true or false,
      }
    end
  end
  return skills, collapsedHeaders
end

---------------------------------------------------------------------------
-- Spells (C_Spell, C_SpellBook)
---------------------------------------------------------------------------

-- C_SpellBook.IsSpellKnown is the old IsPlayerSpell (talent-granted spells
-- too), IsSpellInSpellBook the old IsSpellKnown; either counts.
function Platform.IsSpellKnown(spellID)
  if C_SpellBook then
    if C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
      return true
    end
    if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID) then
      return true
    end
  end
  return false
end

function Platform.GetSpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(spellID)
  end
end

function Platform.GetSpellDisplay(spellID)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
  if not info or not info.name then
    return nil
  end
  local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
  if subtext == "" then
    subtext = nil
  end
  return info.name, subtext, info.iconID
end

---------------------------------------------------------------------------
-- Quest log (C_QuestLog)
---------------------------------------------------------------------------

local function ParseProgress(text)
  local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
  return tonumber(have), tonumber(need)
end

-- The modern client puts the count first ("0/1 Rabid Thistle Bear
-- captured"); Classic's way, which the rest of Pathwise reads, puts it last
-- ("Rabid Thistle Bear captured: 0/1").
function Platform.ClassicObjectiveText(text)
  if type(text) ~= "string" then
    return text
  end
  local have, need, rest = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.-)%s*$")
  if have and rest ~= "" then
    return rest .. ": " .. have .. "/" .. need
  end
  return text
end

local function GetObjectives(questID)
  local objectives = {}
  for i, objective in ipairs(C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}) do
    local have, need = objective.numFulfilled, objective.numRequired
    if not have then
      have, need = ParseProgress(objective.text)
    end
    objectives[i] = { text = Platform.ClassicObjectiveText(objective.text), type = objective.type,
      finished = objective.finished and true or false, have = have, need = need }
  end
  return objectives
end

-- Same result as Platform_Classic's GetQuestLog, from C_QuestLog.GetInfo
-- records. The modern log also holds hidden entries (tasks, bonus
-- objectives): left out.
function Platform.GetQuestLog()
  local quests, collapsedHeaders = {}, {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
    return quests, collapsedHeaders
  end
  local zone
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and info.isHeader then
      zone = info.title
      if info.isCollapsed then
        collapsedHeaders[#collapsedHeaders + 1] = info.title
      end
    elseif info and info.title and not info.isHidden then
      local questID = info.questID
      quests[#quests + 1] = {
        logIndex = i,
        questID = questID,
        title = info.title,
        level = info.level or 0,
        zone = zone,
        suggestedGroup = tonumber(info.suggestedGroup) or 0,
        complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) and true or false,
        failed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(questID) and true or false,
        objectives = GetObjectives(questID),
      }
    end
  end
  return quests, collapsedHeaders
end

-- GetQuestGreenRange became C_QuestLog.GetTrivialRange (same meaning: a
-- quest this many levels below the player is still green).
local classicGreenRange = Platform.GetQuestGreenRange
function Platform.GetQuestGreenRange(playerLevel)
  if C_QuestLog and C_QuestLog.GetTrivialRange then
    local range = C_QuestLog.GetTrivialRange()
    if type(range) == "number" then
      return range
    end
  end
  return classicGreenRange(playerLevel)
end

---------------------------------------------------------------------------
-- Items: tooltips and the ranged slot
---------------------------------------------------------------------------

-- Forever's item tooltips show "Sell Price" themselves.
function Platform.TooltipsShowSellPrice()
  return true
end

---------------------------------------------------------------------------
-- Items: the ranged slot
---------------------------------------------------------------------------

-- Forever's character sheet can do without a ranged slot (like the modern
-- game): then bows, guns, crossbows, wands and thrown weapons go in the main
-- hand, two-handed, and are compared with what's there.
local RANGED_EQUIP_LOCS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local classicGetItemInfo = Platform.GetItemInfo
function Platform.GetItemInfo(item)
  local info = classicGetItemInfo(item)
  if info and RANGED_EQUIP_LOCS[info.equipLoc] and C_PaperDollInfo and C_PaperDollInfo.IsRangedSlotShown
    and C_PaperDollInfo.IsRangedSlotShown() == false then
    info.slots = { Platform.SLOT_MAINHAND }
    info.isTwoHand = true
  end
  return info
end

---------------------------------------------------------------------------
-- Hunter: ammo and pet (C_PaperDollInfo, C_PetInfo, the pet spellbook)
---------------------------------------------------------------------------

-- Forever's character sheet hides the ammo slot when the game says no ammo
-- is needed; then there's nothing to warn about.
function Platform.AmmoNeeded()
  if C_PaperDollInfo and C_PaperDollInfo.AmmoNeeded then
    return C_PaperDollInfo.AmmoNeeded() ~= false
  end
  return true
end

function Platform.GetHunterPet()
  if not UnitExists("pet") then
    return nil
  end
  if HasPetUI then
    local hasUI, isHunterPet = HasPetUI()
    if not hasUI or not isHunterPet then
      return nil
    end
  end
  local happiness, foodTypes
  if C_PetInfo then
    happiness = C_PetInfo.GetPetHappiness and C_PetInfo.GetPetHappiness()
    foodTypes = C_PetInfo.GetPetFoodTypes and C_PetInfo.GetPetFoodTypes()
  end
  local family, familyID = UnitCreatureFamily and UnitCreatureFamily("pet")
  return {
    name = UnitName("pet"),
    happiness = happiness,
    foodTypes = foodTypes or {},
    level = UnitLevel("pet"),
    family = family,
    familyID = type(familyID) == "number" and familyID or nil,
  }
end

function Platform.GetPetSpells()
  local spells = {}
  if not (C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemInfo) then
    return spells
  end
  local count = C_SpellBook.HasPetSpells()
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
  if not count or count == 0 or not bank then
    return spells
  end
  for i = 1, count do
    local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
    if info and (info.name or info.spellID) then
      spells[#spells + 1] = {
        spellID = info.spellID,
        name = info.name,
        rank = tonumber(info.subName and info.subName:match("(%d+)")),
      }
    end
  end
  return spells
end

---------------------------------------------------------------------------
-- Map frames
---------------------------------------------------------------------------

-- Four zone maps have a different frame on Forever (the world didn't move;
-- the map picture covers a different area). Coordinates written for Classic
-- Era (0-1) convert as x' = x * scaleX + offsetX, from QuestieDB's Forever
-- conversion (data/Forever/conversion.json, offsets in percent).
local MAP_FRAMES = {
  [1412] = { 0.8348002068275978, 7.007453108736848, 0.8349418225477033, 13.15387327724201 }, -- Mulgore
  [1423] = { 0.8997577709204458, -1.6464926382438023, 0.9004358590984077, -3.7790494664060477 }, -- Eastern Plaguelands
  [1433] = { 0.9999996626080551, -5.086374584221827, 1.0, 0.0 }, -- Redridge Mountains
  [1453] = { 0.7736792385183993, 19.680449646264936, 0.773826866980289, 24.433287807510073 }, -- Stormwind City
}

function Platform.MapPoint(mapID, x, y)
  local frame = MAP_FRAMES[mapID]
  if not frame or not x or not y then
    return x, y
  end
  return x * frame[1] + frame[2] / 100, y * frame[3] + frame[4] / 100
end
