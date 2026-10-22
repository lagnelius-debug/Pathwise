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
  local classLocalized, class = UnitClass("player")
  local raceLocalized, race = UnitRace("player")
  local faction, factionLocalized = UnitFactionGroup("player")
  return {
    name = UnitName("player"),
    realm = GetRealmName(),
    class = class,
    classLocalized = classLocalized,
    race = race,
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
-- which is inventory slot 0 (INVSLOT_AMMO). TODO verify that
-- GetInventoryItemLink("player", 0) returns the equipped ammo.
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

-- Returns { [slotId] = { slot, slotKey, itemID, link, name, pending } } for
-- every occupied slot. `pending` means the client knows the item ID but has
-- not built the link yet (item data not cached); ask again a bit later.
function Platform.GetEquippedItems()
  local items = {}
  for _, slot in ipairs(EQUIPMENT_SLOTS) do
    local itemID = GetInventoryItemID("player", slot.id)
    local link = GetInventoryItemLink("player", slot.id)
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
