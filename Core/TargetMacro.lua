local addonName, Pathwise = ...

-- Target macro: keeps a character macro named "Pathwise" up to date with
-- /targetexact lines for the NPCs of the arrow's current step (quest mobs
-- still needed, or the turn-in NPC), plus a skull mark on the target.
-- With several kinds of mobs (a "do together" step), it goes through them
-- in turn: once you've targeted one kind, the next press goes for the next
-- kind first (the others stay as fallbacks when it isn't around).
-- The player drags it to an action bar once (/pw macro); after that it
-- changes by itself. Macros can't be edited in combat, so changes made in
-- combat wait until it ends.

local L = Pathwise.L
local Platform = Pathwise.Platform

local TargetMacro = Pathwise:NewModule("TargetMacro")

TargetMacro.MACRO_NAME = "Pathwise"
local ICON = "Ability_Hunter_SniperShot"
local MAX_BODY = 255 -- the client's macro length limit
-- (Only on something to fight: not on a vendor or quest giver. Kept short:
-- the macro holds 255 characters.)
local MARK_LINE = '/run local t="target"if UnitCanAttack("player",t)and not UnitIsDead(t)then SetRaidTarget(t,8)end'

local lastBody
local warnedFull = false
-- The mob name to go for first (set when the player targets one of the
-- step's mobs: the next one in the list), or nil for the list's own order.
local preferred

-- A shared ending shorter than this ("Crawler" is fine) doesn't merge.
local MIN_SHARED_ENDING = 4

local function Words(text)
  local words = {}
  for word in text:gmatch("%S+") do
    words[#words + 1] = word
  end
  return words
end

-- The whole words two names end in ("Reef Crawler", "Tide Crawler" ->
-- "Crawler"), or "".
local function SharedEnding(a, b)
  local wordsA, wordsB = Words(a), Words(b)
  local count = 0
  while count < #wordsA and count < #wordsB and wordsA[#wordsA - count] == wordsB[#wordsB - count] do
    count = count + 1
  end
  return table.concat(wordsA, " ", #wordsA - count + 1, #wordsA)
end

-- Names (most important first) -> groups, in that order: { name, partial,
-- members }. A name that another one contains ("Crag Boar" in "Large Crag
-- Boar" and "Small Crag Boar") stands for all of them, and so does the
-- ending names share ("Pygmy Tide Crawler", "Young Reef Crawler" ->
-- "Crawler"): /target (not /targetexact) matches part of a name and takes
-- the nearest, whichever kind it is. Second result: [name] = its group.
function TargetMacro.Groups(names)
  local keyOf = {}
  for _, name in ipairs(names or {}) do
    local key = name
    for _, other in ipairs(names) do
      -- (Whole words only: "Crag Boar" in "Large Crag Boar", not "Rat" in
      -- "Pirate".)
      if #other < #key and (" " .. name .. " "):find(" " .. other .. " ", 1, true) then
        key = other
      end
    end
    keyOf[name] = key
  end
  local groups, byKey = {}, {}
  for _, name in ipairs(names or {}) do
    local key = keyOf[name]
    local group = byKey[key]
    if not group then
      group = { name = key, partial = false, members = {} }
      groups[#groups + 1] = group
      byKey[key] = group
    end
    if key ~= name then
      group.partial = true
    end
    group.members[#group.members + 1] = name
  end
  -- Groups that end in the same words become one (the first keeps its
  -- place).
  local merged = true
  while merged do
    merged = false
    for i = 1, #groups - 1 do
      for j = i + 1, #groups do
        local ending = SharedEnding(groups[i].name, groups[j].name)
        if #ending >= MIN_SHARED_ENDING then
          groups[i].name, groups[i].partial = ending, true
          for _, member in ipairs(groups[j].members) do
            table.insert(groups[i].members, member)
          end
          table.remove(groups, j)
          merged = true
          break
        end
      end
      if merged then
        break
      end
    end
  end
  local groupOf = {}
  for _, group in ipairs(groups) do
    for _, member in ipairs(group.members) do
      groupOf[member] = group
    end
  end
  return groups, groupOf
end

-- The group a targeted unit belongs to (by its name), or nil.
local function GroupOfUnit(groups, groupOf, unitName)
  if groupOf[unitName] then
    return groupOf[unitName]
  end
  for _, group in ipairs(groups) do
    if group.partial and unitName:find(group.name, 1, true) then
      return group
    end
  end
end

-- Names (most important first) -> the same names, those of the group to
-- go for first leading.
function TargetMacro.Ordered(names)
  if not names or not preferred then
    return names
  end
  local groups = TargetMacro.Groups(names)
  for _, group in ipairs(groups) do
    if group.name == preferred then
      local ordered, seen = {}, {}
      for _, member in ipairs(group.members) do
        ordered[#ordered + 1] = member
        seen[member] = true
      end
      for _, name in ipairs(names) do
        if not seen[name] then
          ordered[#ordered + 1] = name
        end
      end
      return ordered
    end
  end
  return names
end

-- The player targeted something: one of the step's mobs moves the turn on
-- to the next kind. (Looked at right after: the macro's /targetexact lines
-- change the target several times in one press, and the macro isn't
-- edited while it runs.)
local checkPending = false

local function CheckTarget()
  checkPending = false
  local target = Pathwise:GetModule("Waypoints"):GetTarget()
  local names = target and target.names
  local name = Platform.GetTargetNPCName()
  if not names or not name then
    return
  end
  -- (In turn by group: a Crag Boar moves on past the Large Crag Boars.)
  local groups, groupOf = TargetMacro.Groups(names)
  local group = #groups > 1 and GroupOfUnit(groups, groupOf, name)
  if not group then
    return
  end
  for i, candidate in ipairs(groups) do
    if candidate == group then
      local nextName = groups[i % #groups + 1].name
      if nextName ~= preferred then
        preferred = nextName
        TargetMacro:Update()
        Pathwise:FireCallback("TARGET_ORDER_CHANGED", preferred)
      end
      return
    end
  end
end

function TargetMacro:OnTargetChanged()
  if not checkPending then
    checkPending = true
    Platform.After(0, CheckTarget)
  end
end

-- Pure function: names (most important first) -> macro body. Later
-- target lines win when several match, so the most important name goes
-- last. Names grouped by Groups share one /target line. Lines that don't
-- fit in the macro limit are left out.
function TargetMacro.BuildBody(names)
  if not names or #names == 0 then
    return "/run print(\"" .. L.MACRO_NOTHING .. "\")"
  end
  local lines = { "/cleartarget" }
  local length = #lines[1]
  local groups = TargetMacro.Groups(names)
  local targetLines = {}
  for i = #groups, 1, -1 do
    local group = groups[i]
    targetLines[#targetLines + 1] = (group.partial and "/target " or "/targetexact ") .. group.name
  end
  -- Keep the most important names when space runs out.
  local kept = {}
  for i = #targetLines, 1, -1 do
    local line = targetLines[i]
    if length + 1 + #line <= MAX_BODY - (1 + #MARK_LINE) then
      table.insert(kept, 1, line)
      length = length + 1 + #line
    end
  end
  for _, line in ipairs(kept) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = MARK_LINE
  return table.concat(lines, "\n")
end

function TargetMacro:Update()
  if not Pathwise.db.targetMacro then
    return
  end
  local target = Pathwise:GetModule("Waypoints"):GetTarget()
  local body = TargetMacro.BuildBody(TargetMacro.Ordered(target and target.names))
  if body == lastBody then
    return
  end
  local ok, reason = Platform.SetMacro(TargetMacro.MACRO_NAME, ICON, body)
  if ok then
    lastBody = body
    self:Debug("Target macro updated.")
  elseif reason == "combat" then
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
  elseif reason == "full" and not warnedFull then
    warnedFull = true
    Pathwise:Print(L.MACRO_FULL)
  end
end

function TargetMacro:OnCombatEnded()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  self:Update()
end

function TargetMacro:OnWaypointChanged()
  self:Update()
end

function TargetMacro:OnInitialize()
  self:RegisterCallback("WAYPOINT_CHANGED", "OnWaypointChanged")
end

function TargetMacro:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
  self:Update()
end

-- /pw macro: create/update the macro and put it on the cursor.
-- /pw macro off|on: stop/start keeping it up to date.
Pathwise:RegisterCommand("macro", function(args)
  args = args:lower()
  if args == "off" or args == "on" then
    Pathwise.db.targetMacro = args == "on"
    Pathwise:Print(Pathwise.db.targetMacro and L.MACRO_ON or L.MACRO_OFF)
    TargetMacro:Update()
    return
  end
  Pathwise.db.targetMacro = true
  lastBody = nil
  TargetMacro:Update()
  if Platform.PickupMacro(TargetMacro.MACRO_NAME) then
    Pathwise:Print(L.MACRO_PICKED_UP)
  elseif Platform.InCombat() then
    Pathwise:Print(L.MACRO_COMBAT)
  end
end, L.CMD_MACRO)
