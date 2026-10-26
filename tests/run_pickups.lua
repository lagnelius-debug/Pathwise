-- Quests to pick up (QuestieDB) and the next-zone suggestion.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local NextSteps = Pathwise:GetModule("NextSteps")
local QuestieData = Pathwise:GetModule("QuestieData")
local P = NextSteps.PRIORITY

local function Strip(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end
local function Pickups()
  local ids = {}
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id:find("^pickup:") then ids[#ids + 1] = item.id:match("%d+") end
  end
  return table.concat(ids, ",")
end
local function UpdateLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

WoW.completedQuests = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return WoW.completedQuests[id] == true end }

local L = S.level -- quests at the player's level (not grey)
local HORDE, WARRIOR, HUNTER = 178, 1, 4
local quests = {
  [7001] = { name = "Near Quest", requiredLevel = 1, questLevel = L, startedBy = { { 9101 } } },
  [7002] = { name = "Horde Quest", requiredLevel = 1, questLevel = L, requiredRaces = HORDE, startedBy = { { 9101 } } },
  [7003] = { name = "Warrior Quest", requiredLevel = 1, questLevel = L, requiredClasses = WARRIOR, startedBy = { { 9101 } } },
  [7004] = { name = "Hunter Quest", requiredLevel = 1, questLevel = L, requiredClasses = HUNTER, zoneOrSort = -261,
    startedBy = { { 9102 } } },
  [7005] = { name = "Follow-up", requiredLevel = 1, questLevel = L, preQuestSingle = { 7001 }, startedBy = { { 9101 } } },
  [7006] = { name = "Repeatable", requiredLevel = 1, questLevel = L, specialFlags = 1, startedBy = { { 9101 } } },
  [7007] = { name = "Holiday", requiredLevel = 1, questLevel = L, zoneOrSort = -22, startedBy = { { 9101 } } },
  [7008] = { name = "Too High", requiredLevel = L + 3, questLevel = L + 3, startedBy = { { 9101 } } },
  [7009] = { name = "Grey", requiredLevel = 1, questLevel = 1, startedBy = { { 9101 } } },
  [7010] = { name = "From An Item", requiredLevel = 1, questLevel = L, startedBy = { nil, nil, { 1234 } } },
  [7011] = { name = "In The Log", requiredLevel = 1, questLevel = L, startedBy = { { 9101 } } },
  [7012] = { name = "Either This", requiredLevel = 1, questLevel = L, exclusiveTo = { 7001 }, startedBy = { { 9102 } } },
  [7013] = { name = "Wanted: Poster", requiredLevel = 1, questLevel = L, startedBy = { nil, { 9201 } } },
  [7014] = { name = "Far Quest", requiredLevel = 1, questLevel = L, startedBy = { { 9103 } } },
  [7016] = { name = "A Donation of Wool", requiredLevel = 1, questLevel = 60, startedBy = { { 9101 } } },
  [7015] = { name = "Earlier In Chain", requiredLevel = 1, questLevel = L, nextQuestInChain = 7011,
    startedBy = { { 9101 } } },
}
local npcs = {
  [9101] = { name = "Giver Near", spawns = { [141] = { { 58, 41 } } } },   -- 30 yd
  [9102] = { name = "Giver Mid", spawns = { [141] = { { 58, 45 } } } },    -- 150 yd
  [9103] = { name = "Giver Far", spawns = { [141] = { { 58, 70 } } } },    -- 900 yd
}
local objects = { [9201] = { name = "Wanted Poster", spawns = { [141] = { { 60, 40 } } } } } -- 60 yd

local questGet, npcGet, objectGet = LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Object.Get
LibQuestieDB.Quest.Get = function(id, key)
  if quests[id] then return quests[id][key] end
  return questGet(id, key)
end
LibQuestieDB.Npc.Get = function(id, key)
  if npcs[id] then return npcs[id][key] end
  return npcGet(id, key)
end
LibQuestieDB.Object.Get = function(id, key)
  if objects[id] then return objects[id][key] end
  return objectGet(id, key)
end
LibQuestieDB.Quest.GetAllIds = function()
  local ids = {}
  for id in pairs(quests) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end
QuestieData:ResetPickups()
S.mapID, S.mapX, S.mapY = 1438, 0.58, 0.40

---------------------------------------------------------------------------
section("Pickups: what's available")

UpdateLog({ { header = true, title = "Teldrassil" },
  { title = "In The Log", level = L, questID = 7011, objectives = { { text = "Thing: 0/5" } } } })
local ids = Pickups()
check("far too hard (red, like the level 60 cloth donations): not suggested", Item("pickup:7016") == nil)
check("only quests this hunter can pick up now, nearest first (max 4)", ids == "7001,7013,7012,7004", ids) -- 7012 and 7004: same giver, by name
local near = Item("pickup:7001")
check("pick up step with the giver, distance and arrow target",
  Strip(near.text):find("^Pick up: %[" .. L .. "%] Near Quest %- 27 m$") ~= nil
  and near.target.label == "Pick up: Near Quest (Giver Near)" and near.target.names[1] == "Giver Near"
  and near.subLines[1].text == "Get the quest from Giver Near" and near.priority == P.QUEST_NEAR)
check("object givers too (wanted posters)", Item("pickup:7013").detail[1] == "Quest from Wanted Poster."
  and Item("pickup:7013").target.names == nil)
check("the arrow follows the nearest pickup", Pathwise:GetModule("Waypoints"):GetTarget().label
  == "Pick up: Near Quest (Giver Near)")

-- Turning in Near Quest: its follow-up opens, the exclusive one closes
WoW.completedQuests[7001] = true
UpdateLog(WoW.questLog)
ids = Pickups()
check("prerequisite done: follow-up shows; exclusive quest gone", ids == "7005,7013,7004,7014", ids)
check("far pickups join the far route", Item("pickup:7014").priority == P.QUEST_FAR)

---------------------------------------------------------------------------
section("Pickups: next zone")

for id in pairs(quests) do WoW.completedQuests[id] = true end
UpdateLog({})
local zoneItem = Item("zone:next")
check("nothing left to pick up or do: suggests zones for the level", zoneItem ~= nil
  and Strip(zoneItem.text):find("^No quests left nearby: try ") ~= nil and zoneItem.priority == P.QUEST_ZONE
  and zoneItem.detail[1]:find("^Zones for your level: ") ~= nil, zoneItem and zoneItem.text)
check("not the zone you're in", not zoneItem.detail[1]:find("Teldrassil", 1, true))
UpdateLog({ { header = true, title = "Teldrassil" },
  { title = "Some Quest", level = L, questID = 7999, objectives = { { text = "Thing: 0/5" } } } })
check("with a quest to do: no zone suggestion", Item("zone:next") == nil)

---------------------------------------------------------------------------
section("Pickups: on/off")

WoW.completedQuests = {}
UpdateLog({})
check("pickups back", Pickups() ~= "")
WoW.ClearChat()
WoW.Slash("pickups off")
check("/pw pickups off", Pickups() == "" and Item("zone:next") == nil and WoW.ChatContains("no longer suggested"))
WoW.Slash("pickups on")
check("/pw pickups on", Pickups() ~= "")

---------------------------------------------------------------------------
section("Pickups: only quests that are really offered")

local function Has(id) return Item("pickup:" .. id) ~= nil end
UpdateLog({ { header = true, title = "Teldrassil" },
  { title = "In The Log", level = L, questID = 7011, objectives = { { text = "Thing: 0/5" } } } })
check("a later quest of its chain is in the log: not suggested", not Has(7015))

-- Reported in game: "Pick up: The Hunter's Path (Jocaste)", a quest that's
-- in the database but not in the game (Questie blacklists it). With the
-- Questie addon loaded, its own check decides.
QuestieLoader = { ImportModule = function(_, name)
  return { IsDoable = function(id) return id ~= 7001 end }
end }
UpdateLog(WoW.questLog)
check("Questie says it isn't doable: not suggested", not Has(7001) and Has(7013))
QuestieLoader = { ImportModule = function() return {} end } -- changed Questie: no IsDoable
UpdateLog(WoW.questLog)
check("Questie can't be asked: Pathwise's own rules", Has(7001))
QuestieLoader = nil

-- Talking to the giver: the gossip window lists everything they offer.
S.npcName = "Giver Near"
C_GossipInfo = { GetAvailableQuests = function() return { { title = "Something Else", questID = 7999 } } end }
WoW.ClearChat()
WoW.FireEvent("QUEST_DETAIL") -- one quest's window: not the full list, no conclusion
WoW.RunTimers()
check("a single quest window doesn't hide anything", Has(7001))
WoW.FireEvent("GOSSIP_SHOW")
WoW.RunTimers()
check("the giver doesn't offer it: not suggested again", not Has(7001)
  and Pathwise.charDB.notOffered[7001] == S.level and Has(7013))
S.npcName = "Giver Mid"
C_GossipInfo = { GetAvailableQuests = function() return { { title = "Hunter Quest" }, { title = "Either This" } } end }
WoW.FireEvent("GOSSIP_SHOW")
WoW.RunTimers()
check("offered quests (matched by title) stay", Has(7004) and Has(7012))
S.npcName, C_GossipInfo = nil, nil
Pathwise.charDB.notOffered[7001] = S.level - 1 -- as if seen a level ago
UpdateLog(WoW.questLog)
check("after a level up it's tried again", Has(7001))
Pathwise.charDB.notOffered = {}

-- Without a scannable QuestieDB: no pickups and no zone guesses
LibQuestieDB.Quest.GetAllIds = nil
QuestieData:ResetPickups()
UpdateLog({})
check("old QuestieDB: no pickups, no zone suggestion", Pickups() == "" and Item("zone:next") == nil)

-- Clean up for later tests
LibQuestieDB.Quest.Get, LibQuestieDB.Npc.Get, LibQuestieDB.Object.Get = questGet, npcGet, objectGet
C_QuestLog = nil
QuestieData:ResetPickups()
UpdateLog({})
