local addonName, Pathwise = ...

-- Class quest reminders for every class but the hunter (whose taming quest
-- is in Classes/Hunter.lua): stances, forms, demons, totems, poisons and
-- the free mounts (Data/Classic/ClassQuests.lua). From the quest's level
-- until it's done, Next Steps shows a step with the arrow on the nearest
-- giver for your race; while a quest of the chain is in the log, the quest
-- itself is the step. Each one is said once in chat.

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local ClassQuests = Pathwise:NewModule("ClassQuests")

local UPDATE_DELAY = 0.5
-- At most this many reminders at once (a level 30 shaman who skipped the
-- totems doesn't need four lines).
ClassQuests.MAX_STEPS = 3

local updatePending = false
local shownStarts = {} -- [questID] = true for the reminders shown now

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

-- bit: a power of two. Works without the bit library (and in tests).
local function HasBit(mask, bit)
  return math.floor(mask / bit) % 2 == 1
end

-- The first quests of a reminder the player's race can take.
local function StartsFor(reminder, raceID)
  local list = {}
  for questID, races in pairs(reminder.starts) do
    if races == 0 or not raceID or HasBit(races, 2 ^ (raceID - 1)) then
      list[#list + 1] = questID
    end
  end
  table.sort(list)
  return list
end

-- True once the reminder's quest is done: its spell known (any rank: the
-- client may stop reporting lower ranks), its skill or item there, or a
-- last quest completed.
function ClassQuests.IsDone(reminder, class, snapshot)
  for _, questID in ipairs(reminder.finals) do
    if Platform.IsQuestCompleted(questID) then
      return true
    end
  end
  if reminder.spell then
    if Platform.IsSpellKnown(reminder.spell) then
      return true
    end
    for _, entry in ipairs(Data.ClassSpells[class] or {}) do
      if entry.name == reminder.name and Platform.IsSpellKnown(entry.id) then
        return true
      end
    end
  end
  if reminder.skill then
    for _, skill in ipairs(snapshot.skills or {}) do
      if skill.name == reminder.skill then
        return true
      end
    end
  end
  if reminder.item and not reminder.spell and Platform.GetItemCount(reminder.item) > 0 then
    return true
  end
  return false
end

local function ChainInLog(reminder, inLog)
  for _, questID in ipairs(reminder.chain) do
    if inLog[questID] then
      return true
    end
  end
  return false
end

local function StepText(reminder)
  local key = "CQ_" .. reminder.key
  local text, detail = rawget(L, key), rawget(L, key .. "_DETAIL")
  if text then
    return text, detail and string.format(detail, reminder.level)
  end
  -- Priest racial spells share one text, with the client's spell name.
  local name = (reminder.spell and Platform.GetSpellName(reminder.spell)) or reminder.name or "?"
  return string.format(L.CQ_RACIAL, name), string.format(L.CQ_RACIAL_DETAIL, reminder.level, name)
end

-- The reminders to show now: list of { reminder, starts }.
function ClassQuests:GetOpen()
  local snapshot = GetSnapshot()
  local reminders = Data.ClassQuests[snapshot.class or ""]
  if not reminders then
    return {}
  end
  local inLog = {}
  for _, quest in ipairs(Platform.GetQuestLog()) do
    if quest.questID then
      inLog[quest.questID] = true
    end
  end
  local level = snapshot.level or 1
  local open = {}
  for _, reminder in ipairs(reminders) do
    local starts = StartsFor(reminder, snapshot.raceID)
    if #starts > 0 and level >= reminder.level and not ChainInLog(reminder, inLog)
      and not ClassQuests.IsDone(reminder, snapshot.class, snapshot) then
      open[#open + 1] = { reminder = reminder, starts = starts }
    end
  end
  -- The important ones first, then by level.
  table.sort(open, function(a, b)
    if (a.reminder.important or false) ~= (b.reminder.important or false) then
      return a.reminder.important == true
    end
    return a.reminder.level < b.reminder.level
  end)
  return open
end

-- True when a quest is the start of a reminder shown now (the quest
-- pickups leave it out: the reminder already says it).
function ClassQuests:Covers(questID)
  return shownStarts[questID] == true
end

function ClassQuests:Update()
  local NextSteps = Pathwise:GetModule("NextSteps")
  shownStarts = {}
  if not Pathwise.db.classQuests then
    NextSteps:SetItems("classQuests", {})
    return
  end
  local P = NextSteps.PRIORITY
  local reminded = Pathwise.charDB.classQuestsReminded
  local items = {}
  for _, entry in ipairs(self:GetOpen()) do
    if #items >= ClassQuests.MAX_STEPS then
      break
    end
    local reminder = entry.reminder
    local text, detail = StepText(reminder)
    local item = {
      id = "classquest:" .. reminder.key,
      priority = reminder.important and P.CLASS_QUEST or P.CLASS_QUEST_OPTIONAL,
      text = text,
      detail = { detail },
      target = Pathwise:GetModule("QuestieData"):GetQuestGiverTarget(entry.starts, L.CQ_TARGET),
    }
    items[#items + 1] = item
    for _, questID in ipairs(entry.starts) do
      shownStarts[questID] = true
    end
    if not reminded[reminder.key] and Pathwise.db.chatMessages then
      reminded[reminder.key] = true
      Pathwise:Printf(L.CQ_CHAT, text)
    end
  end
  NextSteps:SetItems("classQuests", items)
end

function ClassQuests:ScheduleUpdate()
  if updatePending then
    return
  end
  updatePending = true
  Platform.After(UPDATE_DELAY, function()
    updatePending = false
    ClassQuests:Update()
  end)
end

local UPDATE_SECTIONS = { all = true, level = true, skills = true, bags = true }

function ClassQuests:OnCharacterUpdated(_, _, section)
  if UPDATE_SECTIONS[section] then
    self:ScheduleUpdate()
  end
end

function ClassQuests:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
end

function ClassQuests:OnEnable()
  self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "ScheduleUpdate")
  self:RegisterEvent("LEARNED_SPELL_IN_TAB", "ScheduleUpdate")
  self:RegisterEvent("QUEST_LOG_UPDATE", "ScheduleUpdate") -- class quests picked up / done
  self:ScheduleUpdate()
end
