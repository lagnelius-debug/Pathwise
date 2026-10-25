local addonName, Pathwise = ...

-- Profession advisor: suggests professions that suit the class (once in
-- chat, and as a Next Steps item until learned), reminds the player to
-- train the next rank (Journeyman, Expert, Artisan) and to carry the tools
-- gathering needs, and tells the Skinning skill a beast needs (tooltip, see
-- UI/ProfessionTooltip.lua). With QuestieDB the arrow can point to the
-- nearest trainer. Data: Data/Classic/Professions.lua.
--
-- The player's choice always wins: two primary professions of any kind
-- end the "learn" suggestions, and /pw professions off hides all of it.

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local Professions = Pathwise:NewModule("Professions")

local UPDATE_DELAY = 0.5
-- Re-check trainer distances this often (the "near a trainer" priority).
local DISTANCE_CHECK_SECONDS = 10

local updatePending = false

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

---------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------

-- Skinning skill a beast of `level` needs (nil for "??" bosses).
function Professions.SkinningRequired(level)
  if not level or level < 0 then
    return nil
  elseif level <= 10 then
    return 1
  elseif level <= 20 then
    return (level - 10) * 10
  end
  return level * 5
end

-- The player's professions: [name] = { rank, maxRank }, and how many are
-- primary.
function Professions.Known(skills)
  local known, primaries = {}, 0
  for _, skill in ipairs(skills or {}) do
    local info = Data.Professions.LIST[skill.name]
    if info then
      known[skill.name] = { rank = skill.rank or 0, maxRank = skill.maxRank or 0 }
      if info.primary then
        primaries = primaries + 1
      end
    end
  end
  return known, primaries
end

-- The rank to train after a skill cap of maxRank (nil at the top).
function Professions.NextRank(maxRank)
  for _, rank in ipairs(Data.Professions.RANKS) do
    if rank.cap > maxRank then
      return rank
    end
  end
end

-- Recommendation for a class (falls back to the hunter's - any class gets
-- something sensible from a gathering + crafting pair).
function Professions.GetAdvice(class)
  return Data.Professions.ADVICE[class] or Data.Professions.ADVICE.HUNTER
end

