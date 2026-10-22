local addonName, Pathwise = ...

-- Target macro: keeps a character macro named "Pathwise" up to date with
-- /targetexact lines for the NPCs of the arrow's current step (quest mobs
-- still needed, or the turn-in NPC), plus a skull mark on the target.
-- The player drags it to an action bar once (/pw macro); after that it
-- changes by itself. Macros can't be edited in combat, so changes made in
-- combat wait until it ends.

local L = Pathwise.L
local Platform = Pathwise.Platform

local TargetMacro = Pathwise:NewModule("TargetMacro")

TargetMacro.MACRO_NAME = "Pathwise"
local ICON = "Ability_Hunter_SniperShot"
local MAX_BODY = 255 -- the client's macro length limit
local MARK_LINE = '/run if UnitExists("target") and not UnitIsDead("target") then SetRaidTarget("target",8) end'

local lastBody
local warnedFull = false

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
  local body = TargetMacro.BuildBody(target and target.names)
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
