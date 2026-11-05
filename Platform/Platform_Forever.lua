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

-- Forever's talents are trait trees (C_Traits), not Classic's talent tabs:
-- Pathwise's talent builds don't apply. No trees and no unspent points:
-- the talent advice stays quiet.
function Platform.GetTalentTrees()
  return {}
end

function Platform.GetUnspentTalentPoints()
  return 0
end

-- There's no Beast Training craft window (the pet ability guide reads it).
function Platform.GetBeastTraining()
  return nil
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

local function GetObjectives(questID)
  local objectives = {}
  for i, objective in ipairs(C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}) do
    local have, need = objective.numFulfilled, objective.numRequired
    if not have then
      have, need = ParseProgress(objective.text)
    end
    objectives[i] = { text = objective.text, finished = objective.finished and true or false, have = have, need = need }
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
