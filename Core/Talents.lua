local addonName, Pathwise = ...

-- Spec detection and the player's goal.
--
-- Classic Era has no formal spec choice, so Pathwise infers it:
--  1. The talent tree with the most points is the spec, unless the top two
--     trees are within Data.HybridMargin points of each other (hybrid).
--  2. With no points spent, or a hybrid, the player's chosen goal is used
--     (asked once by the goal prompt, changeable with /pw spec).
--  3. Without a goal, Data.DefaultGoal is used.
--
-- The talent advisor (next talent point) is added here in M5.
--
-- Callbacks fired:
--   SPEC_CHANGED          (specInfo)  the active spec key changed
--   GOAL_CHANGED          (goalKey)   the player picked a new goal (or nil)
--   GOAL_PROMPT_REQUESTED (options, currentGoal)  UI should show the prompt

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local Talents = Pathwise:NewModule("Talents")

-- Delay after login before the one-time goal prompt, so it doesn't appear
-- during the loading screen.
local PROMPT_DELAY_SECONDS = 3

-- The goal prompt is only shown automatically below this level, or when the
-- spec can't be inferred from talents.
local PROMPT_BELOW_LEVEL = 10

local specInfo
local promptChecked = false

---------------------------------------------------------------------------
-- Detection
---------------------------------------------------------------------------

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

-- Returns the spec key of the talent tree at tabIndex for a class.
local function TreeSpecKey(class, tabIndex)
  local classData = Data.ClassSpecs[class]
  return (classData and classData.trees[tabIndex]) or ("TREE" .. tabIndex)
end

