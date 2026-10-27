-- Auto-accept (Core/AutoAccept.lua): the quests the guide suggests are
-- taken when talking to their giver.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local QuestieData = Pathwise:GetModule("QuestieData")
local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()

local completed = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return completed[id] == true end }

local L = S.level
local quests = {
  [8001] = { name = "Suggested Quest", requiredLevel = 1, questLevel = L, startedBy = { { 9301 } } },
  [8002] = { name = "Grey Quest", requiredLevel = 1, questLevel = 1, startedBy = { { 9301 } } },
  [8003] = { name = "Chain Follow-up", requiredLevel = 1, questLevel = L, preQuestSingle = { 8001 },
    startedBy = { { 9302 } } },
}
local npcs = {
  [9301] = { name = "Giver Here", spawns = { [141] = { { 58, 41 } } } },
  [9302] = { name = "Giver Far Away", spawns = { [141] = { { 10, 90 } } } },
}
local questGet, npcGet, allIds = LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Quest.GetAllIds
LibQuestieDB.Quest.Get = function(id, key)
  if quests[id] then return quests[id][key] end
  return questGet(id, key)
end
LibQuestieDB.Npc.Get = function(id, key)
  if npcs[id] then return npcs[id][key] end
  return npcGet(id, key)
end
LibQuestieDB.Quest.GetAllIds = function() return { 8001, 8002, 8003 } end
QuestieData:ResetPickups()
QuestieData:PickupsReady()
WoW.RunTimers()
S.mapID, S.mapX, S.mapY = 1438, 0.58, 0.40
WoW.questLog = {}

local accepted, opened, shift, detail = 0, {}, false, {}
AcceptQuest = function() accepted = accepted + 1 end
GetQuestID = function() return detail.id end
GetTitleText = function() return detail.title end
IsShiftKeyDown = function() return shift end
local function Detail(id, title)
  detail = { id = id, title = title }
  WoW.FireEvent("QUEST_DETAIL")
end
Pathwise.db.autoAcceptHinted = false

---------------------------------------------------------------------------
section("Auto-accept: the quest window")

WoW.ClearChat()
Detail(8001, "Suggested Quest")
check("a suggested quest is accepted", accepted == 1)
check("explained once in chat", WoW.ChatContains("Pathwise accepted Suggested Quest for you"))
WoW.ClearChat()
Detail(8001, "Suggested Quest")
check("not explained again", accepted == 2 and not WoW.ChatContains("Pathwise accepted"))
Detail(8002, "Grey Quest")
check("a quest the guide doesn't suggest (grey) is left alone", accepted == 2)
completed[8001] = true
Detail(8003, "Chain Follow-up")
check("the next quest of a chain counts too, wherever its giver is", accepted == 3)
completed[8001] = nil
shift = true
Detail(8001, "Suggested Quest")
check("holding Shift skips it", accepted == 3)
shift = false
S.npcName = "Some Player"
UnitIsPlayer = function(unit) return unit == "npc" end
Detail(8001, "Suggested Quest")
check("a quest shared by another player is never accepted", accepted == 3)
S.npcName, UnitIsPlayer = nil, nil
Pathwise.db.autoAccept = false
Detail(8001, "Suggested Quest")
check("switched off: nothing", accepted == 3)
Pathwise.db.autoAccept = true
Detail(nil, "Suggested Quest")
check("without a quest ID: by title", accepted == 4)

---------------------------------------------------------------------------
section("Auto-accept: picking from the giver's list")

