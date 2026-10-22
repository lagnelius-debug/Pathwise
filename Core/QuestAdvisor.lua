local addonName, Pathwise = ...

-- Quest log advisor: follows the quest log live and turns it into ordered
-- Next Steps (turn in, almost done, do here, do elsewhere, later, grey).
-- Uses only what the client knows about the quests in the log; no quest
-- database needed.

local L = Pathwise.L
local Platform = Pathwise.Platform

local QuestAdvisor = Pathwise:NewModule("QuestAdvisor")

-- QUEST_LOG_UPDATE fires in bursts; wait this long and update once.
local UPDATE_DELAY = 0.3

-- A quest with at least this share of its objectives done is "almost done".
local ALMOST_DONE = 0.5

local DIFFICULTY_COLORS = {
  RED = "ff2020",
  ORANGE = "ff8040",
  YELLOW = "ffff00",
  GREEN = "40c040",
  GREY = "808080",
}

local updatePending = false
local knownComplete -- [questID] = true; nil until the first scan

---------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------

-- Classic quest colors: red 5+ levels above, orange 3-4 above, yellow
-- within 2, green down to the green range, grey below that.
function QuestAdvisor.Difficulty(questLevel, playerLevel, greenRange)
  local diff = questLevel - playerLevel
  if diff >= 5 then
    return "RED"
  elseif diff >= 3 then
    return "ORANGE"
  elseif diff >= -2 then
    return "YELLOW"
  elseif -diff <= greenRange then
    return "GREEN"
  end
  return "GREY"
end

-- Share of objectives done (0..1), or nil for quests without objectives.
function QuestAdvisor.Progress(quest)
  local done, total = 0, 0
  for _, objective in ipairs(quest.objectives) do
    if objective.need and objective.need > 0 then
      done = done + math.min(objective.have or 0, objective.need)
      total = total + objective.need
    else
      done = done + (objective.finished and 1 or 0)
      total = total + 1
    end
  end
  if total == 0 then
    return nil
  end
  return done / total
end

local function QuestText(quest, difficulty)
  return string.format("|cff%s[%d] %s|r", DIFFICULTY_COLORS[difficulty], quest.level, quest.title)
end

