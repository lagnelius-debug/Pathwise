local addonName, Pathwise = ...

-- The flight timer (Core/FlightTimer.lua): a bar under the To-do window
-- that empties as the flight goes on - "Flying to Stormwind · 1:23" ("~"
-- for an estimate) - and goes away on landing.

local L = Pathwise.L
local FlightTimerBar = Pathwise:NewModule("FlightTimerBar")

local frame

local function Colors()
  local theme = Pathwise.Theme.Get(Pathwise.Theme.GetActiveId())
  local function RGB(hex, alpha)
    return Pathwise.HexToRGB(hex or "#ffd100", alpha)
  end
  frame.bg:SetColorTexture(RGB(theme.bg, 0.9))
  frame:SetStatusBarColor(RGB(theme.title))
  frame.text:SetTextColor(RGB(theme.text or "#ffffff"))
end

local function Create()
  frame = CreateFrame("StatusBar", "PathwiseFlightTimer", UIParent)
  frame:SetHeight(18)
  frame:SetMinMaxValues(0, 1)
  frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints(frame)
  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame:Hide()
end

-- Right under the To-do window, as wide as it.
local function Anchor()
  local window = _G.PathwiseNextSteps
  frame:ClearAllPoints()
  if window then
    frame:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 0, -4)
    frame:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -4)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetWidth(240)
  end
end

-- "1:23" for seconds.
function FlightTimerBar.FormatTime(seconds)
  seconds = math.max(0, math.floor(seconds + 0.5))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function FlightTimerBar:Render()
  local state = Pathwise.db.flightTimer and Pathwise:GetModule("FlightTimer"):GetFlight()
  if not state then
    frame:Hide()
    return
  end
  local town = Pathwise:GetModule("Flights").TownName(state.to)
  if state.duration then
    if state.remaining > 0 then
      local time = FlightTimerBar.FormatTime(state.remaining)
      frame.text:SetText(string.format(L.FLIGHT_TIMER, town, state.estimated and ("~" .. time) or time))
    else
      frame.text:SetText(string.format(L.FLIGHT_LANDING, town))
    end
    frame:SetValue(state.duration > 0 and state.remaining / state.duration or 0)
  else
    -- (No time known: how long it's been.)
    frame.text:SetText(string.format(L.FLIGHT_TIMER, town, FlightTimerBar.FormatTime(state.elapsed)))
    frame:SetValue(1)
  end
  if not frame:IsShown() then
    Anchor()
    Colors()
    frame:Show()
  end
end

function FlightTimerBar:OnInitialize()
  Create()
  self:RegisterCallback("FLIGHT_TIMER", "Render")
  self:RegisterCallback("THEME_CHANGED", function()
    if frame:IsShown() then
      Colors()
    end
  end)
end