C_GossipInfo = {
  GetAvailableQuests = function()
    return { { title = "Grey Quest", questID = 8002 }, { title = "Suggested Quest", questID = 8001 } }
  end,
  SelectAvailableQuest = function(id) opened[#opened + 1] = id end,
}
WoW.FireEvent("GOSSIP_SHOW")
check("gossip: the suggested quest is opened", table.concat(opened, ",") == "8001")
WoW.FireEvent("GOSSIP_SHOW")
check("not opened again right away (the list shows again after accepting)", #opened == 1)
WoW.now = WoW.now + 5
shift = true
WoW.FireEvent("GOSSIP_SHOW")
check("Shift: the list stays as it is", #opened == 1)
shift = false
C_GossipInfo = nil

local titles = { "Grey Quest", "Suggested Quest" }
GetNumAvailableQuests = function() return #titles end
GetAvailableTitle = function(i) return titles[i] end
SelectAvailableQuest = function(i) opened[#opened + 1] = "greeting " .. i end
WoW.FireEvent("QUEST_GREETING")
check("greeting window: by title", opened[#opened] == "greeting 2")
GetNumAvailableQuests, GetAvailableTitle, SelectAvailableQuest = nil, nil, nil

---------------------------------------------------------------------------
section("Auto-accept: class quests")

local saved = { class = snapshot.class, raceID = snapshot.raceID, level = snapshot.level }
snapshot.class, snapshot.raceID, snapshot.level = "WARLOCK", 7, 10
check("the Voidwalker quest is suggested at 10", QuestAdvisor:IsSuggested(1685))
check("so is the rest of its chain", QuestAdvisor:IsSuggested(1688))
WoW.knownSpells[697] = true
check("not once you have the Voidwalker", not QuestAdvisor:IsSuggested(1685))
WoW.knownSpells[697] = nil
snapshot.class, snapshot.raceID, snapshot.level = saved.class, saved.raceID, saved.level

---------------------------------------------------------------------------
section("Auto turn-in")

local selectedActive, completed, rewards = {}, 0, {}
local completable, money, choices = true, 0, 0
C_GossipInfo = {
  GetActiveQuests = function()
    return { { title = "Not Yet", questID = 8101, isComplete = false }, { title = "All Done", questID = 8100, isComplete = true },
      { title = "Not Mine", questID = 8102, isComplete = true } }
  end,
  SelectActiveQuest = function(id) selectedActive[#selectedActive + 1] = id end,
  GetAvailableQuests = function() return { { title = "Suggested Quest", questID = 8001 } } end,
  SelectAvailableQuest = function(id) opened[#opened + 1] = id end,
}
IsQuestCompletable = function() return completable end
GetQuestMoneyToGet = function() return money end
CompleteQuest = function() completed = completed + 1 end
GetNumQuestChoices = function() return choices end
GetQuestReward = function(choice) rewards[#rewards + 1] = choice end
WoW.questLog = {
  { title = "All Done", level = L, questID = 8100, complete = 1, objectives = { { text = "Thing: 1/1", finished = true } } },
  { title = "Not Yet", level = L, questID = 8101, objectives = { { text = "Thing: 0/1" } } },
}
WoW.now = WoW.now + 10
local openedBefore = #opened
WoW.FireEvent("GOSSIP_SHOW")
check("gossip: the finished quest is opened first, not a new one", table.concat(selectedActive, ",") == "8100"
  and #opened == openedBefore)
detail = { id = 8100, title = "All Done" }
WoW.FireEvent("QUEST_PROGRESS")
check("progress window: completed", completed == 1)
WoW.ClearChat()
WoW.FireEvent("QUEST_COMPLETE")
check("no reward to choose: taken", table.concat(rewards, ",") == "0")
check("explained once in chat", WoW.ChatContains("Pathwise turned in All Done for you"))
choices = 1
WoW.FireEvent("QUEST_COMPLETE")
check("one reward: taken", rewards[#rewards] == 1)
choices = 3
WoW.FireEvent("QUEST_COMPLETE")
check("rewards to choose from: left to you", #rewards == 2)
choices = 0

-- Never: quests not in the log (repeatable hand-ins), gold, Shift, off.
detail = { id = 8102, title = "Not Mine" }
WoW.FireEvent("QUEST_PROGRESS")
WoW.FireEvent("QUEST_COMPLETE")
check("a quest that isn't in the log (a repeatable hand-in): left alone", completed == 1 and #rewards == 2)
detail = { id = 8100, title = "All Done" }
money = 500
WoW.FireEvent("QUEST_PROGRESS")
check("asks for gold: left alone", completed == 1)
money = 0
completable = false
WoW.FireEvent("QUEST_PROGRESS")
check("not completable: left alone", completed == 1)
completable = true
shift = true
WoW.FireEvent("QUEST_PROGRESS")
check("Shift: left alone", completed == 1)
shift = false
Pathwise.db.autoTurnIn = false
WoW.FireEvent("QUEST_PROGRESS")
WoW.FireEvent("QUEST_COMPLETE")
check("switched off: nothing", completed == 1 and #rewards == 2)
Pathwise.db.autoTurnIn = true
-- A breadcrumb ("Report to ...") has no objectives: finished in the log.
WoW.questLog = { { title = "Report In", level = L, questID = 8103, objectives = {} } }
C_GossipInfo.GetActiveQuests = function() return { { title = "Report In", questID = 8103 } } end
WoW.now = WoW.now + 10
WoW.FireEvent("GOSSIP_SHOW")
check("a quest with nothing to do (Report to ...) is turned in too", selectedActive[#selectedActive] == 8103)
C_GossipInfo, WoW.questLog = nil, {}
IsQuestCompletable, GetQuestMoneyToGet, CompleteQuest, GetNumQuestChoices, GetQuestReward = nil, nil, nil, nil, nil

-- Clean up
AcceptQuest, GetQuestID, GetTitleText, IsShiftKeyDown, C_QuestLog = nil, nil, nil, nil, nil
LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Quest.GetAllIds = questGet, npcGet, allIds
QuestieData:ResetPickups()
