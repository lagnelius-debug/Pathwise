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

-- Clean up
AcceptQuest, GetQuestID, GetTitleText, IsShiftKeyDown, C_QuestLog = nil, nil, nil, nil, nil
LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Quest.GetAllIds = questGet, npcGet, allIds
QuestieData:ResetPickups()