local function Detail(quest)
  local lines = { quest.zone or "" }
  for _, objective in ipairs(quest.objectives) do
    local color = objective.finished and "|cff40c040" or "|cffffffff"
    lines[#lines + 1] = color .. "- " .. (objective.text or "?") .. "|r"
  end
  return lines
end

-- Pure function: quests -> Next Steps items, in recommended order.
-- locate(quest, kind) optionally returns an arrow target for a quest
-- ("turnIn" for complete quests, "do" for quests to work on).
function QuestAdvisor.Plan(quests, playerLevel, greenRange, currentZone, locate)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local items = {}

  for _, quest in ipairs(quests) do
    local difficulty = QuestAdvisor.Difficulty(quest.level, playerLevel, greenRange)
    local progress = QuestAdvisor.Progress(quest)
    local here = currentZone ~= nil and quest.zone == currentZone
    local name = QuestText(quest, difficulty)
    local priority, text, kind

    if quest.failed then
      priority, text = P.QUEST_FAILED, string.format(L.QA_FAILED, name)
    elseif quest.complete then
      priority, text, kind = P.QUEST_TURN_IN, string.format(L.QA_TURN_IN, name), "turnIn"
    elseif quest.suggestedGroup >= 2 then
      priority, text = P.QUEST_LATER, string.format(L.QA_GROUP, name, quest.suggestedGroup)
    elseif difficulty == "RED" then
      priority, text = P.QUEST_LATER, string.format(L.QA_LATER, quest.level - 2, name)
    elseif difficulty == "GREY" then
      priority, text = P.QUEST_GREY, string.format(L.QA_GREY, name)
    elseif progress and progress >= ALMOST_DONE then
      priority, text, kind = P.QUEST_ALMOST_DONE, string.format(L.QA_ALMOST_DONE, name, progress * 100), "do"
    elseif here then
      priority, text, kind = P.QUEST_HERE, string.format(L.QA_HERE, name), "do"
    else
      priority, text, kind = P.QUEST_ELSEWHERE, string.format(L.QA_ELSEWHERE, name, quest.zone or "?"), "do"
    end
    if difficulty == "ORANGE" and priority >= P.QUEST_ELSEWHERE and not quest.complete then
      text = text .. " " .. L.QA_HARD
    end

    items[#items + 1] = {
      id = "quest:" .. tostring(quest.questID or quest.title),
      priority = priority,
      text = text,
      detail = Detail(quest),
      target = kind and locate and locate(quest, kind) or nil,
      -- Within a priority: current zone first, then most progress, then
      -- lowest level (easiest first).
      order = { here and 0 or 1, -(progress or 0), quest.level },
    }
  end

  table.sort(items, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    for i = 1, 3 do
      if a.order[i] ~= b.order[i] then
        return a.order[i] < b.order[i]
      end
    end
    return a.text < b.text
  end)
  return items
end

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------

function QuestAdvisor:Update()
  local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
  local level = snapshot.level or 1
  local quests, collapsed = Platform.GetQuestLog()
  local currentZone = snapshot.zone and snapshot.zone.zone
  local QuestLocations = Pathwise:GetModule("QuestLocations")
  QuestLocations:OnQuestsScanned(quests)
  local function Locate(quest, kind)
    return QuestLocations:GetTarget(quest, kind)
  end
  local items = QuestAdvisor.Plan(quests, level, Platform.GetQuestGreenRange(level), currentZone, Locate)

  if #collapsed > 0 then
    items[#items + 1] = {
      id = "quest:collapsed",
      priority = 0,
      text = string.format(L.QA_COLLAPSED, table.concat(collapsed, ", ")),
    }
  end
  Pathwise:GetModule("NextSteps"):SetItems("quests", items)

  -- Chat nudge when a quest becomes complete (not for quests that were
  -- already complete when we first looked).
  local nowComplete = {}
  for _, quest in ipairs(quests) do
    if quest.complete and quest.questID then
      nowComplete[quest.questID] = true
      if knownComplete and not knownComplete[quest.questID] and Pathwise.db.chatMessages then
        Pathwise:Printf(L.QA_NOW_COMPLETE, quest.title)
      end
    end
  end
  knownComplete = nowComplete
end

function QuestAdvisor:ScheduleUpdate()
  if updatePending then
    return
  end
  updatePending = true
  Platform.After(UPDATE_DELAY, function()
    updatePending = false
    QuestAdvisor:Update()
  end)
end

local UPDATE_SECTIONS = { all = true, level = true, zone = true }

function QuestAdvisor:OnCharacterUpdated(_, _, section)
  if UPDATE_SECTIONS[section] then
    self:ScheduleUpdate()
  end
end

function QuestAdvisor:OnQuestEvent()
  self:ScheduleUpdate()
end

function QuestAdvisor:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
end

function QuestAdvisor:OnEnable()
  self:RegisterEvent("QUEST_LOG_UPDATE", "OnQuestEvent")
  self:RegisterEvent("QUEST_ACCEPTED", "OnQuestEvent")
  self:RegisterEvent("QUEST_REMOVED", "OnQuestEvent")
  self:RegisterEvent("QUEST_TURNED_IN", "OnQuestEvent")
end

---------------------------------------------------------------------------
-- /pw quests
---------------------------------------------------------------------------

Pathwise:RegisterCommand("quests", function()
  QuestAdvisor:Update()
  local any = false
  for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
    if item.id:find("^quest:") then
      if not any then
        Pathwise:Print(L.QA_HEADER)
        any = true
      end
      Pathwise:PrintLine("  " .. item.text)
    end
  end
  if not any then
    Pathwise:Print(L.QA_NONE)
  end
end, L.CMD_QUESTS)
