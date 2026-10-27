local addonName, Pathwise = ...

-- Platform layer for WoW Classic Era (vanilla 1-60).
--
-- This is the ONLY file that calls flavor-specific WoW API. Everything here
-- returns plain Lua values/tables in Pathwise's own format, so Core never has
-- to know which client it is running in. A future Platform_Forever.lua must
-- implement the same functions.
--
-- Where an API might not exist (or behaves differently between client
-- builds), check at runtime instead of assuming.

local Platform = {}
Pathwise.Platform = Platform

Platform.flavor = "Classic"

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
  Pathwise:DispatchEvent(event, ...)
end)

-- Returns true on success. Registering an event the client doesn't know
-- throws an error in current clients, so it's wrapped in pcall: callers can
-- then fall back gracefully if an event doesn't exist in this flavor.
function Platform.RegisterEvent(event)
  local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
  return ok
end

function Platform.UnregisterEvent(event)
  pcall(eventFrame.UnregisterEvent, eventFrame, event)
end

---------------------------------------------------------------------------
-- Output and timers
---------------------------------------------------------------------------

function Platform.Print(message)
  DEFAULT_CHAT_FRAME:AddMessage(message)
end

-- Runs fn after `seconds`. C_Timer exists in Classic Era, but fall back to an
-- OnUpdate frame just in case.
local pendingTimers = {}
local timerFrame
function Platform.After(seconds, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(seconds, fn)
    return
  end
  if not timerFrame then
    timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
      for i = #pendingTimers, 1, -1 do
        local timer = pendingTimers[i]
        timer.remaining = timer.remaining - elapsed
        if timer.remaining <= 0 then
          table.remove(pendingTimers, i)
          timer.fn()
        end
      end
      if #pendingTimers == 0 then
        self:Hide()
      end
    end)
  end
  pendingTimers[#pendingTimers + 1] = { remaining = seconds, fn = fn }
  timerFrame:Show()
end

-- Calls fn(...) and returns true on success. On error, the error goes to
-- WoW's error handler (the scriptErrors popup, or BugSack if installed) and
-- false is returned, so the caller can carry on. Lua 5.1's xpcall doesn't
-- forward arguments, hence the closure.
function Platform.SafeCall(fn, ...)
  local n, args = select("#", ...), { ... }
  return xpcall(function()
    return fn(unpack(args, 1, n))
  end, geterrorhandler())
end

-- Runs fn every `seconds` until the game ends. C_Timer.NewTicker exists in
-- Classic Era; fall back to chained Platform.After just in case.
function Platform.Every(seconds, fn)
  if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(seconds, fn)
    return
  end
  local function Tick()
    fn()
    Platform.After(seconds, Tick)
  end
  Platform.After(seconds, Tick)
end

-- Seconds since an arbitrary start, with sub-second precision.
function Platform.GetTime()
  return GetTime()
end

function Platform.InCombat()
  if InCombatLockdown then
    return InCombatLockdown() and true or false
  end
  return UnitAffectingCombat("player") and true or false
end

---------------------------------------------------------------------------
-- Client / addon info
---------------------------------------------------------------------------

-- Returns { version = "1.15.9", build = "12345", interface = 11509 }
function Platform.GetClientInfo()
  local version, build, _, interface = GetBuildInfo()
  return { version = version, build = build, interface = interface }
end

-- Metadata moved to C_AddOns in newer clients; the global may or may not
-- still exist depending on the Classic Era build.
function Platform.GetAddOnMetadata(field)
  local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  if getMetadata then
    return getMetadata(addonName, field)
  end
end

---------------------------------------------------------------------------
-- Character
---------------------------------------------------------------------------

-- Returns identity info. Tokens (class, race, faction) are locale-independent;
-- the *Localized fields are for display only.
function Platform.GetPlayerInfo()
  local classLocalized, class, classID = UnitClass("player")
  local raceLocalized, race, raceID = UnitRace("player")
  local faction, factionLocalized = UnitFactionGroup("player")
  return {
    name = UnitName("player"),
    realm = GetRealmName(),
    class = class,
    classID = classID,
    classLocalized = classLocalized,
    race = race,
    raceID = raceID,
    raceLocalized = raceLocalized,
    faction = faction,
    factionLocalized = factionLocalized,
  }
end

function Platform.GetLevel()
  return UnitLevel("player")
end

function Platform.GetMaxLevel()
  if GetMaxPlayerLevel then
    return GetMaxPlayerLevel()
  end
  return MAX_PLAYER_LEVEL or 60
end

-- Returns xp, xpMax, rested. GetXPExhaustion() returns nil when the player
-- has no rested XP.
function Platform.GetXP()
  return UnitXP("player"), UnitXPMax("player"), GetXPExhaustion() or 0
end

-- Returns { zone, subZone, mapID }. mapID is nil if C_Map is unavailable.
function Platform.GetZone()
  local mapID
  if C_Map and C_Map.GetBestMapForUnit then
    mapID = C_Map.GetBestMapForUnit("player")
  end
  return {
    zone = GetRealZoneText(),
    subZone = GetSubZoneText(),
    mapID = mapID,
  }
end

---------------------------------------------------------------------------
-- Equipment
---------------------------------------------------------------------------

-- Equipment slots in display order. Classic Era still has the ammo slot,
-- which is inventory slot 0 (INVSLOT_AMMO). Verified in game (1.15.9):
-- GetInventoryItemID("player", 0) returns the ammo's item ID, but
-- GetInventoryItemLink("player", 0) returns nil, so the link is looked up
-- from the item ID instead (see GetEquippedItems).
local EQUIPMENT_SLOTS = {
  { id = 1, key = "HEAD" },
  { id = 2, key = "NECK" },
  { id = 3, key = "SHOULDER" },
  { id = 15, key = "BACK" },
  { id = 5, key = "CHEST" },
  { id = 4, key = "SHIRT" },
  { id = 19, key = "TABARD" },
  { id = 9, key = "WRIST" },
  { id = 10, key = "HANDS" },
  { id = 6, key = "WAIST" },
  { id = 7, key = "LEGS" },
  { id = 8, key = "FEET" },
  { id = 11, key = "FINGER1" },
  { id = 12, key = "FINGER2" },
  { id = 13, key = "TRINKET1" },
  { id = 14, key = "TRINKET2" },
  { id = 16, key = "MAINHAND" },
  { id = 17, key = "OFFHAND" },
  { id = 18, key = "RANGED" },
  { id = INVSLOT_AMMO or 0, key = "AMMO" },
}

-- Returns the ordered slot list: { { id = 1, key = "HEAD" }, ... }
function Platform.GetEquipmentSlots()
  return EQUIPMENT_SLOTS
end

-- Pulls itemID and name out of an item link like
-- |cff9d9d9d|Hitem:7073:0:0:0|h[Broken Fang]|h|r
function Platform.ParseItemLink(link)
  if not link then
    return nil
  end
  local itemID = tonumber(link:match("item:(%d+)"))
  local name = link:match("|h%[(.-)%]|h")
  return itemID, name
end

-- GetItemInfo moved to C_Item in newer clients; check which one exists.
-- Returns name, link, or nil if the item isn't cached yet (the call also asks
-- the server for it, so a later retry usually succeeds).
local function GetItemNameAndLink(itemID)
  local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getItemInfo then
    local name, link = getItemInfo(itemID)
    return name, link
  end
