local addonName, Pathwise = ...

-- Trainer reminder: works out which class spells/ranks the player can learn
-- now ("available") and soon ("upcoming"), announces new ones once per level
-- and feeds the spellbook Training panel.
--
-- Callbacks fired:
--   TRAINING_UPDATED (list)  list = { available, recommended, optional,
--                            upcoming, spec }; available = recommended +
--                            optional. Entries: { id, name, rank, level,
--                            cost, optional }

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local Trainer = Pathwise:NewModule("Trainer")

-- "Coming soon" covers this many levels above the current one.
local UPCOMING_LEVELS = 4

-- The chat reminder lists at most this many spells by name.
local MAX_ANNOUNCED_NAMES = 6

local chainsClass   -- class the chain info below was built for
local chainInfo     -- [entry] = { prev = entry, base = entry, higher = { entries } }
local trainable     -- non-talent entries sorted by level, then name, then rank
local byId          -- [spellID] = entry
local list = { available = {}, recommended = {}, optional = {}, upcoming = {} }

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

-- Links each rank to the previous one and to the higher ranks of the same
-- spell (by name within the class's data).
local function BuildChains(class)
  chainsClass, chainInfo, trainable, byId = class, {}, {}, {}
  local entries = Data.ClassSpells[class]
  if not entries then
    return
  end
  local byName = {}
  for _, entry in ipairs(entries) do
    byId[entry.id] = entry
    byName[entry.name] = byName[entry.name] or {}
    table.insert(byName[entry.name], entry)
    if not entry.talent then
      trainable[#trainable + 1] = entry
    end
  end
  for _, chain in pairs(byName) do
    table.sort(chain, function(a, b)
      return (a.rank or 0) < (b.rank or 0)
    end)
    for i, entry in ipairs(chain) do
      local higher = {}
      for j = i + 1, #chain do
        higher[#higher + 1] = chain[j]
      end
      chainInfo[entry] = { prev = chain[i - 1], base = chain[1], higher = higher }
    end
  end
  table.sort(trainable, function(a, b)
    if a.level ~= b.level then
      return a.level < b.level
    end
    if a.name ~= b.name then
      return a.name < b.name
    end
    return (a.rank or 0) < (b.rank or 0)
  end)
end

-- Known if the client says so, or if a higher rank is known (learning a
-- higher rank can make the client stop reporting the lower ones).
local function IsKnown(entry)
  if Platform.IsSpellKnown(entry.id) then
    return true
  end
  for _, higher in ipairs(chainInfo[entry].higher) do
    if Platform.IsSpellKnown(higher.id) then
      return true
    end
  end
  return false
end

-- False for spells only another faction's or race's trainers teach.
local function ForPlayer(entry, snapshot)
  if entry.faction and snapshot.faction and entry.faction ~= snapshot.faction then
    return false
  end
  if entry.races and snapshot.raceID then
    for _, raceID in ipairs(entry.races) do
      if raceID == snapshot.raceID then
        return true
      end
    end
    return false
  end
  return true
end

-- True if the spell can be skipped on the player's current path (active
-- spec or goal, see Data/Classic/SpellPriority.lua).
local function IsOptional(entry, class, spec)
  local priority = Data.SpellPriority[class]
  if not priority then
    return false
  end
  if priority.common and priority.common[entry.name] then
    return true
  end
  return priority[spec] and priority[spec][entry.name] or false
end

local function MakeItem(entry, optional)
  local name = Platform.GetSpellDisplay(entry.id) or entry.name
  return {
    id = entry.id,
    name = name,
    rank = entry.rank,
    level = entry.level,
    cost = entry.cost,
    optional = optional,
  }
end

function Trainer:BuildList()
  local snapshot = GetSnapshot()
  if chainsClass ~= snapshot.class then
    BuildChains(snapshot.class)
  end
  local level = snapshot.level or 1
  local spec = Pathwise:GetModule("Talents"):GetSpecInfo().active
  local available, upcoming = {}, {}
  local willBeAvailable = {}

  for _, entry in ipairs(trainable) do
    local info = chainInfo[entry]
    -- Ranks of a talent spell only matter if the player has the talent.
    local talentOK = not info.base.talent or IsKnown(info.base)
    if talentOK and ForPlayer(entry, snapshot) and not IsKnown(entry) then
      if entry.level <= level then
        -- The previous rank must be known, or learnable in the same visit.
        local prevOK = not info.prev or willBeAvailable[info.prev] or IsKnown(info.prev)
        local required = entry.requires and byId[entry.requires]
        local requiresOK = not entry.requires or Platform.IsSpellKnown(entry.requires)
          or (required and (willBeAvailable[required] or IsKnown(required)))
        if prevOK and requiresOK then
          willBeAvailable[entry] = true
          available[#available + 1] = MakeItem(entry, IsOptional(entry, snapshot.class, spec))
        end
      elseif entry.level <= level + UPCOMING_LEVELS
        -- (Not when it needs something from a class quest the player
        -- hasn't done, e.g. bear abilities without Bear Form.)
        and (not entry.requires or byId[entry.requires] or Platform.IsSpellKnown(entry.requires)) then
        upcoming[#upcoming + 1] = MakeItem(entry, IsOptional(entry, snapshot.class, spec))
      end
    end
  end

  -- Recommended spells first, optional ones after (each in level order).
  local recommended, optional = {}, {}
  for _, item in ipairs(available) do
    table.insert(item.optional and optional or recommended, item)
  end

  list = {
    available = available,
    recommended = recommended,
    optional = optional,
    upcoming = upcoming,
    spec = spec,
  }
  return list
end

function Trainer:GetList()
  return list
end

function Trainer.FormatName(item)
  if item.rank then
    return string.format(L.TRAINER_RANK, item.name, item.rank)
  end
  return item.name
end

function Trainer.TotalCost(items)
  local total = 0
  for _, item in ipairs(items) do
    total = total + (item.cost or 0)
  end
  return total
end

---------------------------------------------------------------------------
-- Reminder
---------------------------------------------------------------------------

-- Names the recommended spells; optional ones are only counted.
local function Announce()
  local recommended = list.recommended
  local names = {}
  for i = 1, math.min(#recommended, MAX_ANNOUNCED_NAMES) do
    names[i] = Trainer.FormatName(recommended[i])
  end
  local text = table.concat(names, ", ")
  if #recommended > MAX_ANNOUNCED_NAMES then
    text = text .. string.format(L.TRAINER_AND_MORE, #recommended - MAX_ANNOUNCED_NAMES)
  end
  if #list.optional > 0 then
    text = text .. string.format(L.TRAINER_PLUS_OPTIONAL, #list.optional)
  end
  Pathwise:Printf(L.TRAINER_ANNOUNCE, text, Pathwise.FormatMoney(Trainer.TotalCost(recommended)))
end

local function UpdateNextSteps()
  local NextSteps = Pathwise:GetModule("NextSteps")
  local items = {}
  if #list.recommended > 0 and Pathwise.db.trainerTips then
    local detail = {}
    for i, item in ipairs(list.recommended) do
      detail[i] = Trainer.FormatName(item)
    end
    items[1] = {
      id = "trainer",
      priority = NextSteps.PRIORITY.TRAINER,
      text = string.format(L.NS_TRAINER, #list.recommended, Pathwise.FormatMoney(Trainer.TotalCost(list.recommended))),
      detail = detail,
    }
  end
  NextSteps:SetItems("trainer", items)
end

function Trainer:Refresh(allowAnnounce)
  self:BuildList()
  Pathwise:FireCallback("TRAINING_UPDATED", list)
  UpdateNextSteps()

  local level = GetSnapshot().level
  local charDB = Pathwise.charDB
  if allowAnnounce and #list.recommended > 0 and charDB.trainerAnnouncedLevel ~= level then
    charDB.trainerAnnouncedLevel = level
    if Pathwise.db.chatMessages and Pathwise.db.trainerTips then
      Announce()
    end
  end
end

local REFRESH_SECTIONS = { all = true, level = true, talents = true }

function Trainer:OnCharacterUpdated(_, _, section)
  if REFRESH_SECTIONS[section] then
    -- Announce on login and level up; talent changes only update the list.
    self:Refresh(section ~= "talents")
  end
end

function Trainer:OnSpellLearned()
  self:Refresh(false)
end

function Trainer:OnSpecChanged()
  self:Refresh(false)
end

function Trainer:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
  self:RegisterCallback("SPEC_CHANGED", "OnSpecChanged")
end

function Trainer:OnEnable()
  -- The event was renamed in 1.15.x; registering an unknown one is harmless.
  self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "OnSpellLearned")
  self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnSpellLearned")
end

---------------------------------------------------------------------------
-- /pw training
---------------------------------------------------------------------------

function Trainer:PrintList()
  self:BuildList()
  local specName = L["SPEC_" .. list.spec]
  if #list.available == 0 then
    Pathwise:Print(L.TRAINER_NONE)
  end
  if #list.recommended > 0 then
    Pathwise:Printf(L.TRAINER_RECOMMENDED_HEADER, specName, Pathwise.FormatMoney(Trainer.TotalCost(list.recommended)))
    for _, item in ipairs(list.recommended) do
      Pathwise:PrintLine(string.format("  %s - %s", Trainer.FormatName(item), Pathwise.FormatMoney(item.cost)))
    end
  end
  if #list.optional > 0 then
    Pathwise:PrintLine(string.format(L.TRAINER_OPTIONAL_HEADER, Pathwise.FormatMoney(Trainer.TotalCost(list.optional))))
    for _, item in ipairs(list.optional) do
      Pathwise:PrintLine(string.format("  %s - %s", Trainer.FormatName(item), Pathwise.FormatMoney(item.cost)))
    end
  end
  if #list.upcoming > 0 then
    Pathwise:PrintLine(L.TRAINER_UPCOMING_HEADER)
    for _, item in ipairs(list.upcoming) do
      local text = string.format("  " .. L.TRAINER_AT_LEVEL, item.level, Trainer.FormatName(item))
      if item.optional then
        text = text .. " " .. L.TRAINER_OPTIONAL_TAG
      end
      Pathwise:PrintLine(text)
    end
  end
end

Pathwise:RegisterCommand("training", function()
  Trainer:PrintList()
end, L.CMD_TRAINING)
