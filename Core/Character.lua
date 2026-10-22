local addonName, Pathwise = ...

-- Character tracker: keeps a snapshot of the player (identity, level/XP,
-- zone, equipment, talents, skills) and notifies other modules through the
-- CHARACTER_UPDATED callback whenever part of it changes.
--
-- Callbacks fired:
--   CHARACTER_UPDATED (snapshot, section)  section = "all", "level", "xp",
--                     "zone", "equipment", "talents", "skills" or "bags"
--   LEVEL_UP          (newLevel)

local L = Pathwise.L
local Platform = Pathwise.Platform

local Character = Pathwise:NewModule("Character")

-- Vanilla rule: the first talent point comes at level 10, then one per level.
local FIRST_TALENT_LEVEL = 10

-- How often to retry when equipped items aren't cached yet at login.
local PENDING_RETRY_SECONDS = 1
local PENDING_MAX_RETRIES = 10

local snapshot = {
  equipment = {},
  talents = { trees = {}, spent = 0, unspent = 0 },
  skills = {},
  collapsedSkillHeaders = {},
}

function Character:GetSnapshot()
  return snapshot
end

---------------------------------------------------------------------------
-- Refreshing
---------------------------------------------------------------------------

local function RefreshIdentity()
  local info = Platform.GetPlayerInfo()
  for key, value in pairs(info) do
    snapshot[key] = value
  end
end

local function RefreshLevel(levelFromEvent)
  local level = levelFromEvent or Platform.GetLevel()
  -- UnitLevel can still report the old level right after PLAYER_LEVEL_UP,
  -- so prefer the event's value and never go backwards.
  if snapshot.level and level < snapshot.level then
    level = snapshot.level
  end
  snapshot.level = level
  snapshot.maxLevel = Platform.GetMaxLevel()
end

local function RefreshXP()
  snapshot.xp, snapshot.xpMax, snapshot.rested = Platform.GetXP()
end

local function RefreshZone()
  snapshot.zone = Platform.GetZone()
end

local pendingRetries = 0
local RefreshEquipment

local function RetryPendingEquipment()
  RefreshEquipment()
  Pathwise:FireCallback("CHARACTER_UPDATED", snapshot, "equipment")
end

function RefreshEquipment()
  snapshot.equipment = Platform.GetEquippedItems()
  local anyPending = false
  for _, item in pairs(snapshot.equipment) do
    if item.pending then
      anyPending = true
    end
  end
  if anyPending and pendingRetries < PENDING_MAX_RETRIES then
    pendingRetries = pendingRetries + 1
    Character:Debug("Some equipped items are not cached yet; retrying.")
    Platform.After(PENDING_RETRY_SECONDS, RetryPendingEquipment)
  elseif not anyPending then
    pendingRetries = 0
  end
end

local function RefreshTalents()
  local trees = Platform.GetTalentTrees()
  local spent = 0
  for _, tree in ipairs(trees) do
    spent = spent + tree.points
  end
  local unspent = Platform.GetUnspentTalentPoints()
  if not unspent then
    unspent = math.max(0, (snapshot.level or 1) - (FIRST_TALENT_LEVEL - 1) - spent)
  end
  snapshot.talents = { trees = trees, spent = spent, unspent = unspent }
end

local function RefreshSkills()
  snapshot.skills, snapshot.collapsedSkillHeaders = Platform.GetSkills()
end

local function RefreshAll()
  RefreshIdentity()
  RefreshLevel()
  RefreshXP()
  RefreshZone()
  RefreshEquipment()
  RefreshTalents()
  RefreshSkills()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Which snapshot section each event refreshes.
local EVENT_SECTIONS = {
  PLAYER_ENTERING_WORLD = "all",
  PLAYER_LEVEL_UP = "level",
  PLAYER_XP_UPDATE = "xp",
  UPDATE_EXHAUSTION = "xp",
  PLAYER_EQUIPMENT_CHANGED = "equipment",
  CHARACTER_POINTS_CHANGED = "talents",
  -- May not exist in Classic Era; a failed registration is harmless.
  PLAYER_TALENT_UPDATE = "talents",
  SKILL_LINES_CHANGED = "skills",
  ZONE_CHANGED_NEW_AREA = "zone",
  ZONE_CHANGED = "zone",
  ZONE_CHANGED_INDOORS = "zone",
  BAG_UPDATE_DELAYED = "bags",
}

function Character:Refresh(section, ...)
  if section == "all" then
    RefreshAll()
  elseif section == "level" then
    RefreshLevel(...)
    RefreshXP()
    RefreshTalents() -- unspent points change with level
  elseif section == "xp" then
    RefreshXP()
  elseif section == "zone" then
    RefreshZone()
  elseif section == "equipment" then
    RefreshEquipment()
  elseif section == "talents" then
    RefreshTalents()
  elseif section == "skills" then
    RefreshSkills()
  end
  -- "bags": nothing in the snapshot yet; modules (e.g. hunter ammo) listen.

  snapshot.updated = time()
  Pathwise.charDB.lastSnapshot = snapshot
end

