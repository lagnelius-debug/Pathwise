local addonName, Pathwise = ...

-- Auto-accept: talking to a quest giver, the quests the guide suggests are
-- taken without clicking - in a gossip or greeting list the suggested one
-- is opened, and in the quest window it's accepted. "Suggested" means a
-- quest of an open class quest or one the guide would suggest picking up
-- (QuestAdvisor:IsSuggested: the same rules as the pickups). Hold Shift
-- while talking to skip it; switch it off on the Features page.
-- Quests shared by other players are never accepted.

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

local function Suggested(questID, title)
  -- (By title only when the client gives no ID.)
  return Pathwise:GetModule("QuestAdvisor"):IsSuggested(questID, not questID and title or nil)
end

-- Gossip or greeting list: open the first suggested quest.
function AutoAccept:OnQuestGiver(event)
  if not Active() then
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

function AutoAccept:OnEnable()
  self:RegisterEvent("GOSSIP_SHOW", "OnQuestGiver")
  self:RegisterEvent("QUEST_GREETING", "OnQuestGiver")
  self:RegisterEvent("QUEST_DETAIL", "OnQuestDetail")
end