end

-- Returns { [slotId] = { slot, slotKey, itemID, link, name, pending } } for
-- every occupied slot. `pending` means the client knows the item ID but has
-- no link yet (item data not cached); ask again a bit later.
function Platform.GetEquippedItems()
  local items = {}
  for _, slot in ipairs(EQUIPMENT_SLOTS) do
    local itemID = GetInventoryItemID("player", slot.id)
    local link = GetInventoryItemLink("player", slot.id)
    if itemID and not link then
      -- Always the case for the ammo slot; can also happen for uncached items.
      local _
      _, link = GetItemNameAndLink(itemID)
    end
    if itemID or link then
      local linkID, name = Platform.ParseItemLink(link)
      items[slot.id] = {
        slot = slot.id,
        slotKey = slot.key,
        itemID = itemID or linkID,
        link = link,
        name = name,
        pending = link == nil,
      }
    end
  end
  return items
end

---------------------------------------------------------------------------
-- Talents
---------------------------------------------------------------------------

-- GetTalentTabInfo's return order differs between client generations: the
-- vanilla-style API returns (name, icon, pointsSpent, fileName); later Classic
-- versions return (id, name, ...). Detect at runtime.
local function GetTalentTabName(tab)
  local first, second = GetTalentTabInfo(tab)
  if type(first) == "number" then
    return second
  end
  return first
