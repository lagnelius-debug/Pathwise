local addonName, Pathwise = ...

-- Auto-accept: talking to a quest giver, the quests the guide suggests are
-- taken without clicking - in a gossip or greeting list the suggested one
-- is opened, and in the quest window it's accepted. "Suggested" means a
-- quest of an open class quest or one the guide would suggest picking up
-- (QuestAdvisor:IsSuggested: the same rules as the pickups).
-- Auto turn-in: finished quests from the quest log are handed in the same
-- way - opened from the list (before any quest to pick up, so a follow-up
-- can be taken right after), completed, and the reward taken when there's
-- at most one. With rewards to choose from, the window stays open (with the
-- best one highlighted, UI/QuestRewardUI.lua). Never for quests that aren't
-- in the log (repeatable hand-ins of items you may want to keep) or that
-- ask for gold.
-- Hold Shift while talking to skip both; each has a switch on the Features
-- page. Quests shared by other players are never accepted.

local L = Pathwise.L
local Platform = Pathwise.Platform

local AutoAccept = Pathwise:NewModule("AutoAccept")

-- A quest opened from a list isn't opened again for this long (the list
-- shows again after accepting; the next suggested one is opened then).
local REOPEN_SECONDS = 3

local opened = {} -- [questID or title] = time it was opened

local function Active()
  return Pathwise.db.autoAccept and not Platform.IsShiftKeyDown()
end

local function TurnInActive()
  return Pathwise.db.autoTurnIn and not Platform.IsShiftKeyDown()
end

-- The quests in the log, by ID and by title: [key] = true when finished
-- (complete, or nothing to do like "Report to ..."), false otherwise.
local function LogQuests()
  local byID, byTitle = {}, {}
  for _, quest in ipairs(Platform.GetQuestLog()) do
    local finished = quest.complete == 1 or quest.complete == true
      or (not quest.failed and #(quest.objectives or {}) == 0)
    if quest.questID then
      byID[quest.questID] = finished
    end
    if quest.title then
      byTitle[quest.title] = finished
    end
  end
  return byID, byTitle
end

-- A quest's entry in LogQuests (true/false), or nil when it's not in the log.
local function InLog(byID, byTitle, questID, title)
  if questID then
    return byID[questID]
  end
  return byTitle[title or ""]
end

-- The quest being turned in: set when its progress window is completed,
-- so its reward window may be finished too.
local turningIn

-- Gossip or greeting list: open the first finished quest to turn in.
-- Returns true when one was opened.
local function OpenTurnIn(event)
  if not TurnInActive() then
    return false
  end
  local byID, byTitle = LogQuests()
  local now = Platform.GetTime()
  for _, entry in ipairs(Platform.GetActiveQuests(event) or {}) do
    local key = "turnin:" .. tostring(entry.questID or entry.title)
    local logged = InLog(byID, byTitle, entry.questID, entry.title)
    -- Finished by the giver's word (the list's "complete"), else the log's.
    local finished = logged ~= nil and (entry.complete == true or (entry.complete == nil and logged))
    if finished and not (opened[key] and now - opened[key] < REOPEN_SECONDS) then
      opened[key] = now
      Platform.SelectActiveQuest(event, entry)
      return true
    end
  end
  return false
end

local function Suggested(questID, title)
  -- (By title only when the client gives no ID.)
  return Pathwise:GetModule("QuestAdvisor"):IsSuggested(questID, not questID and title or nil)
end

-- Gossip or greeting list: open the first suggested quest.
function AutoAccept:OnQuestGiver(event)
  if OpenTurnIn(event) or not Active() then
    return
  end
  local now = Platform.GetTime()
  for _, entry in ipairs(Platform.GetOfferedQuests(event) or {}) do
    local key = entry.questID or entry.title
    if key and not (opened[key] and now - opened[key] < REOPEN_SECONDS) and Suggested(entry.questID, entry.title) then
      opened[key] = now
      Platform.SelectOfferedQuest(event, entry)
      return
    end
  end
end

-- The quest window: accept a suggested quest.
function AutoAccept:OnQuestDetail()
  if not Active() or Platform.QuestFromPlayer() then
    return
  end
  local questID, title = Platform.GetQuestDetail()
  if questID == 0 then
    questID = nil
  end
  if not (questID or title) or not Suggested(questID, title) then
    return
  end
  Platform.AcceptQuest()
  -- (The game says "Quest accepted" itself; Pathwise explains once.)
  if not Pathwise.db.autoAcceptHinted and Pathwise.db.chatMessages then
    Pathwise.db.autoAcceptHinted = true
    Pathwise:Printf(L.AUTO_ACCEPT_HINT, title or "?")
  end
end

-- The progress window ("Complete Quest"): only for a quest from the log
-- that the game says can be completed, and never when it asks for gold.
function AutoAccept:OnQuestProgress()
  turningIn = nil
  if not TurnInActive() then
    return
  end
  local questID, title = Platform.GetQuestDetail()
  if questID == 0 then
    questID = nil
  end
  local byID, byTitle = LogQuests()
  local completable, money = Platform.GetQuestProgress()
  if InLog(byID, byTitle, questID, title) ~= nil and completable and money == 0 then
    turningIn = questID or title
    Platform.CompleteQuest()
  end
end

-- The reward window: take the reward when there's nothing to choose.
-- (Also for a quest that skips the progress window: finished in the log.)
function AutoAccept:OnQuestComplete()
  if not TurnInActive() then
    turningIn = nil
    return
  end
  local questID, title = Platform.GetQuestDetail()
  if questID == 0 then
    questID = nil
  end
  local byID, byTitle = LogQuests()
  local ours = turningIn ~= nil and (turningIn == questID or turningIn == title)
    or InLog(byID, byTitle, questID, title) ~= nil
  turningIn = nil
  local choices = Platform.GetNumQuestChoices()
  if ours and choices <= 1 then
    Platform.GetQuestReward(choices)
    if not Pathwise.db.autoTurnInHinted and Pathwise.db.chatMessages then
      Pathwise.db.autoTurnInHinted = true
      Pathwise:Printf(L.AUTO_TURN_IN_HINT, title or "?")
    end
  end
end

function AutoAccept:OnEnable()
  self:RegisterEvent("GOSSIP_SHOW", "OnQuestGiver")
  self:RegisterEvent("QUEST_GREETING", "OnQuestGiver")
  self:RegisterEvent("QUEST_DETAIL", "OnQuestDetail")
  self:RegisterEvent("QUEST_PROGRESS", "OnQuestProgress")
  self:RegisterEvent("QUEST_COMPLETE", "OnQuestComplete")
end
