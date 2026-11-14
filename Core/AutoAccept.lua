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
-- A giver with several quests to pick up leaves the choice to the player
-- (none is opened or accepted), except the follow-up of the quest just
-- turned in. Dungeon quests only in dungeon mode for that dungeon
-- (QuestAdvisor:IsSuggested).

local L = Pathwise.L
local Platform = Pathwise.Platform

local AutoAccept = Pathwise:NewModule("AutoAccept")

-- A quest opened from a list isn't opened again for this long (the list
-- shows again after accepting; the next suggested one is opened then).
local REOPEN_SECONDS = 3

local opened = {} -- [questID or title] = time it was opened

-- A turned-in quest's follow-up is still taken from a list this long after.
local FOLLOW_UP_SECONDS = 60
-- After a list with several quests, a quest window from that giver this
-- soon after was opened by the player: not accepted for them.
local CHOOSE_SECONDS = 120

local lastTurnIn -- { questID, time }
local choosing -- { npc, time }: a list with several quests was shown

-- Whether a quest follows on from another one (its pre-quest, or the next
-- in its chain).
function AutoAccept.FollowsOn(questID, doneID)
  return Pathwise:GetModule("QuestieData"):FollowsOn(questID, doneID)
end

-- The quest just turned in (within FOLLOW_UP_SECONDS), or nil.
local function JustTurnedIn(now)
  return lastTurnIn and now - lastTurnIn.time <= FOLLOW_UP_SECONDS and lastTurnIn.questID or nil
end

local function Active()
  return Pathwise.db.autoAccept and not Platform.IsShiftKeyDown()
end

local function TurnInActive()
  return Pathwise.db.autoTurnIn and not Platform.IsShiftKeyDown()
end

-- The quests in the log, by ID and by title: [key] = true when the log
-- marks it complete, false otherwise. (A quest without objectives - "Report
-- to ...", but also an escort - isn't counted as finished here: the
-- giver's list or the game's "can be completed" decides.)
local function LogQuests()
  local byID, byTitle = {}, {}
  for _, quest in ipairs(Platform.GetQuestLog()) do
    local finished = quest.complete == 1 or quest.complete == true
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
-- Quests whose reward didn't fit in the bags: not opened from the list
-- again until the bags change (so the NPC's other options stay reachable).
local bagsFull = {}

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
    if finished and not bagsFull[entry.questID or entry.title or ""]
      and not (opened[key] and now - opened[key] < REOPEN_SECONDS) then
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
  local offered = Platform.GetOfferedQuests(event) or {}
  -- Several to pick up: the player chooses - only the follow-up of the
  -- quest just turned in is taken (reported: two Drowned City quests taken
  -- at once in Booty Bay).
  local done = #offered > 1 and JustTurnedIn(now)
  choosing = #offered > 1 and { npc = Platform.GetInteractionNPCName(), time = now } or nil
  for _, entry in ipairs(offered) do
    local key = entry.questID or entry.title
    if key and not (opened[key] and now - opened[key] < REOPEN_SECONDS)
      and (#offered == 1 or AutoAccept.FollowsOn(entry.questID, done))
      and Suggested(entry.questID, entry.title) then
      opened[key] = now
      Platform.SelectOfferedQuest(event, entry)
      return
    end
  end
end

-- Whether the player is choosing among the giver's quests (a list with
-- several was shown by this giver just before).
local function Choosing(now)
  return choosing ~= nil and now - choosing.time < CHOOSE_SECONDS
    and choosing.npc == Platform.GetInteractionNPCName()
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
  local now = Platform.GetTime()
  if Choosing(now) and not AutoAccept.FollowsOn(questID, JustTurnedIn(now)) then
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

-- Whether the bags have room for the reward items (fixed ones, plus the
-- only choice). Unknown counts as room.
local function RoomForRewards(choices)
  local free = Platform.GetFreeBagSlots()
  local needed = Platform.GetNumQuestRewards() + (choices == 1 and 1 or 0)
  return free == nil or needed <= free
end

-- The reward window: take the reward when there's nothing to choose.
-- (Also for a quest that skips the progress window: finished in the log.)
-- With full bags it's left to the player: taking it would fail, and every
-- visit to the NPC would open the quest again.
function AutoAccept:OnQuestComplete()
  local questID, title = Platform.GetQuestDetail()
  if questID == 0 then
    questID = nil
  end
  -- (Its follow-up may show before the game says it's turned in.)
  if questID then
    lastTurnIn = { questID = questID, time = Platform.GetTime() }
  end
  if not TurnInActive() then
    turningIn = nil
    return
  end
  local byID, byTitle = LogQuests()
  local ours = turningIn ~= nil and (turningIn == questID or turningIn == title)
    or InLog(byID, byTitle, questID, title) ~= nil
  turningIn = nil
  local choices = Platform.GetNumQuestChoices()
  if ours and choices <= 1 and not RoomForRewards(choices) then
    Pathwise:Print(L.AUTO_TURN_IN_BAGS_FULL)
    bagsFull[questID or title or ""] = true
  elseif ours and choices <= 1 then
    Platform.GetQuestReward(choices)
    if not Pathwise.db.autoTurnInHinted and Pathwise.db.chatMessages then
      Pathwise.db.autoTurnInHinted = true
      Pathwise:Printf(L.AUTO_TURN_IN_HINT, title or "?")
    end
  end
end

-- A quest was turned in (by Pathwise or the player): its follow-up may
-- be taken from the giver's list.
function AutoAccept:OnQuestTurnedIn(_, questID)
  if questID then
    lastTurnIn = { questID = questID, time = Platform.GetTime() }
  end
end

-- Bags changed: the rewards may fit now.
function AutoAccept:OnCharacterUpdated(_, _, section)
  if section == "bags" then
    bagsFull = {}
  end
end

function AutoAccept:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
end

function AutoAccept:OnEnable()
  self:RegisterEvent("GOSSIP_SHOW", "OnQuestGiver")
  self:RegisterEvent("QUEST_GREETING", "OnQuestGiver")
  self:RegisterEvent("QUEST_DETAIL", "OnQuestDetail")
  self:RegisterEvent("QUEST_PROGRESS", "OnQuestProgress")
  self:RegisterEvent("QUEST_COMPLETE", "OnQuestComplete")
  self:RegisterEvent("QUEST_TURNED_IN", "OnQuestTurnedIn")
end