end

-- Returns a list of trees in tab order:
-- { { index, name, points, talents = { { index, name, tier, column, rank, maxRank } } } }
-- Points are summed from talent ranks rather than read from GetTalentTabInfo,
-- so we don't depend on that function's return order.
function Platform.GetTalentTrees()
  local trees = {}
  if not (GetNumTalentTabs and GetTalentInfo) then
    return trees
  end
  for tab = 1, GetNumTalentTabs() do
    local tree = { index = tab, name = GetTalentTabName(tab), points = 0, talents = {} }
    for i = 1, GetNumTalents(tab) or 0 do
      -- Vanilla-style returns: name, icon, tier, column, rank, maxRank, ...
      local name, _, tier, column, rank, maxRank = GetTalentInfo(tab, i)
      if name then
        rank = rank or 0
        tree.talents[#tree.talents + 1] = {
          index = i,
          name = name,
          tier = tier,
          column = column,
          rank = rank,
          maxRank = maxRank or 0,
        }
        tree.points = tree.points + rank
      end
    end
    trees[tab] = tree
  end
  return trees
end

-- Unspent talent points, or nil if the client can't tell us (Core then
-- computes it from level). In Classic Era UnitCharacterPoints("player")
-- returns the unspent talent points. TODO verify
function Platform.GetUnspentTalentPoints()
  if UnitCharacterPoints then
    local points = UnitCharacterPoints("player")
    if type(points) == "number" then
      return points
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- Skills (professions, weapon skills, ...)
---------------------------------------------------------------------------

-- Returns skills, collapsedHeaders.
-- skills: { { name, rank, maxRank, modifier, header, isAbandonable } }
-- Headers ("Professions", "Weapon Skills", ...) are localized display text.
-- Primary professions are the abandonable ones. Skills under a header the
-- player collapsed in the skill frame are not returned by the API; those
-- header names are listed in collapsedHeaders. We don't expand them because
-- that would change the player's UI state.
function Platform.GetSkills()
  local skills, collapsedHeaders = {}, {}
  if not (GetNumSkillLines and GetSkillLineInfo) then
    return skills, collapsedHeaders
  end
  local header
  for i = 1, GetNumSkillLines() do
    local name, isHeader, isExpanded, rank, _, modifier, maxRank, isAbandonable = GetSkillLineInfo(i)
    if isHeader then
      header = name
      if not isExpanded then
        collapsedHeaders[#collapsedHeaders + 1] = name
      end
    elseif name then
      skills[#skills + 1] = {
        name = name,
        rank = rank or 0,
        maxRank = maxRank or 0,
        modifier = modifier or 0,
        header = header,
        isAbandonable = isAbandonable and true or false,
      }
    end
  end
  return skills, collapsedHeaders
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

-- Item class IDs (GetItemInfo returns 12/13). These numbers are the same in
-- every current client.
Platform.ITEM_CLASS_WEAPON = 2
Platform.ITEM_CLASS_ARMOR = 4

-- Inventory type -> equipment slots it can go in. Classic Era has a ranged
-- slot (18) for bows, guns, crossbows, wands and thrown weapons.
local EQUIP_LOC_SLOTS = {
  INVTYPE_HEAD = { 1 },
  INVTYPE_NECK = { 2 },
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_WEAPON = { 16, 17 }, -- one-hand: off hand only with dual wield
  INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 },
  INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 },
  INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 },
}

local RANGED_EQUIP_LOCS = {
  INVTYPE_RANGED = true,
  INVTYPE_RANGEDRIGHT = true,
  INVTYPE_THROWN = true,
}

