local addonName, Pathwise = ...

-- Next Steps: collects recommendations from all modules into one ordered
-- list for the Next Steps window.
--
-- Each module owns a "source" and replaces all of its items at once with
-- SetItems, so resolved items simply disappear on the next update.
-- Item: { id, priority, text, detail = { lines } or nil, color = "rrggbb" }
-- Higher priority comes first; ties keep the order the module gave.
--
-- Callbacks fired:
--   NEXT_STEPS_UPDATED (items)

local NextSteps = Pathwise:NewModule("NextSteps")

-- Shared priority scale, so modules interleave sensibly.
NextSteps.PRIORITY = {
  AMMO_CRITICAL = 95,
  PET_UNHAPPY = 92,
  QUEST_TURN_IN = 90,
  TAMING = 88,
  CLASS_QUEST = 88, -- class quests that teach something important
  QUEST_FAILED = 85,
  TALENT = 82,
  TRAINER = 80,
  PET_FEED = 74,
  QUEST_NEAR_ALMOST_DONE = 76,
  AMMO_LOW = 72,
  QUEST_ALMOST_DONE = 70,
  QUEST_NEAR = 66,
  PROFESSION_NEAR = 64, -- a profession step whose trainer is close by
  QUEST_HERE = 60,
  QUEST_FAR = 56, -- all far quest steps; QuestAdvisor orders them as a route
  CLASS_QUEST_OPTIONAL = 52, -- the other class quests: after the quests nearby
  QUEST_ELSEWHERE = 50,
  QUEST_ZONE = 49, -- nothing left nearby: try another zone
  PROFESSION_CAPPED = 48, -- skill at the cap: skill-ups are being wasted
  HEARTH = 47,     -- move the hearthstone (higher when the inn is close)
  PET_TEACH = 45,  -- teach the pet a rank the hunter knows
  PET_TAME = 44,   -- tame a beast to learn a better pet ability rank
  PROFESSION_TOOL = 46,
  PROFESSION_TRAIN = 42,
  PROFESSION_LEARN = 40,
  TALENT_RESPEC = 30,
  QUEST_LATER = 20,
  QUEST_GREY = 10,
}

local sources = {}     -- [source] = { items }
local sourceOrder = {} -- first-registration order, for stable sorting
local merged = {}

local function Rebuild()
  merged = {}
  for sourceIndex, source in ipairs(sourceOrder) do
    for itemIndex, item in ipairs(sources[source] or {}) do
      item.sortKey = sourceIndex * 1000 + itemIndex
      merged[#merged + 1] = item
    end
  end
  table.sort(merged, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    return a.sortKey < b.sortKey
  end)
end

function NextSteps:SetItems(source, items)
  if not sources[source] then
    sourceOrder[#sourceOrder + 1] = source
  end
  sources[source] = items or {}
  Rebuild()
  Pathwise:FireCallback("NEXT_STEPS_UPDATED", merged)
end

function NextSteps:GetItems()
  return merged
end
