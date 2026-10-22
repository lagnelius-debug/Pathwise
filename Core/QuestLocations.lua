local addonName, Pathwise = ...

-- Quest locations learned while playing, so the arrow has somewhere to
-- point without a quest database:
--   pickup    where the player stood when accepting the quest (quest giver)
--   turnIn    where the player stood when turning it in
--   progress  spots where an objective advanced (kills, loot, ...)
-- Stored account-wide in PathwiseDB.questLocations[questID], so every
-- character benefits from what earlier characters recorded.

local L = Pathwise.L
local Platform = Pathwise.Platform

local QuestLocations = Pathwise:NewModule("QuestLocations")

-- Progress spots kept per quest (newest replace oldest).
local MAX_PROGRESS_POINTS = 8

local lastProgress = {} -- [questID] = progress 0..1 at the previous scan

local function Here()
  local mapID, x, y = Platform.GetPlayerMapPosition()
  if mapID then
    return { mapID = mapID, x = x, y = y }
  end
end

local function Entry(questID)
  local all = Pathwise.db.questLocations
  all[questID] = all[questID] or {}
  return all[questID]
end

function QuestLocations:Get(questID)
  return questID and Pathwise.db.questLocations[questID]
end

-- Returns a target { mapID, x, y, label } for a quest step, or nil.
-- kind: "turnIn" or "do".
function QuestLocations:GetTarget(quest, kind)
  local entry = self:Get(quest.questID)
  if not entry then
    return nil
  end
  if kind == "turnIn" then
    local spot = entry.turnIn or entry.pickup
    if spot then
      local label = entry.turnIn and string.format(L.ARROW_TURN_IN, quest.title)
        or string.format(L.ARROW_TURN_IN_PICKUP, quest.title)
      return { mapID = spot.mapID, x = spot.x, y = spot.y, label = label }
    end
    return nil
  end
  -- "do": the center of the recorded progress spots on the most used map.
  local points = entry.progress
  if not points or #points == 0 then
    return nil
  end
  local counts, bestMap = {}, nil
  for _, point in ipairs(points) do
    counts[point.mapID] = (counts[point.mapID] or 0) + 1
    if not bestMap or counts[point.mapID] > counts[bestMap] then
      bestMap = point.mapID
    end
  end
  local sumX, sumY, n = 0, 0, 0
  for _, point in ipairs(points) do
    if point.mapID == bestMap then
      sumX, sumY, n = sumX + point.x, sumY + point.y, n + 1
    end
  end
  return { mapID = bestMap, x = sumX / n, y = sumY / n, label = string.format(L.ARROW_DO, quest.title) }
end

-- Called by the quest advisor after each quest log scan.
function QuestLocations:OnQuestsScanned(quests)
  local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
  local seen = {}
  for _, quest in ipairs(quests) do
    local id = quest.questID
    if id then
      seen[id] = true
      local progress = QuestAdvisor.Progress(quest) or 0
      local before = lastProgress[id]
      if before and progress > before then
        local here = Here()
        if here then
          -- Spawns around here are done for now; the arrow moves on.
          local Waypoints = Pathwise:GetModule("Waypoints")
          Waypoints:MarkVisited(here, Waypoints.PROGRESS_RADIUS_YARDS)
          local entry = Entry(id)
          entry.progress = entry.progress or {}
          table.insert(entry.progress, here)
          if #entry.progress > MAX_PROGRESS_POINTS then
            table.remove(entry.progress, 1)
          end
        end
      end
      lastProgress[id] = progress
    end
  end
  for id in pairs(lastProgress) do
    if not seen[id] then
      lastProgress[id] = nil
    end
  end
end

-- QUEST_ACCEPTED passes (questLogIndex, questID) in Classic Era and
-- (questID) in newer clients.
function QuestLocations:QUEST_ACCEPTED(_, first, second)
  local questID = second or first
  local here = Here()
  if questID and here then
    Entry(questID).pickup = here
  end
end

function QuestLocations:QUEST_TURNED_IN(_, questID)
  local here = Here()
  if questID and here then
    Entry(questID).turnIn = here
  end
end

function QuestLocations:OnEnable()
  self:RegisterEvent("QUEST_ACCEPTED")
  self:RegisterEvent("QUEST_TURNED_IN")
end