function Character:OnEvent(event, ...)
  local section = EVENT_SECTIONS[event]
  if event == "PLAYER_LEVEL_UP" then
    local newLevel = ...
    self:Refresh(section, newLevel)
    self:Debugf("Level up: %d", snapshot.level)
    Pathwise:FireCallback("CHARACTER_UPDATED", snapshot, section)
    Pathwise:FireCallback("LEVEL_UP", snapshot.level)
    return
  end
  self:Refresh(section)
  Pathwise:FireCallback("CHARACTER_UPDATED", snapshot, section)
end

function Character:OnEnable()
  for event in pairs(EVENT_SECTIONS) do
    self:RegisterEvent(event, "OnEvent")
  end
  self:Refresh("all")
  Pathwise:FireCallback("CHARACTER_UPDATED", snapshot, "all")
end

---------------------------------------------------------------------------
-- /pw status
---------------------------------------------------------------------------

local function FormatNumber(number)
  local text = tostring(math.floor(number + 0.5))
  local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (formatted:gsub("^,", ""))
end

local function Line(fmt, ...)
  Pathwise:PrintLine("  " .. string.format(fmt, ...))
end

function Character:PrintStatus()
  local s = snapshot
  Pathwise:Print(L.STATUS_HEADER)

  Line(L.STATUS_IDENTITY, s.name or "?", s.realm or "?", s.level or 0,
    s.raceLocalized or "?", s.classLocalized or "?", s.factionLocalized or s.faction or "?")

  if s.level and s.maxLevel and s.level >= s.maxLevel then
    Line(L.STATUS_XP_MAX)
  elseif s.xpMax and s.xpMax > 0 then
    local percent = s.xp / s.xpMax * 100
    if s.rested and s.rested > 0 then
      Line(L.STATUS_XP_RESTED, FormatNumber(s.xp), FormatNumber(s.xpMax), percent, FormatNumber(s.rested))
    else
      Line(L.STATUS_XP, FormatNumber(s.xp), FormatNumber(s.xpMax), percent)
    end
  end

  local zone = s.zone or {}
  local zoneText = zone.zone or "?"
  if zone.subZone and zone.subZone ~= "" and zone.subZone ~= zone.zone then
    zoneText = zoneText .. " - " .. zone.subZone
  end
  if zone.mapID then
    zoneText = zoneText .. string.format(" (map %d)", zone.mapID)
  end
  Line(L.STATUS_ZONE, zoneText)

  -- Spec and talents
  local Talents = Pathwise:GetModule("Talents")
  if Talents then
    Line(L.STATUS_SPEC, Talents:DescribeSpec())
  end
  local talents = s.talents
  local treeParts = {}
  for _, tree in ipairs(talents.trees) do
    treeParts[#treeParts + 1] = string.format("%s %d", tree.name or "?", tree.points)
  end
  if #treeParts > 0 then
    Line(L.STATUS_TALENTS, table.concat(treeParts, " / "), talents.unspent)
  else
    Line(L.STATUS_TALENTS_NONE)
  end
  for _, tree in ipairs(talents.trees) do
    local ranks = {}
    for _, talent in ipairs(tree.talents) do
      if talent.rank > 0 then
        ranks[#ranks + 1] = string.format("%s %d/%d", talent.name, talent.rank, talent.maxRank)
      end
    end
    if #ranks > 0 then
      Line("    %s: %s", tree.name or "?", table.concat(ranks, ", "))
    end
  end

  -- Gear
  local slots = Platform.GetEquipmentSlots()
  local empty, equippedCount = {}, 0
  for _, slot in ipairs(slots) do
    if s.equipment[slot.id] then
      equippedCount = equippedCount + 1
    end
  end
  Line(L.STATUS_GEAR, equippedCount, #slots)
  for _, slot in ipairs(slots) do
    local item = s.equipment[slot.id]
    local slotName = L["SLOT_" .. slot.key]
    if item then
      local text = item.link or string.format(L.STATUS_ITEM_PENDING, item.itemID or 0)
      Line("    %s: %s", slotName, text)
    else
      empty[#empty + 1] = slotName
    end
  end
  if #empty > 0 then
    Line(L.STATUS_EMPTY_SLOTS, table.concat(empty, ", "))
  end

  -- Skills, grouped by their (localized) skill window header
  local groups, groupOrder = {}, {}
  for _, skill in ipairs(s.skills) do
    local header = skill.header or "?"
    if not groups[header] then
      groups[header] = {}
      groupOrder[#groupOrder + 1] = header
    end
    local group = groups[header]
    group[#group + 1] = string.format("%s %d/%d", skill.name, skill.rank, skill.maxRank)
  end
  for _, header in ipairs(groupOrder) do
    Line("%s: %s", header, table.concat(groups[header], ", "))
  end
  if #s.collapsedSkillHeaders > 0 then
    Line(L.STATUS_SKILLS_COLLAPSED, table.concat(s.collapsedSkillHeaders, ", "))
  end

  local client = Platform.GetClientInfo()
  Line(L.STATUS_CLIENT, tostring(client.version), tostring(client.interface), Pathwise.version)
end

Pathwise:RegisterCommand("status", function()
  Character:PrintStatus()
end, L.CMD_STATUS)
