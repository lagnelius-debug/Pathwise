local addonName, Pathwise = ...

-- Travel routes: when the destination is in a region walking can't reach
-- (Data/Classic/Travel.lua), the way goes through portals and boats. Route
-- finds the cheapest chain of connectors (walking yards plus each
-- connector's cost); the arrow then points at the first connector, and
-- distances used for ordering steps count the whole route.

local Travel = Pathwise:NewModule("Travel")
local Data = Pathwise.Data

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

-- The way from one map position to another through connectors:
--   { legs = { connector, ... }, distance }
-- or nil when both are in the same region (or a region is unknown, or no
-- connectors lead there) - then walking straight is the way.
function Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
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

-- Distance in yards along the route (through connectors when needed), or
-- straight; nil if there's no way to measure it.
function Travel.Distance(fromMap, fromX, fromY, toMap, toX, toY)
  local route = Travel.Route(fromMap, fromX, fromY, toMap, toX, toY)
  if route then
    return route.distance
  end
  return (Vector(fromMap, fromX, fromY, toMap, toX, toY))
end
