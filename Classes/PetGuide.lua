local addonName, Pathwise = ...

-- Pet ability guide (hunters): which abilities the pet can get better
-- ranks of at its level, and how:
--   - the hunter already knows the rank: teach it in Beast Training;
--   - otherwise: tame a beast that teaches it - the nearest one the hunter
--     is high enough to tame (not rare when possible), with the arrow and
--     the target button on it.
-- The data (ranks, pet levels, families, teaching beasts and where they
-- are) comes from LibTameable-1.0 (Libs/). What the hunter has learned is
-- read from the Beast Training window when it's opened
-- (PathwiseCharDB.beastTraining).

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local PetGuide = Pathwise:NewModule("PetGuide")

-- At most this many pet steps in the To-do window (/pw pet lists all).
PetGuide.MAX_STEPS = 2
-- Teaching beasts listed per rank in /pw pet.
local MAX_LISTED = 3
local UPDATE_DELAY = 0.5
local DISTANCE_CHECK_SECONDS = 10

local updatePending = false

local function Tameable()
  local lib = LibStub and LibStub("LibTameable-1.0", true)
  return lib and lib:HasData() and lib or nil
end

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

-- The pet's family as a LibTameable family ID, or nil.
local function FamilyID(lib, pet)
  if pet.familyID then
    return pet.familyID
  end
  local key = Data.Hunter.PET_FAMILIES[pet.family or ""]
  return key and lib.families[key]
end

-- Spell ID of a rank from its ability name and rank number (Beast Training
-- and older spellbooks only give names), via the client's spell names.
local function RankByName(lib, name, rank)
  for spellID, info in lib:IterateRanks() do
    if info.rank == rank and Platform.GetSpellName(info.ability) == name then
      return spellID
    end
  end
end

-- Pet: [ability] = highest rank it has.
local function PetRanks(lib)
  local have = {}
  for _, spell in ipairs(Platform.GetPetSpells()) do
    local spellID = spell.spellID
    if not (spellID and lib:GetRankInfo(spellID)) and spell.rank then
      spellID = RankByName(lib, spell.name, spell.rank)
    end
    local info = spellID and lib:GetRankInfo(spellID)
    if info and info.rank > (have[info.ability] or 0) then
      have[info.ability] = info.rank
    end
  end
  return have
end

-- Saves what the open Beast Training window shows (learned ranks).
function PetGuide:OnCraftShow()
  local lib = Tameable()
  local list = Platform.GetBeastTraining()
  if not lib or not list then
    return
  end
  local known = {}
  for _, entry in ipairs(list) do
    local spellID = entry.rank and RankByName(lib, entry.name, entry.rank)
    if spellID then
      known[spellID] = true
    end
  end
  Pathwise.charDB.beastTraining = known
  Pathwise.charDB.beastTrainingSeen = true
  self:ScheduleUpdate()
end

-- The hunter knows a rank: seen in Beast Training, or the pet has it (or a
-- higher one).
local function HunterKnows(spellID, info, petRank)
  return Pathwise.charDB.beastTraining[spellID] or (petRank or 0) >= info.rank
end

-- Nearest spot of the best teaching beast for a rank that the player can
-- tame (level), not in an instance, not elite; normal beasts before rare
-- ones. Returns { beast, npcID, mapID, x, y, distance } or nil.
local function NearestTeacher(lib, spellID)
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return nil
  end
  local level = GetSnapshot().level or 1
  local Waypoints = Pathwise:GetModule("Waypoints")
  for _, kind in ipairs({ lib.kinds.normal, lib.kinds.rare }) do
    local best
    for _, npcID in ipairs(lib:GetTeachers(spellID, kind) or {}) do
      local beast = lib:GetBeast(npcID)
      if beast and beast.pins and not beast.elite and beast.minLevel <= level then
        for pinMap, pins in pairs(beast.pins) do
          -- The way there is measured once per map, to its pin nearest in a
          -- straight line (a beast can have hundreds of pins, and the way
          -- may go through boats).
          local px, py, straight
          for i = 1, #pins - 1, 2 do
            local d = Waypoints.Vector(mapID, x, y, pinMap, pins[i] / 100, pins[i + 1] / 100)
            if not px or (d and (not straight or d < straight)) then
              px, py, straight = pins[i] / 100, pins[i + 1] / 100, d
            end
          end
          local distance = px and Waypoints.TravelDistance(mapID, x, y, pinMap, px, py, true)
          if distance and (not best or distance < best.distance) then
            best = { beast = beast, npcID = npcID, mapID = pinMap, x = px, y = py, distance = distance }
          end
        end
      end
    end
    if best then
      return best
    end
  end
