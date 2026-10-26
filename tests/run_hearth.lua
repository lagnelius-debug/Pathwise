-- Hearthstone tip: set it where you're questing.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Hearthstone = Pathwise:GetModule("Hearthstone")
local P = Pathwise:GetModule("NextSteps").PRIORITY

local bindName = "Dolanaar"
function GetBindLocation() return bindName end
local function At(mapID, x, y, zone, subZone)
  S.mapID, S.mapX, S.mapY = mapID, x, y
  S.zone, S.subZone = zone, subZone
  WoW.FireEvent("ZONE_CHANGED")
  WoW.RunTimers()
end
-- Quest steps in Darkshore (what QuestAdvisor planned)
local function Steps(n, mapID)
  local items = {}
  for i = 1, n do
    items[i] = { id = "quest:" .. i, kind = "do", target = { mapID = mapID or 1439, x = 0.4, y = 0.3 + i / 100 } }
  end
  return items
end

-- QuestieDB knows the innkeeper in Auberdine
local npcGet = LibQuestieDB.Npc.Get
LibQuestieDB.Npc.Get = function(id, key)
  if id == 9401 then
    return ({ name = "Innkeeper Shaussiy", subName = "Innkeeper", friendlyToFaction = "A",
      spawns = { [148] = { { 37, 44 } } } })[key]
  end
  return npcGet(id, key)
end
LibQuestieDB.Npc.GetAllIds = function() return { 9401 } end
Pathwise:GetModule("QuestieData"):ResetTrainers()
Pathwise:GetModule("QuestieData"):TrainersReady()
WoW.RunTimers()

---------------------------------------------------------------------------
section("Hearthstone: where it's set")

Pathwise.charDB.bind = {}
At(1439, 0.40, 0.60, "Darkshore", "Bashal'Aran")
check("bind location unknown: no tip, even with lots to do", Hearthstone:BuildItem(Steps(6)) == nil)
At(1438, 0.55, 0.57, "Teldrassil", "Dolanaar")
Hearthstone:BuildItem({})
check("passing through the town it's set to: learned", Pathwise.charDB.bind.mapID == 1438
  and Pathwise.charDB.bind.name == "Dolanaar")

---------------------------------------------------------------------------
section("Hearthstone: the tip")

At(1439, 0.40, 0.70, "Darkshore", "Bashal'Aran")
local item = Hearthstone:BuildItem(Steps(4))
check("4 quest steps here, hearthstone in Teldrassil: suggest moving it", item
  and item.text:find("^Set your hearthstone in .+: talk to Innkeeper Shaussiy$") ~= nil -- (zone name from the client)
  and item.priority == P.HEARTH)
check("arrow to the innkeeper, what to say, and why", item.target.names[1] == "Innkeeper Shaussiy"
  and item.subLines[1].text:find("Make this inn your home", 1, true) and item.detail[1]:find("set to Dolanaar", 1, true))
check("fewer steps: not worth it", Hearthstone:BuildItem(Steps(3)) == nil)
check("steps elsewhere don't count", Hearthstone:BuildItem(Steps(6, 1438)) == nil)
check("a combined step counts each quest", Hearthstone:BuildItem({ { id = "quest:1+quest:2+quest:3+quest:4", kind = "do",
  target = { mapID = 1439, x = 0.4, y = 0.4 } } }) ~= nil)
At(1439, 0.37, 0.45, "Darkshore", "Auberdine")
check("passing by the inn: now", Hearthstone:BuildItem(Steps(4)).priority == P.QUEST_NEAR)

-- Set at the inn: the tip goes away
bindName = "Auberdine"
WoW.FireEvent("HEARTHSTONE_BOUND")
WoW.RunTimers()
check("set here: learned and no tip", Pathwise.charDB.bind.mapID == 1439 and Hearthstone:BuildItem(Steps(6)) == nil)

-- Using the hearthstone: wherever you arrive is where it's set
bindName = "Dolanaar"
Pathwise.charDB.bind = {}
WoW.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 8690)
At(1438, 0.55, 0.57, "Teldrassil", "Shadowglen") -- (not the town's name)
WoW.RunTimers()
check("after hearthing: the arrival zone", Pathwise.charDB.bind.mapID == 1438)

-- To another continent: a loading screen; the map counts only after it
Pathwise.charDB.bind = {}
S.mapID, S.mapX, S.mapY = 1439, 0.4, 0.7
WoW.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 556) -- Astral Recall counts too
WoW.FireEvent("LOADING_SCREEN_ENABLED")
S.mapID = 1438 -- (the client may still say anything while loading)
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, false)
WoW.RunTimers()
check("after a loading screen: recorded once in the world", Pathwise.charDB.bind.mapID == 1438)

-- QuestieDB knows no inn in the zone: no tip (rather than "an inn" that isn't there)
Pathwise.charDB.bind = { name = "Dolanaar", mapID = 1438 }
At(1440, 0.5, 0.5, "Ashenvale", "Astranaar")
check("no friendly inn in this zone: no tip", Hearthstone:BuildItem(Steps(6, 1440)) == nil)

---------------------------------------------------------------------------
section("Hearthstone: on/off")

At(1439, 0.40, 0.70, "Darkshore", "Bashal'Aran")
WoW.ClearChat()
WoW.Slash("hearth off")
check("/pw hearth off", Hearthstone:BuildItem(Steps(6)) == nil and WoW.ChatContains("Hearthstone tips are off"))
WoW.Slash("hearth on")
check("/pw hearth on", Hearthstone:BuildItem(Steps(6)) ~= nil)

-- A module switched off in the saved settings reacts to nothing
local function HasHearth()
  for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
    if item.id == "hearth" then return true end
  end
  return false
end
Pathwise.charDB.bind = { name = "Dolanaar", mapID = 1438 }
At(1439, 0.40, 0.70, "Darkshore", "Bashal'Aran")
Pathwise:FireCallback("QUESTS_PLANNED", Steps(6))
check("module on: the tip is in the To-do list", HasHearth())
Pathwise.db.modules.Hearthstone = false
Pathwise:GetModule("NextSteps"):SetItems("hearth", {})
Pathwise:FireCallback("QUESTS_PLANNED", Steps(6))
check("module switched off: callbacks don't reach it", not HasHearth())
Pathwise.db.modules.Hearthstone = nil
Pathwise:GetModule("NextSteps"):SetItems("hearth", {})

-- Clean up
LibQuestieDB.Npc.Get, LibQuestieDB.Npc.GetAllIds = npcGet, nil
Pathwise:GetModule("QuestieData"):ResetTrainers()
GetBindLocation = nil
Pathwise.charDB.bind = {}
At(1438, 0.58, 0.40, "Teldrassil", "Aldrassil")
