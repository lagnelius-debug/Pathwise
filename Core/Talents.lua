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
-- Talent advisor: suggests the next talent point from the build for the
-- active spec/goal (Data/Classic/TalentBuilds.lua). If the player spent
-- points differently, it doesn't nag: it suggests the first build talent
-- that isn't filled yet and whose tier is open.
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
  -- The path the player chose wins, so changing it (e.g. Marksmanship to
  -- Beast Mastery) switches gear weights, trainer advice and the talent
  -- build at once. Without a choice, the talents decide.
  if goal then
    info.active, info.source = goal, "goal"
  elseif detected then
    info.active, info.source = detected, "talents"
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
  if info.source == "goal" then
    if info.detected and info.detected ~= info.goal then
      return string.format(L.SPEC_GOAL_TALENTS_DIFFER, SpecName(info.goal), SpecName(info.detected), info.points)
    end
    return string.format(L.SPEC_GOAL, SpecName(info.goal), info.points)
  elseif info.source == "talents" then
    return string.format(L.SPEC_FROM_TALENTS, SpecName(info.active), info.points)
  end
  local reason = info.hybrid and string.format(L.SPEC_HYBRID, info.points) or L.SPEC_NO_POINTS
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
  self:RegisterCallback("SPEC_CHANGED", "OnSpecChangedAdvice")
  self:RegisterCallback("CHARACTER_RESET", "OnCharacterReset")
end

local SPEC_SECTIONS = { all = true, level = true, talents = true }

function Talents:OnCharacterUpdated(_, snapshot, section)
  if not SPEC_SECTIONS[section] then
    return
  end
  self:UpdateSpec()
  self:UpdateAdvice(section ~= "talents")

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

---------------------------------------------------------------------------
-- Talent advisor
---------------------------------------------------------------------------

-- Number of upcoming picks shown by /pw talents and in the Next Steps detail.
local PREVIEW_PICKS = 5

-- Returns the build for the player's class and active spec/goal, its key.
function Talents:GetBuild()
  local builds = Data.TalentBuilds[GetSnapshot().class]
  if not builds then
    return nil
  end
  local key = builds.bySpec[self:GetSpecInfo().active] or builds.default
  return builds.builds[key], key
end

-- The client's talent at a pick's position (tab, tier, column), or by its
-- English name as a fallback.
local function FindTalent(trees, pick)
  local tree = trees[pick[1]]
  if not tree then
    return nil
  end
  for _, talent in ipairs(tree.talents) do
    if talent.tier == pick[2] and talent.column == pick[3] then
      return talent
    end
  end
  for _, talent in ipairs(tree.talents) do
    if talent.name == pick[5] then
      return talent
    end
  end
end