-- Pure function: infers a spec from talent trees.
-- Returns detectedKey (nil if none/hybrid), isHybrid.
function Talents.DetectSpec(class, trees)
  local ranking = {}
  for _, tree in ipairs(trees) do
    ranking[#ranking + 1] = tree
  end
  table.sort(ranking, function(a, b)
    if a.points ~= b.points then
      return a.points > b.points
    end
    return a.index < b.index
  end)

  local top, second = ranking[1], ranking[2]
  if not top or top.points == 0 then
    return nil, false
  end
  if second and second.points > 0 and top.points - second.points <= Data.HybridMargin then
    return nil, true
  end
  return TreeSpecKey(class, top.index), false
end

function Talents:GetGoalOptions()
  local classData = Data.ClassSpecs[GetSnapshot().class]
  return (classData and classData.goals) or Data.GenericGoals
end

local function BuildSpecInfo()
  local snapshot = GetSnapshot()
  local trees = snapshot.talents.trees
  local detected, hybrid = Talents.DetectSpec(snapshot.class, trees)
  local goal = Pathwise.charDB.goal

  local points = {}
  for i, tree in ipairs(trees) do
    points[i] = tree.points
  end

  local info = {
    detected = detected,
    hybrid = hybrid,
    goal = goal,
    points = table.concat(points, "/"),
  }
  if detected then
    info.active, info.source = detected, "talents"
  elseif goal then
    info.active, info.source = goal, "goal"
  else
    info.active, info.source = Data.DefaultGoal, "default"
  end
  return info
end

-- Returns { active, source, detected, hybrid, goal, points }.
-- active is the spec/goal key other modules should use (stat weights,
-- talent build); source is "talents", "goal" or "default".
function Talents:GetSpecInfo()
  if not specInfo then
    specInfo = BuildSpecInfo()
  end
  return specInfo
end

function Talents:UpdateSpec()
  local old = specInfo
  specInfo = BuildSpecInfo()
  if not old or old.active ~= specInfo.active then
    self:Debugf("Active spec: %s (%s)", specInfo.active, specInfo.source)
    Pathwise:FireCallback("SPEC_CHANGED", specInfo)
  end
end

local function SpecName(key)
  return L["SPEC_" .. key]
end

-- One-line description for /pw status.
function Talents:DescribeSpec()
  local info = self:GetSpecInfo()
  local goalText = info.goal and SpecName(info.goal) or L.GOAL_NOT_SET
  if info.source == "talents" then
    return string.format(L.SPEC_FROM_TALENTS, SpecName(info.active), info.points, goalText)
  end
  local reason
  if info.hybrid then
    reason = string.format(L.SPEC_HYBRID, info.points)
  else
    reason = L.SPEC_NO_POINTS
  end
  if info.source == "goal" then
    return string.format(L.SPEC_USING_GOAL, reason, SpecName(info.active))
  end
  return string.format(L.SPEC_USING_DEFAULT, reason, SpecName(info.active))
end

---------------------------------------------------------------------------
-- Goal
---------------------------------------------------------------------------

local function Normalize(text)
  return (text:lower():gsub("[%s_%-]", ""))
end

-- Matches user input against the goal options: key, alias (BM, MM, ...),
-- display name, or an unambiguous prefix of either. Returns the key or nil.
function Talents:ParseGoal(text)
  local options = self:GetGoalOptions()
  local wanted = Normalize(text)
  if wanted == "" then
    return nil
  end

  local alias = Data.GoalAliases[wanted:upper()]
  for _, key in ipairs(options) do
    if key == alias or Normalize(key) == wanted or Normalize(SpecName(key)) == wanted then
      return key
    end
  end

  local match
  for _, key in ipairs(options) do
    local normalizedKey, normalizedName = Normalize(key), Normalize(SpecName(key))
    if normalizedKey:sub(1, #wanted) == wanted or normalizedName:sub(1, #wanted) == wanted then
      if match then
        return nil -- ambiguous
      end
      match = key
    end
  end
  return match
end

function Talents:SetGoal(key)
  Pathwise.charDB.goal = key
  Pathwise.charDB.goalPrompted = true
  if key then
    Pathwise:Printf(L.GOAL_SET, SpecName(key))
  else
    Pathwise:Print(L.GOAL_CLEARED)
  end
  Pathwise:FireCallback("GOAL_CHANGED", key)
  self:UpdateSpec()
end

function Talents:RequestGoalPrompt()
  Pathwise.charDB.goalPrompted = true
  Pathwise:FireCallback("GOAL_PROMPT_REQUESTED", self:GetGoalOptions(), Pathwise.charDB.goal)
end

-- Called by the UI when the prompt is closed without picking a goal.
function Talents:OnGoalPromptDismissed()
  if not Pathwise.charDB.goal then
    Pathwise:Printf(L.GOAL_DISMISSED, SpecName(Data.DefaultGoal))
  end
end

local function ShouldPrompt()
  local charDB = Pathwise.charDB
  if charDB.goal or charDB.goalPrompted then
    return false
  end
  local info = Talents:GetSpecInfo()
  return (GetSnapshot().level or 1) < PROMPT_BELOW_LEVEL or not info.detected
end

local function GoalOptionsText()
  local names = {}
  for _, key in ipairs(Talents:GetGoalOptions()) do
    names[#names + 1] = SpecName(key)
  end
  return table.concat(names, ", ")
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Talents:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
  self:RegisterCallback("CHARACTER_RESET", "OnCharacterReset")
end

local SPEC_SECTIONS = { all = true, level = true, talents = true }

function Talents:OnCharacterUpdated(_, snapshot, section)
  if not SPEC_SECTIONS[section] then
    return
  end
  self:UpdateSpec()

  if section == "all" and not promptChecked then
    promptChecked = true
    if ShouldPrompt() then
      Platform.After(PROMPT_DELAY_SECONDS, function()
        if ShouldPrompt() then
          Talents:RequestGoalPrompt()
        end
      end)
    end
  end
end

function Talents:OnCharacterReset()
  self:UpdateSpec()
end

Pathwise:RegisterCommand("spec", function(args)
  if args == "" then
    Talents:RequestGoalPrompt()
  elseif Normalize(args) == "clear" then
    Talents:SetGoal(nil)
  else
    local key = Talents:ParseGoal(args)
    if key then
      Talents:SetGoal(key)
    else
      Pathwise:Printf(L.GOAL_UNKNOWN, args, GoalOptionsText())
    end
  end
end, L.CMD_SPEC)
