local addonName, Pathwise = ...

-- Quest log advisor: follows the quest log live and turns it into ordered
-- Next Steps (turn in, almost done, do here, do elsewhere, later, grey).
-- Uses only what the client knows about the quests in the log; no quest
-- database needed.

local L = Pathwise.L
local Platform = Pathwise.Platform

local QuestAdvisor = Pathwise:NewModule("QuestAdvisor")

-- QUEST_LOG_UPDATE fires in bursts; wait this long and update once.
local UPDATE_DELAY = 0.3

-- A quest with at least this share of its objectives done is "almost done".
local ALMOST_DONE = 0.5

-- Quest steps whose location is within this distance count as nearby and
-- come first; farther ones wait (turn-ins included) until the nearby work
-- is done, then follow as a route (see RouteFar).
QuestAdvisor.NEAR_YARDS = 300

-- While the player moves, re-sort by distance after moving this far,
-- checking every MOVE_CHECK_SECONDS.
local MOVE_REPLAN_YARDS = 40
local MOVE_CHECK_SECONDS = 5

local lastPlanPosition -- { mapID, x, y } where the last plan was made
local lastPickups = {} -- the quests to pick up suggested by the last plan

-- Quests whose nearest objectives are this close to each other are done
-- together as one step (e.g. Timberling Seeds and Timberling Sprouts).
QuestAdvisor.TOGETHER_YARDS = 120