-- Pure function: the upcoming points of a build the player hasn't spent yet.
-- Returns a list of { pick, talent, rank, maxRank, name, open } (rank = the
-- rank this point brings the talent to; open = its tier is reachable), at
-- most `limit` long. Points whose tier isn't open yet are listed after the
-- open ones.
function Talents.UpcomingPoints(trees, build, limit)
  local open, closed = {}, {}
  local spentInTree = {}
  for i, tree in ipairs(trees) do
    spentInTree[i] = tree.points
  end
  for _, pick in ipairs(build.picks) do
    local talent = FindTalent(trees, pick)
    local have = talent and talent.rank or 0
    for rank = 1, pick[4] do
      if rank > have then
        local tierOpen = (spentInTree[pick[1]] or 0) >= (pick[2] - 1) * 5
        local point = {
          pick = pick,
          talent = talent,
          rank = rank,
          maxRank = talent and talent.maxRank or pick[4],
          name = talent and talent.name or pick[5],
          open = tierOpen,
        }
        table.insert(tierOpen and open or closed, point)
        if tierOpen then
          -- Planning ahead: this point opens later tiers of its tree.
          spentInTree[pick[1]] = (spentInTree[pick[1]] or 0) + 1
        end
      end
    end
  end
  local result = {}
  for _, list in ipairs({ open, closed }) do
    for _, point in ipairs(list) do
      if #result < limit then
        result[#result + 1] = point
      end
    end
  end
  return result
end

-- Talent points spent beyond what the build ever puts in that talent.
function Talents.OffBuildPoints(trees, build)
  local planned = {} -- [talent table] = ranks the build wants
  for _, pick in ipairs(build.picks) do
    local talent = FindTalent(trees, pick)
    if talent then
      planned[talent] = (planned[talent] or 0) + pick[4]
    end
  end
  local off = 0
  for _, tree in ipairs(trees) do
    for _, talent in ipairs(tree.talents) do
      off = off + math.max(0, talent.rank - (planned[talent] or 0))
    end
  end
  return off
end

-- From this many points outside the build, suggest unlearning talents.
local RESPEC_THRESHOLD = 3

local function PointText(point)
  return string.format(L.TALENT_POINT, point.name, point.rank, point.maxRank)
end

function Talents:GetUpcoming(limit)
  local build = self:GetBuild()
  if not build then
    return {}, nil
  end
  return Talents.UpcomingPoints(GetSnapshot().talents.trees, build, limit or PREVIEW_PICKS), build
end

-- The talent to put the next point into, for highlighting it in the
-- talent window: { tab, index, name, rank, maxRank }, or nil when there's no
-- unspent point, no build, or the next build point can't be taken yet.
function Talents:GetNextPoint()
  if (GetSnapshot().talents.unspent or 0) <= 0 then
    return nil
  end
  local point = self:GetUpcoming(1)[1]
  if not point or not point.open or not point.talent then
    return nil
  end
  return {
    tab = point.pick[1],
    index = point.talent.index,
    name = point.name,
    rank = point.rank,
    maxRank = point.maxRank,
  }
end

-- Updates the Next Steps item and, once per level, the chat reminder.
-- Fires TALENT_ADVICE_UPDATED (for the talent window highlight).
function Talents:UpdateAdvice(allowAnnounce)
  local NextSteps = Pathwise:GetModule("NextSteps")
  local snapshot = GetSnapshot()
  local unspent = snapshot.talents.unspent or 0
  local upcoming, build = self:GetUpcoming(PREVIEW_PICKS)
  local items = {}
  if unspent > 0 and #upcoming > 0 then
    local detail = { build.name }
    for i, point in ipairs(upcoming) do
      detail[#detail + 1] = string.format("%d. %s", i, PointText(point))
    end
    items[1] = {
      id = "talent",
      priority = NextSteps.PRIORITY.TALENT,
      text = string.format(unspent == 1 and L.TALENT_SPEND_ONE or L.TALENT_SPEND, unspent, PointText(upcoming[1])),
      detail = detail,
    }
    local charDB = Pathwise.charDB
    if allowAnnounce and charDB.talentAnnouncedLevel ~= snapshot.level and Pathwise.db.chatMessages then
      charDB.talentAnnouncedLevel = snapshot.level
      Pathwise:Printf(L.TALENT_ANNOUNCE, PointText(upcoming[1]))
    end
  end
  if build then
    local off = Talents.OffBuildPoints(snapshot.talents.trees, build)
    if off >= RESPEC_THRESHOLD then
      items[#items + 1] = {
        id = "talent-respec",
        priority = NextSteps.PRIORITY.TALENT_RESPEC,
        text = string.format(L.TALENT_RESPEC, SpecName(self:GetSpecInfo().active)),
        detail = { string.format(L.TALENT_RESPEC_DETAIL, off, build.name) },
      }
    end
  end
  NextSteps:SetItems("talents", items)
  Pathwise:FireCallback("TALENT_ADVICE_UPDATED")
end

function Talents:OnSpecChangedAdvice()
  self:UpdateAdvice(false)
end

-- /pw talents        the next points of the build
-- /pw talents check  compare the build data with the client's talent names
local function PrintCheck()
  local build = Talents:GetBuild()
  if not build then
    Pathwise:Print(L.TALENT_NO_BUILD)
    return
  end
  local trees = GetSnapshot().talents.trees
  local problems = 0
  for _, pick in ipairs(build.picks) do
    local talent = FindTalent(trees, pick)
    local atPosition = talent and talent.tier == pick[2] and talent.column == pick[3]
    if not talent or not atPosition or talent.name ~= pick[5] then
      problems = problems + 1
      Pathwise:PrintLine(string.format("  " .. L.TALENT_CHECK_MISMATCH, pick[5], pick[1], pick[2], pick[3],
        talent and talent.name or "-", talent and talent.tier or 0, talent and talent.column or 0))
    end
  end
  Pathwise:Printf(L.TALENT_CHECK_RESULT, #build.picks, problems)
end

Pathwise:RegisterCommand("talents", function(args)
  if args:lower() == "check" then
    PrintCheck()
    return
  end
  local upcoming, build = Talents:GetUpcoming(PREVIEW_PICKS)
  if not build then
    Pathwise:Print(L.TALENT_NO_BUILD)
    return
  end
  Pathwise:Printf(L.TALENT_HEADER, build.name, GetSnapshot().talents.unspent or 0)
  for i, point in ipairs(upcoming) do
    Pathwise:PrintLine(string.format("  %d. %s", i, PointText(point)))
  end
  if #upcoming == 0 then
    Pathwise:PrintLine("  " .. L.TALENT_BUILD_DONE)
  end
end, L.CMD_TALENTS)

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
