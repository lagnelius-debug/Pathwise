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
