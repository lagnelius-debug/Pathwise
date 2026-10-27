local addonName, Pathwise = ...

-- Travel routes: when the destination is in a region walking can't reach
-- (Data/Classic/Travel.lua), the way goes through portals, boats and
-- zeppelins, also between the continents. Route
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

-- A trip within one region only tries connectors when it's at least this
-- long (yards): a boat or zeppelin costs about this much on its own, so a
-- shorter walk can't get faster through one (and most trips stay cheap).
Travel.SHORTCUT_MIN = 1500

local function PlayerFaction()
  return Pathwise:GetModule("Character"):GetSnapshot().faction
end

-- Whether the player can take a connector (some docks and towers are in
-- the other faction's towns).
local function Usable(connector)
  return not connector.faction or not PlayerFaction() or connector.faction == PlayerFaction()
end

-- The crossing itself in yards: a fixed one between continents (sail), else
-- the distance sailed at the connector's pace (a portal is instant).
local function Crossing(connector)
  if connector.sail then
    return connector.sail
  end
  local entry, exit = connector.entry, connector.exit
  return (connector.pace or 0) * (Vector(entry[1], entry[2], entry[3], exit[1], exit[2], exit[3]) or 0)
end
Travel.Crossing = Crossing

-- The way on foot (with portals, boats and zeppelins) from one map position
-- to another: { legs = { connector, ... }, distance }, or nil when walking
-- straight is the way (or a region is unknown, or no connectors lead there).
local function StaticRoute(fromMap, fromX, fromY, toMap, toX, toY)
  local start = Travel.RegionOf(fromMap, fromX, fromY)
  local goal = Travel.RegionOf(toMap, toX, toY)
  if not start or not goal then
    return nil
  end
  local best
  if start == goal then
    local direct = Vector(fromMap, fromX, fromY, toMap, toX, toY)
    if not direct or direct < Travel.SHORTCUT_MIN then
      return nil
    end
    best = { legs = {}, distance = direct }
  end
  local legs, used = {}, {}
  -- Depth-first over the (small) connector graph, each connector at most
  -- once, keeping the cheapest.
  local function Walk(region, mapID, x, y, cost)
    if best and cost >= best.distance then
      return
    end
    if region == goal and #legs > 0 then
      local last = Vector(mapID, x, y, toMap, toX, toY)
      if last and (not best or cost + last < best.distance) then
        local copy = {}
        for i, leg in ipairs(legs) do
          copy[i] = leg
        end
        best = { legs = copy, distance = cost + last }
      end
    end
    for _, connector in ipairs(Data.Travel.CONNECTORS) do
      if connector.from == region and not used[connector] and Usable(connector) then
        local entry, exit = connector.entry, connector.exit
        local walk = Vector(mapID, x, y, entry[1], entry[2], entry[3])
        if walk then
          used[connector] = true
          legs[#legs + 1] = connector
          Walk(connector.to, exit[1], exit[2], exit[3], cost + walk + (connector.cost or 0) + Crossing(connector))
          legs[#legs] = nil
          used[connector] = nil
        end
      end
    end
  end
  Walk(start, fromMap, fromX, fromY, 0)
  if best and #best.legs > 0 then
    return best
  end
  return nil
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

local SameContinentRoute

-- The continent (world instance ID) of a map, or nil.
local function Continent(mapID)
  local rect = Pathwise.Platform.GetMapWorldRect(mapID)
  return rect and rect.continent
end

-- To another continent: the best boat or zeppelin across, with the best
-- way (flights too) to it on this side and from it on the other side.
local function CrossRoute(fromMap, fromX, fromY, toMap, toX, toY)
  local fromContinent, toContinent = Continent(fromMap), Continent(toMap)
  local best
  for _, connector in ipairs(Data.Travel.CONNECTORS) do
    local entry, exit = connector.entry, connector.exit
    if Usable(connector) and Continent(entry[1]) == fromContinent and Continent(exit[1]) == toContinent then
      local before = SameContinentRoute(fromMap, fromX, fromY, entry[1], entry[2], entry[3])
      local after = before and SameContinentRoute(exit[1], exit[2], exit[3], toMap, toX, toY)
      if after then
        local distance = before.distance + (connector.cost or 0) + Crossing(connector) + after.distance
        if not best or distance < best.distance then
          local legs = {}
          for _, leg in ipairs(before.legs) do
            legs[#legs + 1] = leg
          end
          legs[#legs + 1] = connector
          for _, leg in ipairs(after.legs) do
            legs[#legs + 1] = leg
          end
          best = { legs = legs, distance = distance }
        end
      end
    end
  end
  return best
end

-- The way from one map position to another: { legs = { connector, ... },
-- distance }, where a connector is a portal, boat, zeppelin or flight; or
-- nil when walking straight is the way (or there's no way to tell).
function Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
  local fromContinent, toContinent = Continent(fromMap), Continent(toMap)
  if fromContinent and toContinent and fromContinent ~= toContinent then
    return CrossRoute(fromMap, fromX, fromY, toMap, toX, toY)
  end
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

-- Within a continent: the route, or walking straight as a route without
-- legs; nil when there's no way to measure it.
function SameContinentRoute(fromMap, fromX, fromY, toMap, toX, toY)
  local route = Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
  if route then
    return route
  end
  local distance = Vector(fromMap, fromX, fromY, toMap, toX, toY)
  return distance and { legs = {}, distance = distance } or nil
end

-- Distance in yards along the route (through connectors when needed), or
-- straight; nil if there's no way to measure it. onFoot: leave flights out
-- (picking the nearest of many spawns or NPCs doesn't need them, and it's
-- much cheaper).
function Travel.Distance(fromMap, fromX, fromY, toMap, toX, toY, onFoot)
  if onFoot then
    return (FootDistance(fromMap, fromX, fromY, toMap, toX, toY))
  end
  local route = Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
  if route then
    return route.distance
  end
  return (Vector(fromMap, fromX, fromY, toMap, toX, toY))
end
