local addonName, Pathwise = ...

-- Waypoints: what the navigation arrow points at, and the math for it.
--
-- A target is { mapID, x, y, label } with x/y in 0..1 map coordinates.
-- The arrow follows, in order: a manual target (/pw way, or a clicked Next
-- Steps line), else the top Next Steps item that has a target ("auto").
--
-- Callbacks fired:
--   WAYPOINT_CHANGED (target or nil)

local L = Pathwise.L
local Platform = Pathwise.Platform

local Waypoints = Pathwise:NewModule("Waypoints")

-- Closer than this counts as arrived.
Waypoints.ARRIVE_YARDS = 10

-- Where quest progress happened (mob killed, node looted), spawns within
-- this radius are skipped for VISIT_MEMORY_SECONDS when picking the next
-- target. The radius covers mobs that wander off their spawn point before
-- they die.
Waypoints.PROGRESS_RADIUS_YARDS = 20
Waypoints.VISIT_MEMORY_SECONDS = 300

local visited = {} -- { { mapID, x, y, radius, time } }

local manual -- manual target or nil
local auto   -- target of the top Next Steps item, or nil
local autoItemId     -- id of the Next Steps item auto points at
local lastItems = {} -- latest Next Steps items
local skippedSteps = {} -- [Next Steps item id] = time the player skipped it

---------------------------------------------------------------------------
-- Math (pure apart from the map rectangles)
---------------------------------------------------------------------------

-- Map position -> world position: continent, north, west (yards).
function Waypoints.ToWorld(mapID, x, y)
  local rect = Platform.GetMapWorldRect(mapID)
  if not rect then
    return nil
  end
  local north = rect.top - y * (rect.top - rect.bottom)
  local west = rect.left - x * (rect.left - rect.right)
  return rect.continent, north, west
end

-- Returns distance (yards) and bearing (radians counterclockwise from north,
-- the same convention as GetPlayerFacing) from one map position to another,
-- or nil if they are on different continents or unknown maps.
function Waypoints.Vector(fromMap, fromX, fromY, toMap, toX, toY)
  local c1, n1, w1 = Waypoints.ToWorld(fromMap, fromX, fromY)
  local c2, n2, w2 = Waypoints.ToWorld(toMap, toX, toY)
  if not c1 or not c2 or c1 ~= c2 then
    return nil
  end
  local dNorth, dWest = n2 - n1, w2 - w1
  return math.sqrt(dNorth * dNorth + dWest * dWest), math.atan2(dWest, dNorth)
end

-- Where the arrow should point: returns distance, angle relative to the
-- player's facing (radians, counterclockwise; 0 = straight ahead), or nil.
function Waypoints:GetDirection()
  local target = self:GetTarget()
  if not target then
    return nil
  end
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID then
    return nil
  end
  local distance, bearing = Waypoints.Vector(mapID, x, y, target.mapID, target.x, target.y)
  if not distance then
    return nil
  end
  local facing = Platform.GetPlayerFacing()
  if not facing then
    return distance, nil
  end
  local relative = (bearing - facing) % (2 * math.pi)
  return distance, relative
end

---------------------------------------------------------------------------
-- Target state
---------------------------------------------------------------------------

function Waypoints:GetTarget()
  if manual then
    return manual, "manual"
  end
  if auto and Pathwise.db.arrowAuto then
    return auto, "auto"
  end
end

local function Changed()
  Pathwise:FireCallback("WAYPOINT_CHANGED", (Waypoints:GetTarget()))
end

function Waypoints:SetManual(target)
  manual = target
  Changed()
end

function Waypoints:ClearManual()
  if manual then
    manual = nil
    Changed()
  end
end

-- Remembers a spot as done: spawns within radius (yards, default the
-- arrival range) are skipped for a while.
function Waypoints:MarkVisited(point, radius)
  local now = Platform.GetTime()
  for i = #visited, 1, -1 do
    if now - visited[i].time > Waypoints.VISIT_MEMORY_SECONDS then
      table.remove(visited, i)
    end
  end
  visited[#visited + 1] = {
    mapID = point.mapID,
    x = point.x,
    y = point.y,
    radius = radius or Waypoints.ARRIVE_YARDS,
    time = now,
  }
end

-- True if point lies within a recently visited spot.
function Waypoints:IsVisited(point)
  local now = Platform.GetTime()
  for _, spot in ipairs(visited) do
    if now - spot.time <= Waypoints.VISIT_MEMORY_SECONDS then
      local distance = Waypoints.Vector(spot.mapID, spot.x, spot.y, point.mapID, point.x, point.y)
      if distance and distance <= spot.radius then
        return true
      end
    end
  end
  return false
