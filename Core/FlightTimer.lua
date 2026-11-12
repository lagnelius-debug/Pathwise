local addonName, Pathwise = ...

-- How long the current flight takes. The game doesn't say, so the first
-- flight on a route is estimated from the distance between its flight
-- points (marked as an estimate); every flight that lands saves its real
-- time (Pathwise.db.flightTimes, shared by every character: routes don't
-- change), so the next one on that route counts down exactly.
-- UI/FlightTimerBar.lua shows it under the To-do window.

local Platform = Pathwise.Platform

local FlightTimer = Pathwise:NewModule("FlightTimer")

-- Estimates: flight speed (yards a second), how much longer the path is
-- than a straight line (it follows roads and goes around mountains), and
-- seconds for take-off and landing.
FlightTimer.SPEED = 32
FlightTimer.PATH_FACTOR = 1.3
FlightTimer.OVERHEAD = 8
-- A destination picked but no flight after this long: it didn't start
-- (not enough money, the window closed).
FlightTimer.TAKEOFF_WAIT = 5
-- Shorter flights aren't saved (a dismount, a glitch).
FlightTimer.MIN_SAVED = 10

local flight -- { from, to, picked, start, duration, estimated }

function FlightTimer.Key(from, to)
  return from .. " > " .. to
end

-- The flight time from one flight point to another, by their names: the
-- learned one, or an estimate (second result true), or nil.
function FlightTimer.Duration(from, to)
  if not from or not to then
    return nil
  end
  local learned = Pathwise.db.flightTimes[FlightTimer.Key(from, to)]
  if learned then
    return learned, false
  end
  local nodes = Pathwise.charDB.flightNodes
  local a, b = nodes[from], nodes[to]
  if not (a and b and a.mapID and b.mapID) then
    return nil
  end
  local yards = Pathwise:GetModule("Waypoints").Vector(a.mapID, a.x, a.y, b.mapID, b.x, b.y)
  if not yards then
    return nil
  end
  return math.floor(yards * FlightTimer.PATH_FACTOR / FlightTimer.SPEED + FlightTimer.OVERHEAD + 0.5), true
end

-- The player picked a destination on the flight map.
function FlightTimer:OnTakeoff(index)
  if not Pathwise.db.flightTimer then
    return
  end
  local to = Platform.GetTaxiNodeName(index)
  if not to then
    return
  end
  local from
  for _, node in ipairs(Platform.GetTaxiNodes()) do
    if node.state == "CURRENT" then
      from = node.name
    end
  end
  local duration, estimated = FlightTimer.Duration(from, to)
  flight = { from = from, to = to, picked = Platform.GetTime(), duration = duration, estimated = estimated }
  Pathwise:FireCallback("FLIGHT_TIMER")
end

-- Every quarter second: the flight starts, goes on, or lands.
function FlightTimer:Tick()
  if not flight then
    return
  end
  local now, onTaxi = Platform.GetTime(), Platform.IsOnTaxi()
  if not flight.start then
    if onTaxi then
      flight.start = now
    elseif now - flight.picked > FlightTimer.TAKEOFF_WAIT then
      flight = nil
    end
  elseif not onTaxi then
    local seconds = now - flight.start
    if flight.from and seconds >= FlightTimer.MIN_SAVED then
      Pathwise.db.flightTimes[FlightTimer.Key(flight.from, flight.to)] = math.floor(seconds + 0.5)
    end
    flight = nil
  end
  Pathwise:FireCallback("FLIGHT_TIMER")
end

-- The flight under way, or nil: { to, elapsed, duration (nil when not
-- known), remaining, estimated }.
function FlightTimer:GetFlight()
  if not flight or not flight.start then
    return nil
  end
  local elapsed = Platform.GetTime() - flight.start
  return {
    to = flight.to,
    elapsed = elapsed,
    duration = flight.duration,
    remaining = flight.duration and math.max(0, flight.duration - elapsed) or nil,
    estimated = flight.estimated,
  }
end

function FlightTimer:OnEnable()
  Platform.HookTaxiTakeoff(function(index)
    FlightTimer:OnTakeoff(index)
  end)
  Platform.Every(0.25, function()
    FlightTimer:Tick()
  end)
end
