local addonName, Pathwise = ...

-- Travel routes: when the destination is in a region walking can't reach
-- (Data/Classic/Travel.lua), the way goes through portals and boats. Route
-- finds the cheapest chain of connectors (walking yards plus each
-- connector's cost); the arrow then points at the first connector, and
-- distances used for ordering steps count the whole route.
-- For longer trips a flight between two known flight points (Core/Flights)
-- is considered too, when it's clearly faster than going on foot.

local L = Pathwise.L
local Travel = Pathwise:NewModule("Travel")
local Data = Pathwise.Data

-- Flights are only considered for trips at least this long (yards)...
Travel.FLIGHT_MIN_YARDS = 800
-- ...and only taken when they cost at most this share of going on foot.
Travel.FLIGHT_SAVING = 0.75
-- Cost of a flight in "yards on foot": a flight covers ground about three
-- times faster (counting the detours of the flight paths), plus a fixed
-- part for talking to the flight master, taking off and landing.
Travel.FLY_FACTOR = 0.3
Travel.FLY_OVERHEAD = 250
-- Flight points tried at each end: the ones nearest to the start and goal.
local NEAREST_NODES = 2

local function Vector(...)
  return Pathwise:GetModule("Waypoints").Vector(...)
end

-- The zone a map belongs to for "finish the zone before leaving": the map
-- itself, or the zone around it for a capital.
function Travel.ZoneGroup(mapID)
  return Data.Travel.ZONE_GROUPS[mapID] or mapID
end

-- The region a map position is in, or nil (unknown map).
function Travel.RegionOf(mapID, x, y)
  for _, area in ipairs(Data.Travel.AREAS) do
    if area.mapID == mapID then
      local box = area.box
      if not box or (x >= box[1] and x <= box[3] and y >= box[2] and y <= box[4]) then
        return area.region
      end
    end
  end
  local rect = Pathwise.Platform.GetMapWorldRect(mapID)
  return rect and Data.Travel.CONTINENTS[rect.continent] or nil
end

-- The way on foot (with portals and boats) from one map position to
-- another: { legs = { connector, ... }, distance }, or nil when both are in
-- the same region (or a region is unknown, or no connectors lead there).
local function StaticRoute(fromMap, fromX, fromY, toMap, toX, toY)
  local start = Travel.RegionOf(fromMap, fromX, fromY)
  local goal = Travel.RegionOf(toMap, toX, toY)
  if not start or not goal or start == goal then
    return nil
  end
  local best
  local legs, visited = {}, { [start] = true }
  -- Depth-first over the (small) connector graph, keeping the cheapest.
  local function Walk(region, mapID, x, y, cost)
    if best and cost >= best.distance then
      return
    end
    if region == goal then
      local last = Vector(mapID, x, y, toMap, toX, toY)
      if last and (not best or cost + last < best.distance) then
        local copy = {}
        for i, leg in ipairs(legs) do
          copy[i] = leg
        end
        best = { legs = copy, distance = cost + last }
      end
      return
    end
    for _, connector in ipairs(Data.Travel.CONNECTORS) do
      if connector.from == region and not visited[connector.to] then
        local entry, exit = connector.entry, connector.exit
        local walk = Vector(mapID, x, y, entry[1], entry[2], entry[3])
        if walk then
          visited[connector.to] = true
          legs[#legs + 1] = connector
          Walk(connector.to, exit[1], exit[2], exit[3], cost + walk + (connector.cost or 0))
          legs[#legs] = nil
          visited[connector.to] = nil
        end
      end
    end
  end
  Walk(start, fromMap, fromX, fromY, 0)
  return best
end

-- Yards on foot (with portals and boats) between two positions, or nil.
local function FootDistance(fromMap, fromX, fromY, toMap, toX, toY)
  local route = StaticRoute(fromMap, fromX, fromY, toMap, toX, toY)
  if route then
    return route.distance, route.legs
  end
  return (Vector(fromMap, fromX, fromY, toMap, toX, toY)), {}
end

-- The flight points nearest to a position (by straight distance).
local function NearestNodes(nodes, mapID, x, y)
  local list = {}
  for _, node in ipairs(nodes) do
    local distance = Vector(mapID, x, y, node.mapID, node.x, node.y)
    if distance then
      list[#list + 1] = { node = node, distance = distance }
    end
  end
  table.sort(list, function(a, b) return a.distance < b.distance end)
  local result = {}
  for i = 1, math.min(NEAREST_NODES, #list) do
    result[i] = list[i].node
  end
  return result
end

-- The best way that includes a flight, or nil: walk (and take portals) to
-- a flight point near the start, fly to one near the goal, walk on.
local function FlightRoute(fromMap, fromX, fromY, toMap, toX, toY)
  local rect = Pathwise.Platform.GetMapWorldRect(fromMap)
  if not rect then
    return nil
  end
  local nodes = Pathwise:GetModule("Flights"):GetNodes(rect.continent)
  if #nodes < 2 then
    return nil
  end
  local best
  for _, from in ipairs(NearestNodes(nodes, fromMap, fromX, fromY)) do
    for _, to in ipairs(NearestNodes(nodes, toMap, toX, toY)) do
      if from ~= to then
        local walkTo, legsTo = FootDistance(fromMap, fromX, fromY, from.mapID, from.x, from.y)
        local walkFrom, legsFrom = FootDistance(to.mapID, to.x, to.y, toMap, toX, toY)
        local flight = Vector(from.mapID, from.x, from.y, to.mapID, to.x, to.y)
        if walkTo and walkFrom and flight then
          local cost = walkTo + flight * Travel.FLY_FACTOR + Travel.FLY_OVERHEAD + walkFrom
          if not best or cost < best.distance then
            local legs = {}
            for _, leg in ipairs(legsTo) do
              legs[#legs + 1] = leg
            end
            legs[#legs + 1] = {
              flight = true,
              text = string.format(L.TRAVEL_FLY, from.town, to.town, from.npc or "?"),
              entry = { from.mapID, from.x, from.y },
              exit = { to.mapID, to.x, to.y },
            }
            for _, leg in ipairs(legsFrom) do
              legs[#legs + 1] = leg
            end
            best = { legs = legs, distance = cost }
          end
        end
      end
    end
  end
  return best
end

-- The way from one map position to another: { legs = { connector, ... },
-- distance }, where a connector is a portal, boat or flight; or nil when
-- walking straight is the way (or there's no way to tell).
function Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
  local route = StaticRoute(fromMap, fromX, fromY, toMap, toX, toY)
  local onFoot = route and route.distance or Vector(fromMap, fromX, fromY, toMap, toX, toY)
  if onFoot and onFoot >= Travel.FLIGHT_MIN_YARDS then
    local flight = FlightRoute(fromMap, fromX, fromY, toMap, toX, toY)
    if flight and flight.distance <= onFoot * Travel.FLIGHT_SAVING then
      return flight
    end
  end
  return route
end

-- Distance in yards along the route (through connectors when needed), or
-- straight; nil if there's no way to measure it.
function Travel.Distance(fromMap, fromX, fromY, toMap, toX, toY)
  local route = Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
  if route then
    return route.distance
  end
  return (Vector(fromMap, fromX, fromY, toMap, toX, toY))
end