end

-- Pure-ish: what the pet could get, in PET_ABILITIES order:
-- list of { ability, name, spellID, rank, have, known }.
function PetGuide:GetUpgrades()
  local lib = Tameable()
  local pet = Platform.GetHunterPet()
  if not lib or not pet or not pet.level then
    return {}
  end
  local family = FamilyID(lib, pet)
  if not family then
    return {}
  end
  local petRanks = PetRanks(lib)
  local upgrades = {}
  for _, ability in ipairs(Data.Hunter.PET_ABILITIES) do
    -- The best rank this family learns at the pet's level.
    local best
    for _, spellID in ipairs(lib:GetAbilityRanks(ability) or {}) do
      local info = lib:GetRankInfo(spellID)
      if info.level <= pet.level and lib:CanLearn(family, spellID) then
        best = spellID
      end
    end
    local have = petRanks[ability] or 0
    local info = best and lib:GetRankInfo(best)
    if info and info.rank > have then
      upgrades[#upgrades + 1] = {
        ability = ability,
        name = Platform.GetSpellName(ability) or "?",
        spellID = best,
        rank = info.rank,
        have = have,
        known = HunterKnows(best, info, have),
      }
    end
  end
  return upgrades, pet
end

local function StepFor(lib, upgrade, pet)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  if upgrade.known then
    return {
      id = "pet:" .. upgrade.ability,
      priority = P.PET_TEACH,
      text = string.format(L.PET_TEACH, upgrade.name, upgrade.rank, pet.name or "?"),
      detail = { L.PET_TEACH_DETAIL },
    }
  end
  local teacher = NearestTeacher(lib, upgrade.spellID)
  if not teacher then
    return nil -- no beast the player can tame (yet) teaches it
  end
  local beast = teacher.beast
  local levels = beast.minLevel == beast.maxLevel and tostring(beast.minLevel)
    or (beast.minLevel .. "-" .. beast.maxLevel)
  local detail = {
    string.format(L.PET_TAME_WHERE, beast.name, levels, Platform.GetMapName(teacher.mapID) or "?"),
    string.format(L.PET_TAME_STABLE, pet.name or "?"),
    string.format(L.PET_TAME_THEN, upgrade.name, upgrade.rank, pet.name or "?"),
  }
  if beast.rare then
    detail[#detail + 1] = L.PET_TAME_RARE
  end
  if not Pathwise.charDB.beastTrainingSeen then
    detail[#detail + 1] = L.PET_OPEN_TRAINING
  end
  return {
    id = "pet:" .. upgrade.ability,
    priority = P.PET_TAME,
    text = string.format(L.PET_TAME, beast.name, levels, upgrade.name, upgrade.rank),
    detail = detail,
    -- A spawn spot of a beast: the target button and macro get its name.
    target = { mapID = teacher.mapID, x = teacher.x, y = teacher.y, spawn = true, npcName = beast.name,
      names = { beast.name }, label = string.format(L.PET_TAME_LABEL, beast.name, upgrade.name, upgrade.rank) },
  }
end

function PetGuide:BuildItems()
  local lib = Tameable()
  if not lib or not Pathwise.db.petGuide or GetSnapshot().class ~= "HUNTER" then
    return {}
  end
  local upgrades, pet = self:GetUpgrades()
  local items = {}
  for _, upgrade in ipairs(upgrades) do
    if #items >= PetGuide.MAX_STEPS then
      break
    end
    local item = StepFor(lib, upgrade, pet)
    if item then
      items[#items + 1] = item
    end
  end
  return items
end

function PetGuide:Update()
  local items = self:BuildItems()
  self.hasTargets = false
  for _, item in ipairs(items) do
    self.hasTargets = self.hasTargets or item.target ~= nil
  end
  Pathwise:GetModule("NextSteps"):SetItems("pet", items)
end

function PetGuide:ScheduleUpdate()
  if updatePending then
    return
  end
  updatePending = true
  Platform.After(UPDATE_DELAY, function()
    updatePending = false
    PetGuide:Update()
  end)
end

function PetGuide:OnUnitEvent(_, unit)
  if unit == nil or unit == "pet" or unit == "player" then
    self:ScheduleUpdate()
  end
end

local UPDATE_SECTIONS = { all = true, level = true, zone = true }

function PetGuide:OnCharacterUpdated(_, _, section)
  if UPDATE_SECTIONS[section] then
    self:ScheduleUpdate()
  end
end

function PetGuide:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
end

function PetGuide:OnEnable()
  if GetSnapshot().class ~= "HUNTER" then
    return
  end
  self:RegisterEvent("UNIT_PET", "OnUnitEvent")
  self:RegisterEvent("UNIT_LEVEL", "OnUnitEvent")
  self:RegisterEvent("PET_UI_UPDATE", "OnUnitEvent")
  self:RegisterEvent("PET_BAR_UPDATE", "OnUnitEvent")
  self:RegisterEvent("CRAFT_SHOW", "OnCraftShow")
  self:RegisterEvent("CRAFT_UPDATE", "OnCraftShow")
  -- The nearest teaching beast changes as the player moves.
  Platform.Every(DISTANCE_CHECK_SECONDS, function()
    if PetGuide.hasTargets then
      PetGuide:Update()
    end
  end)
  self:ScheduleUpdate()
end

---------------------------------------------------------------------------
-- /pw pet
---------------------------------------------------------------------------

Pathwise:RegisterCommand("pet", function()
  local lib = Tameable()
  local pet = Platform.GetHunterPet()
  if not lib then
    Pathwise:Print(L.PET_NO_DATA)
    return
  elseif not pet then
    Pathwise:Print(L.PET_NONE)
    return
  end
  Pathwise:Printf(L.PET_HEADER, pet.name or "?", pet.family or "?", pet.level or 0)
  local upgrades = PetGuide:GetUpgrades()
  if #upgrades == 0 then
    Pathwise:PrintLine("  " .. L.PET_ALL_GOOD)
  end
  local level = GetSnapshot().level or 1
  for _, upgrade in ipairs(upgrades) do
    if upgrade.known then
      Pathwise:PrintLine("  " .. string.format(L.PET_TEACH, upgrade.name, upgrade.rank, pet.name or "?"))
    else
      local names = {}
      for _, npcID in ipairs(lib:GetTeachers(upgrade.spellID) or {}) do
        local beast = lib:GetBeast(npcID)
        if beast and #names < MAX_LISTED and beast.minLevel <= level and not beast.elite then
          local map = beast.pins and next(beast.pins)
          names[#names + 1] = string.format(L.PET_BEAST, beast.name, beast.minLevel,
            map and Platform.GetMapName(map) or "?")
        end
      end
      Pathwise:PrintLine("  " .. string.format(L.PET_LEARN_LINE, upgrade.name, upgrade.rank,
        #names > 0 and table.concat(names, ", ") or L.PET_NO_TEACHER))
    end
  end
  if not Pathwise.charDB.beastTrainingSeen then
    Pathwise:PrintLine("  " .. L.PET_OPEN_TRAINING)
  end
end, L.CMD_PET)