Platform.SLOT_MAINHAND = 16
Platform.SLOT_OFFHAND = 17

-- Returns item info as a table, or nil if the item isn't cached yet (the
-- request also asks the server for it; GET_ITEM_INFO_RECEIVED fires later).
-- slots is nil for items that don't go in a scored equipment slot (shirts,
-- tabards, bags, ammo, ...).
function Platform.GetItemInfo(item)
  local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getItemInfo or not item then
    return nil
  end
  local name, link, quality, itemLevel, minLevel, _, subTypeName, _, equipLoc, _, sellPrice, classID, subclassID =
    getItemInfo(item)
  if not name then
    return nil
  end
  return {
    itemID = Platform.ParseItemLink(link),
    name = name,
    link = link,
    quality = quality,
    itemLevel = itemLevel,
    minLevel = minLevel or 0,
    subTypeName = subTypeName,
    equipLoc = equipLoc,
    sellPrice = sellPrice or 0,
    classID = classID,
    subclassID = subclassID,
    slots = EQUIP_LOC_SLOTS[equipLoc],
    isRanged = RANGED_EQUIP_LOCS[equipLoc] or false,
    isTwoHand = equipLoc == "INVTYPE_2HWEAPON",
  }
end

-- Returns { [statKey] = value } for an item link, or nil if not available.
-- Keys are the locale-independent global string names, e.g.
-- ITEM_MOD_AGILITY_SHORT, RESISTANCE0_NAME (armor) and
-- ITEM_MOD_DAMAGE_PER_SECOND_SHORT (weapon DPS). TODO verify that Classic Era
-- reports armor and weapon DPS through GetItemStats.
function Platform.GetItemStats(link)
  local getItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
  if not getItemStats or not link then
    return nil
  end
  local stats = getItemStats(link)
  if not stats then
    return nil
  end
  local copy = {}
  for key, value in pairs(stats) do
    copy[key] = value
  end
  return copy
end

---------------------------------------------------------------------------
-- Quest rewards
---------------------------------------------------------------------------

-- Returns the reward choices of the quest being turned in (QUEST_COMPLETE):
-- { { index, link, name, count } }. link can be nil while the item isn't
-- cached yet.
function Platform.GetQuestRewardChoices()
  local choices = {}
  for i = 1, (GetNumQuestChoices and GetNumQuestChoices() or 0) do
    local name, _, count = GetQuestItemInfo("choice", i)
    choices[i] = {
      index = i,
      link = GetQuestItemLink("choice", i),
      name = name,
      count = count or 1,
    }
  end
  return choices
end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

-- True if the player knows the spell. In Classic Era both checks are
-- needed: IsSpellKnown misses some spells (e.g. talent-granted ranks) that
-- IsPlayerSpell reports, and vice versa. Note: learning a higher rank can
-- make lower ranks report as unknown; Core handles that through rank chains.
function Platform.IsSpellKnown(spellID)
  if IsSpellKnown and IsSpellKnown(spellID) then
    return true
  end
  if IsPlayerSpell and IsPlayerSpell(spellID) then
    return true
  end
  return false
end

-- Returns name, rankText ("Rank 2" or nil), icon for a spell ID, or nil if
-- the client doesn't know the ID. Newer clients return a table from
-- C_Spell.GetSpellInfo; older ones return values from GetSpellInfo.
-- A spell's name (no rank), or nil.
function Platform.GetSpellName(spellID)
  if GetSpellInfo then
    return (GetSpellInfo(spellID))
  elseif C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(spellID)
  end
end

function Platform.GetSpellDisplay(spellID)
  local name, icon
  if GetSpellInfo then
    local _
    name, _, icon = GetSpellInfo(spellID)
  elseif C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info then
      name, icon = info.name, info.iconID
    end
  end
  if not name then
    return nil
  end
  local subtext
  local getSubtext = GetSpellSubtext or (C_Spell and C_Spell.GetSpellSubtext)
  if getSubtext then
    subtext = getSubtext(spellID)
    if subtext == "" then
      subtext = nil
    end
  end
  return name, subtext, icon