-- What to learn: the class's leveling pair (as many as there's room for
-- next to the professions already known) plus First Aid-type secondaries
-- (only the first secondary - the rest are mentioned in the advice).
function Professions.ToLearn(class, known, primaries)
  local advice = Professions.GetAdvice(class)
  local missing = {}
  local room = Data.Professions.MAX_PRIMARY - primaries
  for _, name in ipairs(advice.leveling) do
    if room > 0 and not known[name] then
      missing[#missing + 1] = name
      room = room - 1
    end
  end
  local secondary = advice.secondary and advice.secondary[1]
  if secondary and not known[secondary] then
    missing[#missing + 1] = secondary
  end
  return missing
end

---------------------------------------------------------------------------
-- Next Steps
---------------------------------------------------------------------------

-- Trainer titles for a profession: the basic trainer, then the higher-rank
-- ones ("Artisan Leatherworker", ...).
local function TrainerTitles(name)
  local info = Data.Professions.LIST[name]
  local titles = { info.trainer }
  for _, prefix in ipairs({ "Journeyman", "Expert", "Artisan", "Master" }) do
    titles[#titles + 1] = prefix .. " " .. info.person
  end
  return titles
end

local function TrainerTarget(name)
  return Pathwise:GetModule("QuestieData"):GetTrainerTarget(TrainerTitles(name),
    string.format(L.PROF_TRAINER_LABEL, name))
end

local function Distance(target)
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not (target and mapID) then
    return nil
  end
  return Pathwise:GetModule("Waypoints").Vector(mapID, x, y, target.mapID, target.x, target.y)
end

-- Steps at a trainer within reach take the arrow; the others wait below the
-- quests.
local function NearPriority(distance, otherwise)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  if distance and distance <= Pathwise:GetModule("QuestAdvisor").NEAR_YARDS then
    return P.PROFESSION_NEAR
  end
  return otherwise
end

local function AdviceLines(class)
  local advice = Professions.GetAdvice(class)
  local lines = { L["PROF_WHY_" .. class] or L.PROF_WHY_DEFAULT }
  if advice.gold then
    lines[#lines + 1] = string.format(L.PROF_GOLD, table.concat(advice.gold, " + "))
  end
  if advice.endgame then
    lines[#lines + 1] = string.format(L.PROF_ENDGAME, advice.endgame)
  end
  if advice.secondary then
    lines[#lines + 1] = string.format(L.PROF_SECONDARY, table.concat(advice.secondary, ", "))
  end
  return lines
end

local function LearnItem(snapshot, known, primaries)
  local missing = Professions.ToLearn(snapshot.class, known, primaries)
  if #missing == 0 then
    return nil
  end
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  -- The arrow goes to the nearest trainer of any missing profession.
  local target, distance
  for _, name in ipairs(missing) do
    local candidate = TrainerTarget(name)
    local candidateDistance = Distance(candidate)
    if candidate and (not distance or (candidateDistance and candidateDistance < distance)) then
      target, distance = candidate, candidateDistance
    end
  end
  local detail = AdviceLines(snapshot.class)
  detail[#detail + 1] = L.PROF_OFF_HINT
  return {
    id = "prof:learn",
    priority = NearPriority(distance, P.PROFESSION_LEARN),
    text = string.format(L.PROF_LEARN, table.concat(missing, ", ")),
    detail = detail,
    target = target,
  }
end

local function TrainItems(snapshot, known)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local items = {}
  local level = snapshot.level or 1
  for name, skill in pairs(known) do
    local rank = Professions.NextRank(skill.maxRank)
    if rank and level >= rank.level and skill.rank >= rank.skill then
      local capped = skill.rank >= skill.maxRank
      local target = TrainerTarget(name)
      local detail = { capped and L.PROF_CAPPED_DETAIL or string.format(L.PROF_TRAIN_DETAIL, rank.cap) }
      if rank.level >= 20 then
        detail[#detail + 1] = L.PROF_HIGH_RANK_DETAIL
      end
      items[#items + 1] = {
        id = "prof:train:" .. name,
        priority = NearPriority(Distance(target), capped and P.PROFESSION_CAPPED or P.PROFESSION_TRAIN),
        text = string.format(L.PROF_TRAIN, rank.name, name, skill.rank, skill.maxRank),
        detail = detail,
        target = target,
      }
    end
  end
  table.sort(items, function(a, b) return a.id < b.id end)
  return items
end

local function ToolItems(known)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local items = {}
  for name in pairs(known) do
    local tool = Data.Professions.LIST[name].tool
    if tool and Platform.GetItemCount(tool.id) == 0 then
      local toolName = Platform.GetItemInfo(tool.id)
      items[#items + 1] = {
        id = "prof:tool:" .. name,
        priority = P.PROFESSION_TOOL,
        text = string.format(L.PROF_TOOL, toolName and toolName.name or tool.name, name),
        detail = { L.PROF_TOOL_DETAIL },
      }
    end
  end
  table.sort(items, function(a, b) return a.id < b.id end)
  return items
end

function Professions:BuildItems()
  local snapshot = GetSnapshot()
  if Pathwise.charDB.professionsOff or (snapshot.level or 1) < Data.Professions.RANKS[1].level then
    return {}
  end
  local known, primaries = Professions.Known(snapshot.skills)
  local items = {}
  local learn = LearnItem(snapshot, known, primaries)
  if learn then
    items[1] = learn
  end
  for _, list in ipairs({ TrainItems(snapshot, known), ToolItems(known) }) do
    for _, item in ipairs(list) do
      items[#items + 1] = item
    end
  end
  return items
end

-- One chat message with the recommendation, the first time the character
-- can learn professions.
local function MaybeAdvise(snapshot)
  local charDB = Pathwise.charDB
  if charDB.professionAdvice or charDB.professionsOff or not Pathwise.db.chatMessages
    or (snapshot.level or 1) < Data.Professions.RANKS[1].level then
    return
  end
  local _, primaries = Professions.Known(snapshot.skills)
  charDB.professionAdvice = true
  if primaries >= Data.Professions.MAX_PRIMARY then
    return -- already chosen
  end
  local advice = Professions.GetAdvice(snapshot.class)
  Pathwise:Printf(L.PROF_ADVICE_CHAT, snapshot.classLocalized or snapshot.class or "?",
    table.concat(advice.leveling, " + "))
end

function Professions:Update()
  local snapshot = GetSnapshot()
  MaybeAdvise(snapshot)
  local items = self:BuildItems()
  Pathwise:GetModule("NextSteps"):SetItems("professions", items)
  self.hasTargets = false
  for _, item in ipairs(items) do
    if item.target then
      self.hasTargets = true
    end
  end
end

function Professions:ScheduleUpdate()
  if updatePending then
    return
  end
  updatePending = true
  Platform.After(UPDATE_DELAY, function()
    updatePending = false
    Professions:Update()
  end)
end

local UPDATE_SECTIONS = { all = true, level = true, skills = true, bags = true, zone = true }

function Professions:OnCharacterUpdated(_, _, section)
  if UPDATE_SECTIONS[section] then
    self:ScheduleUpdate()
  end
end

function Professions:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
  self:RegisterCallback("QUESTIE_TRAINERS_READY", "ScheduleUpdate")
end

function Professions:OnEnable()
  self:ScheduleUpdate()
  -- Walking up to a trainer raises its step (and gives it the arrow).
  Platform.Every(DISTANCE_CHECK_SECONDS, function()
    if Professions.hasTargets then
      Professions:Update()
    end
  end)
end

---------------------------------------------------------------------------
-- Skinning (tooltips)
---------------------------------------------------------------------------

-- For a beast of `level`: needed, have (the player's Skinning), or nil
-- when the player has no Skinning or the level is unknown.
function Professions:GetSkinning(level)
  local needed = Professions.SkinningRequired(level)
  if not needed or Pathwise.charDB.professionsOff then
    return nil
  end
  local known = Professions.Known(GetSnapshot().skills)
  local skill = known[Data.Professions.SKINNING]
  if not skill then
    return nil
  end
  return needed, skill.rank
end

---------------------------------------------------------------------------
-- /pw professions [off|on]
---------------------------------------------------------------------------

Pathwise:RegisterCommand("professions", function(args)
  args = args:lower()
  if args == "off" or args == "on" then
    Pathwise.charDB.professionsOff = args == "off"
    Pathwise:Print(args == "off" and L.PROF_OFF or L.PROF_ON)
    Professions:Update()
    return
  end
  local snapshot = GetSnapshot()
  local advice = Professions.GetAdvice(snapshot.class)
  Pathwise:Printf(L.PROF_ADVICE_CHAT, snapshot.classLocalized or snapshot.class or "?",
    table.concat(advice.leveling, " + "))
  for _, line in ipairs(AdviceLines(snapshot.class)) do
    Pathwise:PrintLine("  " .. line)
  end
  local known = Professions.Known(snapshot.skills)
  local parts = {}
  for name, skill in pairs(known) do
    parts[#parts + 1] = string.format("%s %d/%d", name, skill.rank, skill.maxRank)
  end
  table.sort(parts)
  Pathwise:PrintLine("  " .. (#parts > 0 and string.format(L.PROF_YOURS, table.concat(parts, ", ")) or L.PROF_NONE))
end, L.CMD_PROFESSIONS)
