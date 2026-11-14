-- The questline the player is on (Core/QuestAdvisor.lua): after a turn-in,
-- the quest that follows on from it comes before what's merely close by
-- (reported: after travelling to turn a quest in, the guide led to the
-- nearest quests instead of on with the chain).
local WoW, Pathwise, check, section = ...
local S = WoW.state

local NextSteps = Pathwise:GetModule("NextSteps")
local QuestieData = Pathwise:GetModule("QuestieData")
local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local P = NextSteps.PRIORITY

local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end
local function Position(id)
  for i, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return i end
  end
end
local function UpdateLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

WoW.completedQuests = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return WoW.completedQuests[id] == true end }

local L = S.level
local quests = {
  [8101] = { name = "Chain Start", requiredLevel = 1, questLevel = L, startedBy = { { 9401 } } },
  -- Its follow-up: given far away, in Darkshore.
  [8102] = { name = "Chain Next", requiredLevel = 1, questLevel = L, preQuestSingle = { 8101 },
    startedBy = { { 9403 } }, objectives = { { { 9404 } } } },
  [8103] = { name = "Nearby Quest", requiredLevel = 1, questLevel = L, startedBy = { { 9401 } } },
  [8104] = { name = "Near Work", requiredLevel = 1, questLevel = L, startedBy = { { 9401 } },
    objectives = { { { 9405 } } } },
  [8105] = { name = "Unrelated Far", requiredLevel = 1, questLevel = L, startedBy = { { 9403 } },
    objectives = { { { 9406 } } } },
  [8106] = { name = "Chain Third", requiredLevel = 1, questLevel = L, preQuestSingle = { 8102 },
    startedBy = { { 9403 } } },
  [8107] = { name = "Near Work Two", requiredLevel = 1, questLevel = L, startedBy = { { 9401 } },
    objectives = { { { 9407 } } } },
  [8108] = { name = "Near Work Three", requiredLevel = 1, questLevel = L, startedBy = { { 9401 } },
    objectives = { { { 9408 } } } },
}
local npcs = {
  [9401] = { name = "Giver Here", spawns = { [141] = { { 58, 41 } } } },
  [9403] = { name = "Giver In Darkshore", spawns = { [148] = { { 36, 45 } } } },
  [9404] = { name = "Darkshore Beast", spawns = { [148] = { { 40, 50 } } } },
  [9405] = { name = "Teldrassil Beast", spawns = { [141] = { { 59, 42 } } } },
  [9406] = { name = "Other Darkshore Beast", spawns = { [148] = { { 55, 20 } } } },
  [9407] = { name = "Teldrassil Owl", spawns = { [141] = { { 45, 60 } } } },
  [9408] = { name = "Teldrassil Cat", spawns = { [141] = { { 70, 30 } } } },
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
LibQuestieDB.Quest.GetAllIds = function() return { 8101, 8102, 8103, 8104, 8105, 8106, 8107, 8108 } end
QuestieData:ResetPickups()
S.mapID, S.mapX, S.mapY = 1438, 0.58, 0.40
local startAreas = Pathwise.Data.StartAreas
Pathwise.Data.StartAreas = {}
Pathwise.charDB.questline = {}
local function Log(id, title) return { title = title, level = L, questID = id, objectives = { { text = "Beast slain: 0/5" } } } end

---------------------------------------------------------------------------
section("Questline: the next quest after a turn-in")

UpdateLog({ Log(8104, "Near Work") })
check("before: the next quest isn't suggested (far away, another zone)", Item("pickup:8102") == nil)
WoW.completedQuests[8101] = true
WoW.FireEvent("QUEST_TURNED_IN", 8101)
UpdateLog({ Log(8104, "Near Work") })
local nextPickup = Item("pickup:8102")
check("turned in: its follow-up to pick up, even in another zone", nextPickup ~= nil
  and nextPickup.priority == P.QUEST_CHAIN)
check("... before the work close by", Position("pickup:8102") < Position("quest:8104"))
local said = false
for _, line in ipairs(nextPickup and nextPickup.detail or {}) do
  said = said or line == Pathwise.L.QA_QUESTLINE_NEXT
end
check("... and says why", said)
-- A full log: still suggested (no other pickups then).
local full = { Log(8104, "Near Work") }
for i = 1, 10 do full[#full + 1] = Log(8200 + i, "Filler " .. i) end
UpdateLog(full)
check("a full log: the questline's next quest all the same", Item("pickup:8102") ~= nil and Item("pickup:8103") == nil)

---------------------------------------------------------------------------
section("Questline: the quest taken")

UpdateLog({ Log(8104, "Near Work"), Log(8105, "Unrelated Far") })
UpdateLog({ Log(8104, "Near Work"), Log(8105, "Unrelated Far"), Log(8102, "Chain Next") })
local chain, near, far = Item("quest:8102"), Item("quest:8104"), Item("quest:8105")
check("the follow-up taken: part of the questline", Pathwise.charDB.questline[8102] == true)
check("its step before the work close by (" .. tostring(chain and chain.priority) .. " vs "
  .. tostring(near and near.priority) .. ")", chain and near and chain.priority == P.QUEST_CHAIN
  and Position("quest:8102") < Position("quest:8104"))
check("a quest taken that doesn't follow on: as before", far and far.priority ~= P.QUEST_CHAIN
  and not Pathwise.charDB.questline[8105])
-- After a /reload: still the questline (saved).
UpdateLog({ Log(8104, "Near Work"), Log(8105, "Unrelated Far"), Log(8102, "Chain Next") })
check("on the next plan too", Item("quest:8102").priority == P.QUEST_CHAIN)

-- Turned in: the chain goes on with the next one.
WoW.completedQuests[8102] = true
WoW.FireEvent("QUEST_TURNED_IN", 8102)
UpdateLog({ Log(8104, "Near Work"), Log(8105, "Unrelated Far") })
check("turned in: no longer the questline; its follow-up is next", Pathwise.charDB.questline[8102] == nil
  and Item("pickup:8106") and Item("pickup:8106").priority == P.QUEST_CHAIN)
UpdateLog({ Log(8104, "Near Work"), Log(8105, "Unrelated Far"), Log(8106, "Chain Third") })
check("the third one taken: the questline goes on", Pathwise.charDB.questline[8106] == true)
WoW.FireEvent("QUEST_REMOVED", 8106)
check("abandoned: no longer the questline", Pathwise.charDB.questline[8106] == nil)

-- Long after the turn-in: a follow-up taken then is just a quest.
WoW.completedQuests[8102] = nil
Pathwise.charDB.questline = {}
UpdateLog({ Log(8104, "Near Work") })
WoW.now = WoW.now + QuestAdvisor.QUESTLINE_SECONDS + 60
UpdateLog({ Log(8104, "Near Work") })
check("long after the turn-in: its follow-up isn't pushed any more (an ordinary pickup at most)",
  Item("pickup:8102") == nil or Item("pickup:8102").priority ~= P.QUEST_CHAIN)
UpdateLog({ Log(8104, "Near Work"), Log(8102, "Chain Next") })
check("... and taken then, it's an ordinary quest", not Pathwise.charDB.questline[8102]
  and Item("quest:8102").priority ~= P.QUEST_CHAIN)

---------------------------------------------------------------------------
section("Questline: questing somewhere else")

-- Reported: Desolace's quests taken on purpose, and the guide still pulled
-- away to the questline's hard Sealed Folder in Hillsbrad.
Pathwise.charDB.questline = { [8102] = true }
UpdateLog({ Log(8104, "Near Work"), Log(8102, "Chain Next") })
check("one quest under way here: the questline still first", Item("quest:8102").priority == P.QUEST_CHAIN)
UpdateLog({ Log(8104, "Near Work"), Log(8107, "Near Work Two"), Log(8108, "Near Work Three"), Log(8102, "Chain Next") })
check("three quests under way here: the questline waits (" .. tostring(Item("quest:8102").priority) .. ")",
  Item("quest:8102").priority ~= P.QUEST_CHAIN and Pathwise.charDB.questline[8102] == true)
S.mapID, S.mapX, S.mapY = 1439, 0.40, 0.50
UpdateLog({ Log(8104, "Near Work"), Log(8107, "Near Work Two"), Log(8108, "Near Work Three"), Log(8102, "Chain Next") })
check("moved on (Darkshore): the questline first again", Item("quest:8102").priority == P.QUEST_CHAIN)
S.mapID, S.mapX, S.mapY = 1438, 0.58, 0.40
-- Next on the questline's step: it no longer comes first.
Pathwise:FireCallback("STEP_SKIPPED", "quest:8102")
WoW.RunTimers()
check("skipped with Next: no longer the questline", Pathwise.charDB.questline[8102] == nil)

-- Clean up
LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Quest.GetAllIds = questGet, npcGet, allIds
Pathwise.Data.StartAreas = startAreas
Pathwise.charDB.questline = {}
C_QuestLog = nil
WoW.completedQuests = {}
QuestieData:ResetPickups()
UpdateLog({})
