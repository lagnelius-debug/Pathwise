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
-- the same near/far order as kind "pickup"; class quest steps
-- (Classes/ClassQuests.lua, with classQuest = true) join it the same way.
-- A pickup's note is added to its details. anyZone: see RouteFar.
-- A class quest step as a quest to pick up: near or far by its distance.
-- The important ones (urgent) are never held back for "finish the zone
-- first" (RouteFar).
local function ClassQuestItem(step)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local near = step.distance ~= nil and step.distance <= QuestAdvisor.NEAR_YARDS
  local text = step.text
  if step.distance then
    text = text .. string.format(L.QA_DISTANCE, Pathwise.FormatDistance(step.distance))
  end
  local giver = step.target.npcName or (step.target.names and step.target.names[1]) or "?"
  return {
    id = "classquest:" .. step.key,
    priority = near and P.QUEST_NEAR or P.QUEST_FAR,
    urgent = step.important,
    text = text,
    detail = { step.detail },
    target = step.target,
    kind = "pickup",
    title = step.text,
    questName = step.text,
    distance = step.distance,
    subLines = { { text = string.format(L.TASK_PICKUP, giver), level = 1, task = true } },
    order = { step.distance or math.huge, 0, 0, 0 },
  }
end

function QuestAdvisor.Plan(quests, playerLevel, greenRange, location, locate, pickups, anyZone)
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

  local Travel = Pathwise:GetModule("Travel")
  for _, pickup in ipairs(pickups or {}) do
    if pickup.classQuest then
      items[#items + 1] = ClassQuestItem(pickup)
    else
      local difficulty = QuestAdvisor.Difficulty(pickup.level, playerLevel, greenRange)
      local name = QuestText(pickup, difficulty)
      local near = pickup.distance <= QuestAdvisor.NEAR_YARDS
      local detail = { string.format(L.QA_PICKUP_DETAIL, pickup.giver or "?") }
      -- Turned in in another zone (e.g. "Flight to Auberdine"): taking it
      -- leads away, so it waits until the steps in this zone are done.
      local leadsAway = pickup.finishMapID ~= nil
        and Travel.ZoneGroup(pickup.finishMapID) ~= Travel.ZoneGroup(pickup.target.mapID)
      if leadsAway then
        detail[#detail + 1] = string.format(L.QA_PICKUP_LEADS_AWAY, Platform.GetMapName(pickup.finishMapID) or "?")
      end
      if pickup.note then
        detail[#detail + 1] = pickup.note
      end
      items[#items + 1] = {
        id = "pickup:" .. pickup.questID,
        priority = (near and not leadsAway) and P.QUEST_NEAR or P.QUEST_FAR,
        leadsAway = leadsAway,
        text = string.format(L.QA_PICKUP, name) .. string.format(L.QA_DISTANCE, Pathwise.FormatDistance(pickup.distance)),
        detail = detail,
        target = pickup.target,
        kind = "pickup",
        title = pickup.title,
        questName = name,
        distance = pickup.distance,
        subLines = { { text = string.format(L.TASK_PICKUP, pickup.giver or "?"), level = 1, task = true } },
        order = { pickup.distance, 0, 0, pickup.level },
      }
    end
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
  QuestAdvisor.RouteFar(items, location, anyZone)
  return items
end

-- Reorders the far steps (all QUEST_FAR, so next to each other after the
-- sort) into a route: starting at the player, always go to the closest
-- remaining step from where the last one was, turn-ins pulled closer by
-- TURN_IN_PULL. Without this, a far turn-in to the west came before a much
-- closer quest to the east, and the player crossed the zone twice.
-- The zone is finished before leaving it: steps in the player's zone (its
-- capital included) come first, then steps elsewhere and pickups that lead
-- away - otherwise e.g. the boat from Rut'theran to Darkshore "won" over
-- the turn-ins still waiting up on Teldrassil.
-- anyZone: no "finish the zone first" (dungeon mode).
function QuestAdvisor.RouteFar(items, location, anyZone)
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
  local Travel = Pathwise:GetModule("Travel")
  local zone = Travel.ZoneGroup(location.mapID)
  local function InZone(item)
    return anyZone or item.urgent or (not item.leadsAway and Travel.ZoneGroup(item.target.mapID) == zone)
  end
  local pending = {}
  for index = first, last do
    pending[#pending + 1] = items[index]
  end
  local at = location
  for index = first, last do
    local zoneLeft = false
    for _, item in ipairs(pending) do
      zoneLeft = zoneLeft or InZone(item)
    end
    local bestIndex, bestCost
    for candidate, item in ipairs(pending) do
      -- While steps in this zone are left, only they count.
      if not zoneLeft or InZone(item) then
        local target = item.target
        local distance = Waypoints.TravelDistance(at.mapID, at.x, at.y, target.mapID, target.x, target.y) or math.huge
        local quick = item.kind == "turnIn" or item.kind == "pickup"
        local cost = distance * (quick and QuestAdvisor.TURN_IN_PULL or 1)
        if not bestCost or cost < bestCost then
          bestIndex, bestCost = candidate, cost
        end
      end
    end
    items[index] = table.remove(pending, bestIndex)
    at = items[index].target
  end
end

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------

-- What the quest pickups are chosen with (QuestieData:GetPickups).
local function PickupContext(quests, level, greenRange)
  local inLog = {}
  for _, quest in ipairs(quests) do
    if quest.questID then
      inLog[quest.questID] = true
    end
  end
  local notOffered = Pathwise.charDB.notOffered
  return {
    level = level,
    inLog = inLog,
    -- Too easy (grey) or far too hard (red, e.g. the level 60 cloth
    -- donations that can be picked up at 12): not worth suggesting.
    outOfRange = function(questLevel)
      local difficulty = QuestAdvisor.Difficulty(questLevel, level, greenRange)
      return difficulty == "GREY" or difficulty == "RED"
    end,
    -- The giver didn't offer it when the player talked to them at this
    -- level (see OnQuestGiverShown); try again after a level up.
    -- A class quest reminder already points at the quest.
    skip = function(questID)
      return notOffered[questID] ~= nil and level <= notOffered[questID]
        or Pathwise:GetModule("ClassQuests"):Covers(questID)
    end,
  }
end

-- Whether the guide suggests a quest (Core/AutoAccept.lua): a quest of an
-- open class quest, or one it would suggest picking up - with the same
-- rules as the pickups, wherever its giver is (so the next quest of a chain
-- counts too). By ID, or by title when the client gives no ID.
function QuestAdvisor:IsSuggested(questID, title)
  if questID and Pathwise:GetModule("ClassQuests"):Suggests(questID) then
    return true
  end
  local level = Pathwise:GetModule("Character"):GetSnapshot().level or 1
  local ctx = PickupContext(Platform.GetQuestLog(), level, Platform.GetQuestGreenRange(level))
  local QuestieData = Pathwise:GetModule("QuestieData")
  -- Dungeon mode: the dungeon's quests and pre-quests, whatever their
  -- level (as the dungeon plan suggests them).
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local dungeon = DungeonGuide:GetActive()
  local belongs = dungeon and DungeonGuide:GetQuests(dungeon)
  if belongs and (not questID or belongs.quests[questID]) then
    local dungeonCtx = PickupContext(Platform.GetQuestLog(), level, Platform.GetQuestGreenRange(level))
    dungeonCtx.outOfRange = function() return false end
    dungeonCtx.only = belongs.quests
    if QuestieData:WouldSuggest(questID, title, dungeonCtx) then
      return true
    end
  end
  if not (Pathwise.db.questGuide and Pathwise.db.questPickups) then
    return false
  end
  return QuestieData:WouldSuggest(questID, title, ctx) == true
end

-- Dungeon mode (Core/DungeonGuide.lua): only the dungeon's quests and the
-- ones that lead to them, planned like the usual steps but without
-- "finish the zone first"; the dungeon's own quests point at the entrance.
local DUNGEON_MAX_PICKUPS = 12

-- Inside a dungeon: the game gives no position there (no arrow), so the
-- list says where instead - one step per boss the quests need, in the
-- dungeon's order ("Boss 7 of 8: Edwin VanCleef - the top deck of the
-- ship") with what to do there, the objectives on other mobs "along the
-- way", and the quests already done. For the dungeon's quests and any
-- other quest that needs one of its bosses.
local function InsidePlan(dungeon, quests, level, greenRange)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local QuestieData = Pathwise:GetModule("QuestieData")
  local belongs = DungeonGuide:GetQuests(dungeon)
  local bosses = {}  -- [boss index] = { lines }
  local along, done = {}, {}
  for _, quest in ipairs(quests) do
    local tasks = QuestieData:QuestTasks(quest) or {}
    local name = QuestText(quest, QuestAdvisor.Difficulty(quest.level, level, greenRange))
    local forBoss, forOther = {}, {}
    for _, task in ipairs(tasks) do
      local bossIndex
      for _, npc in ipairs(task.npcs or {}) do
        bossIndex = bossIndex or DungeonGuide.Boss(dungeon, npc)
      end
      if task.kind == "kill" then
        local line = string.format(L.INSIDE_KILL, task.npcs[1] or "?")
        table.insert(bossIndex and forBoss or forOther, { index = bossIndex, text = line })
      elseif task.kind == "loot" then
        -- From the boss when a boss drops it; else up to two of the mobs.
        local from = bossIndex and dungeon.bosses[bossIndex][1]
          or #task.npcs > 0 and table.concat(task.npcs, ", ", 1, math.min(#task.npcs, 2))
        local line = from and string.format(L.INSIDE_LOOT_FROM, task.item, from) or string.format(L.INSIDE_LOOT, task.item)
        table.insert(bossIndex and forBoss or forOther, { index = bossIndex, text = line })
      else
        table.insert(forOther, { text = string.format(L.INSIDE_USE, task.object or "?") })
      end
    end
    local mine = (belongs and belongs.inDungeon[quest.questID]) or #forBoss > 0
    if mine and QuestAdvisor.IsReady(quest) then
      done[#done + 1] = quest
    elseif mine then
      for _, task in ipairs(forBoss) do
        bosses[task.index] = bosses[task.index] or {}
        table.insert(bosses[task.index], { text = string.format(L.INSIDE_FOR, task.text, name), level = 1, task = true })
      end
      local lines = {}
      for _, task in ipairs(forOther) do
        lines[#lines + 1] = { text = task.text, level = 1, task = true }
      end
      -- A dungeon quest QuestieDB has no objectives for: the game's own.
      if #tasks == 0 then
        for _, objective in ipairs(quest.objectives or {}) do
          if not objective.finished and objective.text then
            lines[#lines + 1] = { text = objective.text, level = 1, task = true }
          end
        end
      end
      if #lines > 0 or (#forBoss == 0 and #tasks == 0) then
        along[#along + 1] = { quest = quest, name = name, lines = lines }
      end
    end
  end

  -- (The next boss first: the To-do window opens up the first step.)
  local items = {}
  for index, boss in ipairs(dungeon.bosses or {}) do
    if bosses[index] then
      items[#items + 1] = { id = "inside:boss:" .. index, priority = P.QUEST_NEAR,
        text = string.format(L.INSIDE_BOSS, index, #dungeon.bosses, boss[1], boss[2]), subLines = bosses[index] }
    end
  end
  for _, entry in ipairs(along) do
    items[#items + 1] = { id = "inside:along:" .. tostring(entry.quest.questID or entry.quest.title), priority = P.QUEST_NEAR,
      text = string.format(L.INSIDE_ALONG, entry.name), subLines = entry.lines }
  end
  for _, quest in ipairs(done) do
    items[#items + 1] = { id = "inside:done:" .. tostring(quest.questID or quest.title), priority = P.QUEST_ELSEWHERE,
      text = string.format(L.INSIDE_DONE, QuestText(quest, QuestAdvisor.Difficulty(quest.level, level, greenRange))) }
  end
  if #items == 0 then
    items[1] = { id = "inside:none", priority = P.QUEST_ELSEWHERE, text = string.format(L.INSIDE_NONE, dungeon.name) }
  end
  return items
end

local function DungeonPlan(dungeon, quests, level, greenRange, location, Locate)
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local belongs = DungeonGuide:GetQuests(dungeon)
  local items = {}
  if belongs then
    local mine = {}
    for _, quest in ipairs(quests) do
      if quest.questID and belongs.quests[quest.questID] then
        mine[#mine + 1] = quest
      end
    end
    local entrance = DungeonGuide:EntranceTarget(dungeon)
    local function DungeonLocate(quest, kind)
      if kind == "do" and entrance and belongs.inDungeon[quest.questID] then
        return entrance -- (its objectives are inside)
      end
      return Locate(quest, kind)
    end
    local ctx = PickupContext(quests, level, greenRange)
    ctx.only = belongs.quests
    -- Pre-quests count whatever their level (a grey one can still unlock
    -- the chain).
    ctx.outOfRange = function() return false end
    local pickups = Pathwise:GetModule("QuestieData"):GetPickups(ctx, DUNGEON_MAX_PICKUPS) or {}
    for _, pickup in ipairs(pickups) do
      pickup.finishMapID = nil
      if not belongs.inDungeon[pickup.questID] then
        pickup.note = string.format(L.DUNGEON_PREQUEST, dungeon.name)
      end
    end
    items = QuestAdvisor.Plan(mine, level, greenRange, location, DungeonLocate, pickups, true)
    lastPickups = pickups -- (so "not offered" is learned here too)
  end
  for _, item in ipairs(DungeonGuide:ExtraItems(dungeon, quests)) do
    items[#items + 1] = item
  end
  return items
end

function QuestAdvisor:Update()
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local inside = DungeonGuide:GetInside()
  local dungeon = DungeonGuide:GetActive()
  if not Pathwise.db.questGuide and not dungeon and not inside then
    lastPickups = {}
    Pathwise:GetModule("NextSteps"):SetItems("quests", {})
    Pathwise:FireCallback("QUESTS_PLANNED", {})
    return
  end
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
  local items
  if inside then
    lastPickups = {}
    items = InsidePlan(inside, quests, level, greenRange)
  elseif dungeon then
    lastPickups = {}
    items = DungeonPlan(dungeon, quests, level, greenRange, location, Locate)
  else
    -- Class quest steps first: the pickups below leave their quests out.
    local ClassQuests = Pathwise:GetModule("ClassQuests")
    local classSteps = ClassQuests:GetSteps()
    -- Quests to pick up (nil while QuestieDB's quest list is being scanned,
    -- or without QuestieDB).
    local pickups
    if Pathwise.db.questPickups then
      pickups = QuestieData:GetPickups(PickupContext(quests, level, greenRange), QuestAdvisor.MAX_PICKUPS)
    end
    lastPickups = pickups or {}
    -- Class quest steps with a known giver join the plan like pickups.
    local planned = {}
    for _, pickup in ipairs(pickups or {}) do
      planned[#planned + 1] = pickup
    end
    for _, step in ipairs(classSteps) do
      if ClassQuests.InQuestPlan(step) then
        step.classQuest = true
        step.distance = mapID and Pathwise:GetModule("Waypoints").TravelDistance(mapID, x, y,
          step.target.mapID, step.target.x, step.target.y, true)
        planned[#planned + 1] = step
      end
    end
    items = QuestAdvisor.Plan(quests, level, greenRange, location, Locate, planned)
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
  end
  Pathwise:GetModule("NextSteps"):SetItems("quests", items)
  -- (For the hearthstone tip: how much there is to do in this zone.)
  Pathwise:FireCallback("QUESTS_PLANNED", items)

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