end

local function RecentlySkipped(itemId)
  local time = skippedSteps[itemId]
  return time ~= nil and Platform.GetTime() - time <= Waypoints.VISIT_MEMORY_SECONDS
end

-- "Next": moves the arrow on. A spawn target (one of several mobs/nodes)
-- goes to the next spawn; any other step, or a spawn step with no unvisited
-- spawns left, is skipped for a while so the arrow points at the next Next
-- Steps item; a manual waypoint is cleared.
function Waypoints:Next()
  local target, kind = self:GetTarget()
  if kind == "manual" then
    self:ClearManual()
    Pathwise:Print(L.WAY_CLEARED)
  elseif kind == "auto" and target.spawn and not self:IsVisited(target) then
    self:MarkVisited(target)
    Pathwise:Print(L.ARROW_NEXT_SPAWN)
    Pathwise:FireCallback("WAYPOINT_VISITED", target)
  elseif kind == "auto" and autoItemId then
    -- Not a spawn, or every spawn of this step was already visited (the
    -- arrow fell back to one of them): skip the whole step.
    skippedSteps[autoItemId] = Platform.GetTime()
    Pathwise:Print(L.ARROW_NEXT_STEP)
    self:RefreshAuto()
  else
    Pathwise:Print(L.ARROW_NOTHING_TO_SKIP)
  end
end

-- Called by the UI when the player reaches the target.
function Waypoints:OnArrived()
  local target, kind = self:GetTarget()
  -- Quest targets stay until quest progress moves them on (see
  -- QuestLocations), because the mob or node may not be there yet.
  if kind == "manual" then
    Pathwise:Printf(L.WAY_ARRIVED, target.label or "")
    self:ClearManual()
  end
end

-- Picks the most important step that has a location; "later" and grey
-- quests are never worth walking to automatically, and steps the player
-- skipped are passed over for a while.
function Waypoints:RefreshAuto()
  local minPriority = Pathwise:GetModule("NextSteps").PRIORITY.QUEST_ELSEWHERE
  local chosen
  for _, item in ipairs(lastItems) do
    if item.target and item.priority >= minPriority and not RecentlySkipped(item.id) then
      chosen = item
      break
    end
  end
  local newAuto = chosen and chosen.target
  local changed = (newAuto and newAuto.label) ~= (auto and auto.label)
    or (newAuto and auto and (newAuto.x ~= auto.x or newAuto.y ~= auto.y))
  auto, autoItemId = newAuto, chosen and chosen.id
  if changed and not manual then
    Changed()
  end
end

function Waypoints:OnNextStepsUpdated(_, items)
  lastItems = items
  self:RefreshAuto()
end

function Waypoints:OnInitialize()
  self:RegisterCallback("NEXT_STEPS_UPDATED", "OnNextStepsUpdated")
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

-- /pw way <x> <y> [label]   coordinates on the current zone map (0-100)
-- /pw way clear
Pathwise:RegisterCommand("way", function(args)
  if args:lower() == "clear" then
    Waypoints:ClearManual()
    Pathwise:Print(L.WAY_CLEARED)
    return
  end
  local x, y, label = args:match("^([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
  x, y = tonumber(x), tonumber(y)
  local mapID = Platform.GetPlayerMapPosition()
  if not x or not y or x > 100 or y > 100 then
    Pathwise:Print(L.WAY_USAGE)
    return
  end
  if not mapID then
    Pathwise:Print(L.WAY_NO_POSITION)
    return
  end
  label = label ~= "" and label or string.format("%.1f, %.1f", x, y)
  Waypoints:SetManual({ mapID = mapID, x = x / 100, y = y / 100, label = label })
  Pathwise:Printf(L.WAY_SET, label)
end, L.CMD_WAY)

-- /pw next: same as the arrow's Next button.
Pathwise:RegisterCommand("next", function()
  Waypoints:Next()
end, L.CMD_NEXT)

-- /pw arrow: toggle following the Next Steps automatically.
Pathwise:RegisterCommand("arrow", function()
  Pathwise.db.arrowAuto = not Pathwise.db.arrowAuto
  Pathwise:Print(Pathwise.db.arrowAuto and L.ARROW_AUTO_ON or L.ARROW_AUTO_OFF)
  Changed()
end, L.CMD_ARROW)