end

---------------------------------------------------------------------------
-- Quest log
---------------------------------------------------------------------------

-- Parses "Webwood Venom Sac: 6/10" into 6, 10.
local function ParseProgress(text)
  local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
  return tonumber(have), tonumber(need)
end

local function GetObjectives(logIndex, questID)
  local objectives = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives and questID then
    for i, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
      objectives[i] = {
        text = objective.text,
        finished = objective.finished and true or false,
        have = objective.numFulfilled,
        need = objective.numRequired,
      }
    end
    return objectives
  end
  for i = 1, (GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(logIndex) or 0) do
    local text, _, finished = GetQuestLogLeaderBoard(i, logIndex)
    local have, need = ParseProgress(text)
    objectives[i] = { text = text, finished = finished and true or false, have = have, need = need }
  end
  return objectives
end

-- Returns quests, collapsedHeaders.
-- quests: { { questID, title, level, zone, suggestedGroup, complete,
--             failed, objectives = { { text, finished, have, need } } } }
-- zone is the quest log header the quest is listed under (localized; usually
-- the zone name). Quests under a header the player collapsed are not
-- returned by the API; we don't expand headers because that would change
-- the player's quest log.
--
-- Classic Era: GetQuestLogTitle returns title, level, suggestedGroup,
-- isHeader, isCollapsed, isComplete (1 = complete, -1 = failed), frequency,
-- questID.
function Platform.GetQuestLog()
  local quests, collapsedHeaders = {}, {}
  if not (GetNumQuestLogEntries and GetQuestLogTitle) then
    return quests, collapsedHeaders
  end
  local zone
  for i = 1, GetNumQuestLogEntries() do
    local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, _, questID = GetQuestLogTitle(i)
    if isHeader then
      zone = title
      if isCollapsed then
        collapsedHeaders[#collapsedHeaders + 1] = title
      end
    elseif title then
      quests[#quests + 1] = {
        logIndex = i,
        questID = questID,
        title = title,
        level = level or 0,
        zone = zone,
        suggestedGroup = tonumber(suggestedGroup) or 0,
        complete = isComplete == 1 or isComplete == true,
        failed = isComplete == -1,
        objectives = GetObjectives(i, questID),
      }
    end
  end
  return quests, collapsedHeaders
end

-- Highest quest level below the player's that still gives decent XP is
-- playerLevel - greenRange; anything lower is grey. Uses the client's value
-- when available. TODO verify the fallback against Classic Era.
function Platform.GetQuestGreenRange(playerLevel)
  if GetQuestGreenRange then
    local range = GetQuestGreenRange()
    if type(range) == "number" then
      return range
    end
  end
  if playerLevel <= 9 then
    return 4
  elseif playerLevel <= 19 then
    return 5
  elseif playerLevel <= 29 then
    return 6
  elseif playerLevel <= 39 then
    return 7
  end
  return 8
end

---------------------------------------------------------------------------
-- Map position and facing (navigation arrow)
---------------------------------------------------------------------------

-- Returns mapID, x, y (0..1) of the player on the best map for their
-- location, or nil where the client hides the position (e.g. instances).
function Platform.GetPlayerMapPosition()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
    return nil
  end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then
    return nil
  end
  local position = C_Map.GetPlayerMapPosition(mapID, "player")
  if not position then
    return nil
  end
  local x, y = position:GetXY()
  if not x or (x == 0 and y == 0) then
    return nil
  end
  return mapID, x, y
end

-- Player facing in radians, counterclockwise from north; nil if unavailable.
function Platform.GetPlayerFacing()
  if GetPlayerFacing then
    return GetPlayerFacing()
  end
end

-- World-space rectangle of a map, in yards: { continent, top, left, bottom,
-- right }. World coordinates grow towards north (top) and west (left), so
-- top > bottom and left > right. Cached; nil if the API is missing.
local mapRects = {}
function Platform.GetMapWorldRect(mapID)
  if mapRects[mapID] ~= nil then
    return mapRects[mapID] or nil
  end
  local rect = false
  if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local continent, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
    local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
    if topLeft and bottomRight then
      local top, left = topLeft:GetXY()
      local bottom, right = bottomRight:GetXY()
      rect = { continent = continent, top = top, left = left, bottom = bottom, right = right }
    end
  end
  mapRects[mapID] = rect
  return rect or nil
end

-- The quests the NPC the player is talking to offers, as { title,
-- questID (when the client says) }, or nil when the window doesn't list
-- them all. Only the gossip window (GOSSIP_SHOW) and the quest greeting
-- (QUEST_GREETING) list every available quest; a quest detail window shows
-- just one.
function Platform.GetOfferedQuests(event)
  local offered = {}
  if event == "GOSSIP_SHOW" then
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
      for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        offered[#offered + 1] = { title = info.title, questID = info.questID }
      end
    elseif GetGossipAvailableQuests then
      -- Older clients: title, level, flags... per quest; only titles are strings.
      for _, value in ipairs({ GetGossipAvailableQuests() }) do
        if type(value) == "string" then
          offered[#offered + 1] = { title = value }
        end
      end
    else
      return nil
    end
  elseif event == "QUEST_GREETING" then
    if not (GetNumAvailableQuests and GetAvailableTitle) then
      return nil
    end
    for i = 1, GetNumAvailableQuests() do
      offered[#offered + 1] = { title = GetAvailableTitle(i) }
    end
  else
    return nil
  end
  return offered
end

-- The flight points on the open flight map (TAXIMAP_OPENED): list of
-- { name = "Rut'theran Village, Teldrassil", state = "CURRENT" |
-- "REACHABLE" | ..., x, y } (x, y: position on the flight map, 0-1, which
-- shows the continent). Empty when no flight map is open.
function Platform.GetTaxiNodes()
  local nodes = {}
  if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then
    return nodes
  end
  for i = 1, NumTaxiNodes() or 0 do
    local x, y
    if TaxiNodePosition then
      x, y = TaxiNodePosition(i)
    end
    nodes[#nodes + 1] = { name = TaxiNodeName(i), state = TaxiNodeGetType(i), x = x, y = y }
  end
  return nodes
end

-- Where the hearthstone is set: the town's name (e.g. "Dolanaar"), or nil.
function Platform.GetBindLocation()
  return GetBindLocation and GetBindLocation() or nil
end

-- The Hearthstone spell (cast when the item is used).
Platform.HEARTHSTONE_SPELL = 8690

-- True while the player is on a flight.
function Platform.IsOnTaxi()
  return UnitOnTaxi and UnitOnTaxi("player") and true or false
end

-- Name of the NPC the player is talking to (quest giver dialogs), or nil.
function Platform.GetInteractionNPCName()
  if UnitExists("npc") then
    return UnitName("npc")
  end
end

function Platform.GetMapName(mapID)
  if C_Map and C_Map.GetMapInfo then
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name
  end
end

---------------------------------------------------------------------------
-- Macros
---------------------------------------------------------------------------

-- Creates or updates a character-specific macro. Returns true, or false and
-- a reason: "combat" (macros can't be changed in combat), "full" (no free
-- character macro slot) or "api" (macro functions missing).
function Platform.SetMacro(name, icon, body)
  if not (GetMacroIndexByName and CreateMacro and EditMacro) then
    return false, "api"
  end
  if Platform.InCombat() then
    return false, "combat"
  end
  local index = GetMacroIndexByName(name)
  if index and index > 0 then
    EditMacro(index, name, icon, body)
    return true
  end
  local _, numCharacter = GetNumMacros()
  if numCharacter >= (MAX_CHARACTER_MACROS or 18) then
    return false, "full"
  end
  index = CreateMacro(name, icon, body, true)
  return index ~= nil and index > 0, "api"
end

-- Puts the macro on the cursor so the player can drop it on an action bar.
function Platform.PickupMacro(name)
  local index = GetMacroIndexByName and GetMacroIndexByName(name)
  if index and index > 0 and not Platform.InCombat() then
    PickupMacro(index)
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Bag items and units (professions)
---------------------------------------------------------------------------

-- True if the character has turned in quest questID at some point.
function Platform.IsQuestCompleted(questID)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
  elseif IsQuestFlaggedCompleted then
    return IsQuestFlaggedCompleted(questID) and true or false
  end
  return false
end

-- How many of an item the player has in the bags.
function Platform.GetItemCount(itemID)
  local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID))
    or (GetItemCount and GetItemCount(itemID))
  return count or 0
end

-- { level, creatureType, isPlayer } for a unit, or nil. creatureType is the
-- client's (localized) name, e.g. "Beast"; level -1 means "??".
function Platform.GetUnitCreature(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  return {
    level = UnitLevel(unit),
    creatureType = UnitCreatureType and UnitCreatureType(unit),
    isPlayer = UnitIsPlayer and UnitIsPlayer(unit) and true or false,
  }
end

---------------------------------------------------------------------------
-- Hunter: ammo and pet
---------------------------------------------------------------------------

-- Returns count, itemID of the equipped ammo (0, nil if none). For the ammo
-- slot, GetInventoryItemCount counts that ammo in all bags and quivers.
function Platform.GetAmmo()
  local slot = INVSLOT_AMMO or 0
  local itemID = GetInventoryItemID("player", slot)
  if not itemID then
    return 0, nil
  end
  return GetInventoryItemCount("player", slot) or 0, itemID
end

-- Returns { name, happiness, foodTypes } for the player's hunter pet, or nil
-- when there is none. happiness: 1 = unhappy, 2 = content, 3 = happy.
-- foodTypes: localized diet names ("Meat", "Fish", ...).
function Platform.GetHunterPet()
  if not UnitExists("pet") then
    return nil
  end
  if HasPetUI then
    local hasUI, isHunterPet = HasPetUI()
    if not hasUI or not isHunterPet then
      return nil
    end
  end
  local happiness = GetPetHappiness and GetPetHappiness()
  local foodTypes = {}
  if GetPetFoodTypes then
    foodTypes = { GetPetFoodTypes() }
  end
  local family, familyID = UnitCreatureFamily and UnitCreatureFamily("pet")
  return {
    name = UnitName("pet"),
    happiness = happiness,
    foodTypes = foodTypes,
    level = UnitLevel("pet"),
    family = family, -- localized name, e.g. "Cat"
    familyID = type(familyID) == "number" and familyID or nil, -- only where the client gives it
  }
end

local function RankNumber(text)
  return tonumber(text and text:match("(%d+)"))
end

-- The pet's spells from its spellbook: list of { spellID, name, rank }.
function Platform.GetPetSpells()
  local spells = {}
  local count = HasPetSpells and HasPetSpells()
  if not count or count == 0 then
    return spells
  end
  local book = BOOKTYPE_PET or "pet"
  for i = 1, count do
    local spellID
    if GetSpellBookItemInfo then
      local _, id = GetSpellBookItemInfo(i, book)
      spellID = id
    end
    local name, subText
    if GetSpellBookItemName then
      name, subText = GetSpellBookItemName(i, book)
    elseif GetSpellName then
      name, subText = GetSpellName(i, book)
    end
    if name or spellID then
      spells[#spells + 1] = { spellID = spellID, name = name, rank = RankNumber(subText) }
    end
  end
  return spells
end

-- The abilities in the open Beast Training window (the hunter's learned pet
-- abilities): list of { name, rank, level, cost }, or nil when no Beast
-- Training window is open.
function Platform.GetBeastTraining()
  if not (GetNumCrafts and GetCraftInfo) then
    return nil
  end
  if GetCraftDisplaySkillLine then
    local skill = GetCraftDisplaySkillLine()
    if skill and skill ~= (BEAST_TRAINING or "Beast Training") then
      return nil -- another craft window (Enchanting)
    end
  end
  local list = {}
  for i = 1, GetNumCrafts() or 0 do
    local name, subName, craftType, _, _, cost, level = GetCraftInfo(i)
    if name and craftType ~= "header" then
      list[#list + 1] = { name = name, rank = RankNumber(subName), level = level, cost = cost }
    end
  end
  return list
end