-- Far steps are done as a route: each next one is the closest to where the
-- previous one ends. Turn-ins and pickups count as this much closer than
-- they are (they're quick), but a far turn-in in the other direction
-- doesn't come before a much closer quest any more.
QuestAdvisor.TURN_IN_PULL = 0.75

-- Quests to pick up (from QuestieDB): at most this many, nearest first.
QuestAdvisor.MAX_PICKUPS = 4

-- "Next zone" suggestion: at most this many zones listed.
local MAX_ZONES = 3

local DIFFICULTY_COLORS = {
  RED = "ff2020",
  ORANGE = "ff8040",
  YELLOW = "ffd100",
  GREEN = "40c040",
  GREY = "808080",
}

local updatePending = false
local knownComplete -- [questID] = true; nil until the first scan

---------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------

-- Classic quest colors: red 5+ levels above, orange 3-4 above, yellow
-- within 2, green down to the green range, grey below that.
function QuestAdvisor.Difficulty(questLevel, playerLevel, greenRange)
  local diff = questLevel - playerLevel
  if diff >= 5 then
    return "RED"
  elseif diff >= 3 then
    return "ORANGE"
  elseif diff >= -2 then
    return "YELLOW"
  elseif -diff <= greenRange then
    return "GREEN"
  end
  return "GREY"
end

-- Share of objectives done (0..1), or nil for quests without objectives.
function QuestAdvisor.Progress(quest)
  local done, total = 0, 0
  for _, objective in ipairs(quest.objectives) do
    if objective.need and objective.need > 0 then
      done = done + math.min(objective.have or 0, objective.need)
      total = total + objective.need
    else
      done = done + (objective.finished and 1 or 0)
      total = total + 1
    end
  end
  if total == 0 then
    return nil
  end
  return done / total
end

local function QuestText(quest, difficulty)
  return string.format("|cff%s[%d] %s|r", DIFFICULTY_COLORS[difficulty], quest.level, quest.title)
end

local function Detail(quest)
  local lines = { quest.zone or "" }
  for _, objective in ipairs(quest.objectives) do
    local color = objective.finished and "|cff40c040" or "|cffffffff"
    lines[#lines + 1] = color .. "- " .. (objective.text or "?") .. "|r"
  end
  return lines
end

-- Ready to hand in: the client marks it complete, or it has no objectives
-- at all ("talk to X", "deliver this letter"), which the client never
-- reports as complete even though only the turn-in is left.
function QuestAdvisor.IsReady(quest)
  return quest.complete or (#quest.objectives == 0 and not quest.failed)
end

-- The step kind a quest needs an arrow target for, if any.
local function TargetKind(quest, difficulty)
  if quest.failed then
    return nil
  elseif QuestAdvisor.IsReady(quest) then
    return "turnIn"
  elseif quest.suggestedGroup >= 2 or difficulty == "RED" or difficulty == "GREY" then
    return nil
  end
  return "do"
end

-- Is the quest in the player's area? The quest log header is often a zone
-- name, but sometimes a subzone ("Shadowglen" while the client reports the
-- zone as Teldrassil and the subzone as Aldrassil), so a target on the
-- player's current map also counts.
local function IsHere(quest, location, target)
  if not location then
    return false
  end
  if quest.zone and (quest.zone == location.zone or quest.zone == location.subZone) then
    return true
  end
  return target ~= nil and location.mapID ~= nil and target.mapID == location.mapID
end

-- The target's tasks ("Kill Timberling", ...) as Next Steps sub-lines.
local function TaskLines(target, level)
  local lines = {}
  for _, task in ipairs(target and target.tasks or {}) do
    lines[#lines + 1] = { text = task, level = level, task = true }
  end
  return lines
end

-- Merges "do" steps whose targets are within TOGETHER_YARDS of each other
-- into one step: "Do together: A + B", with all their mobs in the target
-- macro and all their tasks under the arrow. Other items pass through.
function QuestAdvisor.CombineNearby(items)
  local Waypoints = Pathwise:GetModule("Waypoints")
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local function Close(a, b)
    local distance = Waypoints.Vector(a.target.mapID, a.target.x, a.target.y, b.target.mapID, b.target.x, b.target.y)
    return distance ~= nil and distance <= QuestAdvisor.TOGETHER_YARDS
  end

  local candidates, result = {}, {}
  for _, item in ipairs(items) do
    if item.kind == "do" and item.target and item.priority >= P.QUEST_ELSEWHERE then
      candidates[#candidates + 1] = item
    else
      result[#result + 1] = item
    end
  end

  local grouped = {}
  for _, seed in ipairs(candidates) do
    if not grouped[seed] then
      local group = { seed }
      grouped[seed] = true
      -- Grow the group with anything close to any member.
      local added = true
      while added do
        added = false
        for _, other in ipairs(candidates) do
          if not grouped[other] then
            for _, member in ipairs(group) do
              if Close(member, other) then
                group[#group + 1] = other
                grouped[other] = true
                added = true
                break
              end
            end
          end
        end
      end

      if #group == 1 then
        result[#result + 1] = seed
      else
        -- Nearest member first; it provides the arrow position.
        table.sort(group, function(a, b)
          return (a.distance or math.huge) < (b.distance or math.huge)
        end)
        local names, titles, ids, detail, npcNames, tasks, subLines = {}, {}, {}, {}, {}, {}, {}
        local seenNpc, seenTask = {}, {}
        local priority = 0
        for _, member in ipairs(group) do
          names[#names + 1] = member.questName
          titles[#titles + 1] = member.title
          ids[#ids + 1] = member.id
          priority = math.max(priority, member.priority)
          detail[#detail + 1] = member.questName
          for _, line in ipairs(member.detail or {}) do
            detail[#detail + 1] = "  " .. line
          end
          -- Each quest with its own tasks under it.
          subLines[#subLines + 1] = { text = member.questName, level = 1 }
          for _, line in ipairs(TaskLines(member.target, 2)) do
            subLines[#subLines + 1] = line
          end
          for _, npc in ipairs(member.target.names or {}) do
            if not seenNpc[npc] then
              seenNpc[npc] = true
              npcNames[#npcNames + 1] = npc
            end
          end
          for _, task in ipairs(member.target.tasks or {}) do
            if not seenTask[task] then
              seenTask[task] = true
              tasks[#tasks + 1] = task
            end
          end
        end
        local nearest = group[1]
        local target = {}
        for key, value in pairs(nearest.target) do
          target[key] = value
        end
        target.names, target.tasks = npcNames, tasks
        -- Short arrow label: where it points now, plus how many more quests.
        local more = #group == 2 and L.ARROW_MORE_QUEST or string.format(L.ARROW_MORE_QUESTS, #group - 1)
        target.label = (nearest.target.label or nearest.title) .. more
        local distanceText = nearest.distance and string.format(L.QA_DISTANCE, Pathwise.FormatDistance(nearest.distance)) or ""
        result[#result + 1] = {
          id = table.concat(ids, "+"),
          priority = priority,
          text = string.format(L.QA_TOGETHER, table.concat(names, " + ")) .. distanceText,
          -- When it's the current step, the quests are listed underneath.
          expandedText = string.format(L.QA_TOGETHER_COUNT, #group) .. distanceText,
          subLines = subLines,
          detail = detail,
          target = target,
          kind = "do",
          distance = nearest.distance,
          order = nearest.order,
        }
      end
    end
  end
  return result
end

-- Pure function (apart from map geometry): quests -> Next Steps items, in
-- recommended order. Steps with a known location are ordered by distance:
-- nearby ones (NEAR_YARDS) first, far ones after the steps without a
-- location, as a route (RouteFar).
-- location: { zone, subZone, mapID, x, y } of the player.
-- locate(quest, kind) optionally returns an arrow target for a quest
-- ("turnIn" for complete quests, "do" for quests to work on).
-- pickups: optional quests to pick up (QuestieData:GetPickups), which join
-- the same near/far order as kind "pickup".
function QuestAdvisor.Plan(quests, playerLevel, greenRange, location, locate, pickups)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local items = {}

  for _, quest in ipairs(quests) do
    local difficulty = QuestAdvisor.Difficulty(quest.level, playerLevel, greenRange)
    local progress = QuestAdvisor.Progress(quest)
    local targetKind = TargetKind(quest, difficulty)
    local target = targetKind and locate and locate(quest, targetKind) or nil
    local here = IsHere(quest, location, target)
    local name = QuestText(quest, difficulty)
    local priority, text

    local distance
    if target and location and location.mapID and location.x then
      distance = Pathwise:GetModule("Waypoints").TravelDistance(location.mapID, location.x, location.y,
        target.mapID, target.x, target.y)
    end
    local near = distance ~= nil and distance <= QuestAdvisor.NEAR_YARDS
    local far = distance ~= nil and not near

    if quest.failed then
      priority, text = P.QUEST_FAILED, string.format(L.QA_FAILED, name)
    elseif QuestAdvisor.IsReady(quest) then
      priority = far and P.QUEST_FAR or P.QUEST_TURN_IN
      text = string.format(L.QA_TURN_IN, name)
    elseif quest.suggestedGroup >= 2 then
      priority, text = P.QUEST_LATER, string.format(L.QA_GROUP, name, quest.suggestedGroup)
    elseif difficulty == "RED" then
      priority, text = P.QUEST_LATER, string.format(L.QA_LATER, quest.level - 2, name)
    elseif difficulty == "GREY" then
      priority, text = P.QUEST_GREY, string.format(L.QA_GREY, name)
    elseif progress and progress >= ALMOST_DONE then
      priority = near and P.QUEST_NEAR_ALMOST_DONE or far and P.QUEST_FAR or P.QUEST_ALMOST_DONE
      text = string.format(L.QA_ALMOST_DONE, name, progress * 100)
    elseif near then
      priority, text = P.QUEST_NEAR, string.format(L.QA_HERE, name)
    elseif here then
      priority, text = far and P.QUEST_FAR or P.QUEST_HERE, string.format(L.QA_HERE, name)
    else
      -- (Another zone; with a known location it joins the far route.)
      priority = far and P.QUEST_FAR or P.QUEST_ELSEWHERE
      text = string.format(L.QA_ELSEWHERE, name, quest.zone or "?")
    end
    if difficulty == "ORANGE" and priority >= P.QUEST_ELSEWHERE and not QuestAdvisor.IsReady(quest) then
      text = text .. " " .. L.QA_HARD
    end
    if distance and priority >= P.QUEST_ELSEWHERE then
      text = text .. string.format(L.QA_DISTANCE, Pathwise.FormatDistance(distance))
    end

    items[#items + 1] = {
      id = "quest:" .. tostring(quest.questID or quest.title),
      priority = priority,
      text = text,
      detail = Detail(quest),
      target = target,
      kind = targetKind,
      title = quest.title,
      questName = name,
      distance = distance,
      -- What to do, shown under the line when it's the current step.
      subLines = TaskLines(target, 1),
      -- Within a priority: nearest first, then current zone, then most
      -- progress, then lowest level (easiest first).
      order = { distance or math.huge, here and 0 or 1, -(progress or 0), quest.level },
    }
  end

  for _, pickup in ipairs(pickups or {}) do
    local difficulty = QuestAdvisor.Difficulty(pickup.level, playerLevel, greenRange)
    local name = QuestText(pickup, difficulty)
    local near = pickup.distance <= QuestAdvisor.NEAR_YARDS
    items[#items + 1] = {
      id = "pickup:" .. pickup.questID,
      priority = near and P.QUEST_NEAR or P.QUEST_FAR,
      text = string.format(L.QA_PICKUP, name) .. string.format(L.QA_DISTANCE, Pathwise.FormatDistance(pickup.distance)),
      detail = { string.format(L.QA_PICKUP_DETAIL, pickup.giver or "?") },
      target = pickup.target,
      kind = "pickup",
      title = pickup.title,
      questName = name,
      distance = pickup.distance,
      subLines = { { text = string.format(L.TASK_PICKUP, pickup.giver or "?"), level = 1, task = true } },
      order = { pickup.distance, 0, 0, pickup.level },
    }
  end

  items = QuestAdvisor.CombineNearby(items)

  table.sort(items, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    for i = 1, 4 do
      if a.order[i] ~= b.order[i] then
        return a.order[i] < b.order[i]
      end
    end
    return a.text < b.text
  end)
  QuestAdvisor.RouteFar(items, location)
  return items
end

-- Reorders the far steps (all QUEST_FAR, so next to each other after the
-- sort) into a route: starting at the player, always go to the closest
-- remaining step from where the last one was, turn-ins pulled closer by
-- TURN_IN_PULL. Without this, a far turn-in to the west came before a much
-- closer quest to the east, and the player crossed the zone twice.
function QuestAdvisor.RouteFar(items, location)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local first, last
  for index, item in ipairs(items) do
    if item.priority == P.QUEST_FAR then
      first, last = first or index, index
    end
  end
  if not first or not location or not location.mapID or not location.x then
    return
  end
  local Waypoints = Pathwise:GetModule("Waypoints")
  local pending = {}
  for index = first, last do
    pending[#pending + 1] = items[index]
  end
  local at = location
  for index = first, last do
    local bestIndex, bestCost
    for candidate, item in ipairs(pending) do
      local target = item.target
      local distance = Waypoints.TravelDistance(at.mapID, at.x, at.y, target.mapID, target.x, target.y) or math.huge
      local quick = item.kind == "turnIn" or item.kind == "pickup"
      local cost = distance * (quick and QuestAdvisor.TURN_IN_PULL or 1)
      if not bestCost or cost < bestCost then
        bestIndex, bestCost = candidate, cost
      end
    end
    items[index] = table.remove(pending, bestIndex)
    at = items[index].target
  end
end

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------

function QuestAdvisor:Update()
  local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
  local level = snapshot.level or 1
  local quests, collapsed = Platform.GetQuestLog()
  local zone = snapshot.zone or {}
  local mapID, x, y = Platform.GetPlayerMapPosition()
  local location = { zone = zone.zone, subZone = zone.subZone, mapID = mapID, x = x, y = y }
  lastPlanPosition = mapID and { mapID = mapID, x = x, y = y } or nil
  local QuestLocations = Pathwise:GetModule("QuestLocations")
  local QuestieData = Pathwise:GetModule("QuestieData")
  QuestLocations:OnQuestsScanned(quests)
  -- QuestieDB knows exact locations; learned spots are the fallback.
  local function Locate(quest, kind)
    return QuestieData:GetTarget(quest, kind) or QuestLocations:GetTarget(quest, kind)
  end
  local greenRange = Platform.GetQuestGreenRange(level)
  -- Quests to pick up (nil while QuestieDB's quest list is being scanned,
  -- or without QuestieDB).
  local pickups
  if Pathwise.db.questPickups then
    local inLog = {}
    for _, quest in ipairs(quests) do
      if quest.questID then
        inLog[quest.questID] = true
      end
    end
    local notOffered = Pathwise.charDB.notOffered
    pickups = QuestieData:GetPickups({
      level = level,
      inLog = inLog,
      isGrey = function(questLevel)
        return QuestAdvisor.Difficulty(questLevel, level, greenRange) == "GREY"
      end,
      -- The giver didn't offer it when the player talked to them at this
      -- level (see OnQuestGiverShown); try again after a level up.
      skip = function(questID)
        return notOffered[questID] ~= nil and level <= notOffered[questID]
      end,
    }, QuestAdvisor.MAX_PICKUPS)
  end
  lastPickups = pickups or {}
  local items = QuestAdvisor.Plan(quests, level, greenRange, location, Locate, pickups)
  local zoneItem = pickups and QuestAdvisor.NextZoneItem(items, level, snapshot.faction, zone.zone)
  if zoneItem then
    items[#items + 1] = zoneItem
  end

  if #collapsed > 0 then
    items[#items + 1] = {
      id = "quest:collapsed",
      priority = 0,
      text = string.format(L.QA_COLLAPSED, table.concat(collapsed, ", ")),
    }
  end
  Pathwise:GetModule("NextSteps"):SetItems("quests", items)

  -- Chat nudge when a quest becomes complete (not for quests that were
  -- already complete when we first looked).
  local nowComplete = {}
  for _, quest in ipairs(quests) do
    if quest.complete and quest.questID then
      nowComplete[quest.questID] = true
      if knownComplete and not knownComplete[quest.questID] and Pathwise.db.chatMessages then
        Pathwise:Printf(L.QA_NOW_COMPLETE, quest.title)
      end
    end
  end
  knownComplete = nowComplete
end

-- When there's nothing left to pick up on this continent and nothing to do
-- from the quest log: a step suggesting zones for the player's level
-- (Data/Classic/Zones.lua), or nil.
function QuestAdvisor.NextZoneItem(items, level, faction, currentZone)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  for _, item in ipairs(items) do
    if item.priority >= P.QUEST_ELSEWHERE and (item.kind == "do" or item.kind == "turnIn" or item.kind == "pickup") then
      return nil
    end
  end
  local zones = {}
  for _, zone in ipairs(Pathwise.Data.Zones[faction] or {}) do
    if zone.min <= level and level < zone.max and zone.name ~= currentZone and #zones < MAX_ZONES then
      zones[#zones + 1] = string.format(L.ZONE_RANGE, zone.name, zone.min, zone.max)
    end
  end
  if #zones == 0 then
    return nil
  end
  return {
    id = "zone:next",
    priority = P.QUEST_ZONE,
    text = string.format(L.ZONE_NEXT, zones[1]),
    detail = { string.format(L.ZONE_OPTIONS, table.concat(zones, ", ")), L.ZONE_DETAIL },
  }
end

-- Talking to an NPC whose window lists every quest they offer: a suggested
-- pickup from this NPC that isn't in the list isn't really available (the
-- quest database can be wrong, or a condition isn't known to Pathwise).
-- Remember that, so it isn't suggested again at this level.
function QuestAdvisor:OnQuestGiverShown(event)
  local npc = Platform.GetInteractionNPCName()
  local offered = Platform.GetOfferedQuests(event)
  if not npc or not offered then
    return
  end
  local ids, titles = {}, {}
  for _, quest in ipairs(offered) do
    if quest.questID then
      ids[quest.questID] = true
    end
    if quest.title then
      titles[quest.title] = true
    end
  end
  local level = Pathwise:GetModule("Character"):GetSnapshot().level or 1
  local changed = false
  for _, pickup in ipairs(lastPickups) do
    if pickup.giver == npc and not ids[pickup.questID] and not titles[pickup.title] then
      Pathwise.charDB.notOffered[pickup.questID] = level
      self:Debugf("%s doesn't offer %s (%d); not suggested again at this level.", npc, pickup.title, pickup.questID)
      changed = true
    end
  end
  if changed then
    self:ScheduleUpdate()
  end
end

function QuestAdvisor:ScheduleUpdate()
  if updatePending then
    return
  end
  updatePending = true
  Platform.After(UPDATE_DELAY, function()
    updatePending = false
    QuestAdvisor:Update()
  end)
end

local UPDATE_SECTIONS = { all = true, level = true, zone = true }

function QuestAdvisor:OnCharacterUpdated(_, _, section)
  if UPDATE_SECTIONS[section] then
    self:ScheduleUpdate()
  end
end

function QuestAdvisor:OnQuestEvent()
  self:ScheduleUpdate()
end

function QuestAdvisor:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
  -- Reached a spawn the arrow pointed at: pick the next one.
  self:RegisterCallback("WAYPOINT_VISITED", "OnQuestEvent")
  -- QuestieDB's quest list is scanned: pickups can be suggested now.
  self:RegisterCallback("QUESTIE_PICKUPS_READY", "OnQuestEvent")
end

-- Re-plans when the player has moved far enough since the last plan, so
-- the order (and the arrow) keeps following what's nearest.
function QuestAdvisor:CheckMovement()
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if not mapID or not lastPlanPosition then
    return
  end
  local moved = Pathwise:GetModule("Waypoints").Vector(lastPlanPosition.mapID, lastPlanPosition.x,
    lastPlanPosition.y, mapID, x, y)
  if not moved or moved >= MOVE_REPLAN_YARDS then
    self:ScheduleUpdate()
  end
end

function QuestAdvisor:OnEnable()
  Platform.Every(MOVE_CHECK_SECONDS, function()
    QuestAdvisor:CheckMovement()
  end)
  self:RegisterEvent("QUEST_LOG_UPDATE", "OnQuestEvent")
  self:RegisterEvent("QUEST_ACCEPTED", "OnQuestEvent")
  self:RegisterEvent("QUEST_REMOVED", "OnQuestEvent")
  self:RegisterEvent("QUEST_TURNED_IN", "OnQuestEvent")
  self:RegisterEvent("GOSSIP_SHOW", "OnQuestGiverShown")
  self:RegisterEvent("QUEST_GREETING", "OnQuestGiverShown")
end

---------------------------------------------------------------------------
-- /pw quests
---------------------------------------------------------------------------

Pathwise:RegisterCommand("quests", function()
  QuestAdvisor:Update()
  local any = false
  for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
    if item.id:find("^quest:") then
      if not any then
        Pathwise:Print(L.QA_HEADER)
        any = true
      end
      Pathwise:PrintLine("  " .. item.text)
    end
  end
  if not any then
    Pathwise:Print(L.QA_NONE)
  end
end, L.CMD_QUESTS)

-- How distances are shown: "meters" or "yards". The step texts carry them,
-- so the plan is rebuilt; the arrow follows by itself. Fires
-- DISTANCE_UNIT_CHANGED (unit).
function QuestAdvisor:SetDistanceUnit(unit)
  Pathwise.db.distanceUnit = unit == "yards" and "yards" or "meters"
  self:Update()
  Pathwise:FireCallback("DISTANCE_UNIT_CHANGED", Pathwise.db.distanceUnit)
end

-- /pw units meters|yards (also in the settings: General > Distances)
Pathwise:RegisterCommand("units", function(args)
  args = args:lower()
  if args == "meters" or args == "m" or args == "yards" or args == "yd" then
    local yards = args == "yards" or args == "yd"
    QuestAdvisor:SetDistanceUnit(yards and "yards" or "meters")
    Pathwise:Print(yards and L.UNITS_SET_YARDS or L.UNITS_SET_METERS)
  else
    Pathwise:Print(L.UNITS_USAGE)
  end
end, L.CMD_UNITS)

-- /pw pickups on|off: suggest quests to pick up (needs QuestieDB)
Pathwise:RegisterCommand("pickups", function(args)
  args = args:lower()
  if args == "on" or args == "off" then
    Pathwise.db.questPickups = args == "on"
    Pathwise:Print(args == "on" and L.PICKUPS_ON or L.PICKUPS_OFF)
    QuestAdvisor:Update()
  else
    Pathwise:Print(L.PICKUPS_USAGE)
  end
end, L.CMD_PICKUPS)
