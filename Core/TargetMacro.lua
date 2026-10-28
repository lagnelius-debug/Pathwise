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
-- (Only on something to fight: not on a vendor or quest giver.)
local MARK_LINE = '/run if UnitCanAttack("player","target") and not UnitIsDead("target") then SetRaidTarget("target",8) end'

local lastBody
local warnedFull = false
-- The mob name to go for first (set when the player targets one of the
-- step's mobs: the next one in the list), or nil for the list's own order.
local preferred

-- Names (most important first) -> the same names starting at the one to go
-- for first.
function TargetMacro.Ordered(names)
  if not names or not preferred then
    return names
  end
  for i, name in ipairs(names) do
    if name == preferred then
      local ordered = {}
      for k = 0, #names - 1 do
        ordered[#ordered + 1] = names[(i - 1 + k) % #names + 1]
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
  if not names or #names < 2 or not name then
    return
  end
  for i, candidate in ipairs(names) do
    if candidate == name then
      local nextName = names[i % #names + 1]
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
-- /targetexact lines win when several match, so the most important name
-- goes last. Lines that don't fit in the macro limit are left out.
function TargetMacro.BuildBody(names)
  if not names or #names == 0 then
    return "/run print(\"" .. L.MACRO_NOTHING .. "\")"
  end
  local lines = { "/cleartarget" }
  local length = #lines[1]
  local targetLines = {}
  for i = #names, 1, -1 do
    local line = "/targetexact " .. names[i]
    targetLines[#targetLines + 1] = line
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
