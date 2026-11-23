-- One real-data scenario (see tests/sim/run.sh):
--   lua5.1 tests/sim/check.lua <faction> <level> <mapID> <x> <y> <mode> [language]
-- mode: fresh (empty log) | busy (8 quests of the zone under way) | turnin
-- (the same, 3 ready to turn in) | dungeon:<id> (dungeon mode).
-- Prints "ok [...]" with what it found, and a "FAIL [...]" line per problem.
-- SIM_BUDGET_MS (default 40): a plan may take at most this long.
local H = dofile("tests/sim/harness.lua")
local faction, level, mapID, x, y, mode, lang = arg[1], tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4]),
  tonumber(arg[5]), arg[6], arg[7]
local WoW = H.WoW
local tag = string.format("[%s %d %d %s%s]", faction, level, mapID, mode, lang and (" " .. lang) or "")
local budget = tonumber(os.getenv("SIM_BUDGET_MS") or "") or 40
local fails = 0
local function Fail(message)
  fails = fails + 1
  print("FAIL " .. tag .. " " .. message)
end

if lang then
  PathwiseDB = { language = lang }
  GetLocale = function() return lang end
end
local done = H.TypicalDone(level - 4, {}, faction)
local Pathwise = H.Load({ level = level, mapID = mapID, x = x, y = y, done = done, faction = faction })
local QA = Pathwise:GetModule("QuestAdvisor")
local QD = Pathwise:GetModule("QuestieData")
local DG = Pathwise:GetModule("DungeonGuide")
local Platform = Pathwise.Platform

local log = {}
if mode == "busy" or mode == "turnin" then
  for i, id in ipairs(H.ZoneQuests(mapID, level, 8, faction, done)) do
    log[#log + 1] = H.LogEntry(id, mode == "turnin" and i <= 3)
  end
end
H.SetLog(log)

local dungeonID = mode:match("^dungeon:(.+)$")
if dungeonID then
  -- WoW Forever's own dungeons too (the harness runs the Classic client).
  local forever = { Data = {}, Platform = { flavor = "Forever" } }
  assert(loadfile("./Data/Classic/Dungeons.lua"))("Pathwise", forever)
  local have = {}
  for _, dungeon in ipairs(Pathwise.Data.Dungeons) do
    have[dungeon.id] = true
  end
  for _, dungeon in ipairs(forever.Data.Dungeons) do
    if not have[dungeon.id] then
      table.insert(Pathwise.Data.Dungeons, dungeon)
    end
  end
  QD:ResetPickups()
  QD:PickupsReady()
  for _ = 1, 400 do
    WoW.RunTimers()
  end
  DG:SetDungeon(tonumber(dungeonID) or dungeonID)
  for _ = 1, 20 do
    WoW.RunTimers()
  end
end

-- Time: the first plan builds what's kept between plans; the ones after it
-- are what playing costs (a frame is 16 ms at 60 fps).
QA:Update()
local start = os.clock()
for _ = 1, 5 do
  WoW.now = WoW.now + 1
  QA:Update()
end
local ms = (os.clock() - start) / 5 * 1000
if ms > budget then
  Fail(string.format("slow plan: %.1f ms (budget %d)", ms, budget))
end

local items = Pathwise:GetModule("NextSteps"):GetItems()
local greenRange = Platform.GetQuestGreenRange(level)
local ongoing = QA.Ongoing(Platform.GetQuestLog(), level, greenRange, function(q, k) return QD:GetTarget(q, k) end)
local busy = ongoing >= QA.BUSY_QUESTS or #log >= QA.BUSY_LOG_QUESTS
local seen, pickups = {}, 0
for _, item in ipairs(items) do
  if seen[item.id] then
    Fail("duplicate step " .. item.id)
  end
  seen[item.id] = true
  local questID = tonumber(item.id:match("^pickup:(%d+)$") or "")
  if questID then
    pickups = pickups + 1
    local text = (item.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local sort = H.Q(questID, "zoneOrSort") or 0
    local questLevel = H.Q(questID, "questLevel") or level
    if not dungeonID and DG.Get(sort) then
      Fail("dungeon quest suggested in normal mode: " .. text)
    end
    if not dungeonID and QA.Difficulty(questLevel, level, greenRange) == "GREY" then
      Fail("grey pickup: " .. text)
    end
    if not dungeonID and busy and item.priority ~= Pathwise:GetModule("NextSteps").PRIORITY.QUEST_CHAIN then
      Fail("a pickup with the log busy: " .. text)
    end
  end
  if item.id == "hearth" and dungeonID then
    Fail("hearthstone tip in dungeon mode")
  end
end
if not dungeonID and pickups > QA.MAX_PICKUPS then
  Fail("too many pickups: " .. pickups)
end
if dungeonID then
  local missing, entrance
  for i, item in ipairs(items) do
    if item.id == "dungeon:missing" then missing = i end
    if item.id == "dungeon:entrance" then entrance = i end
  end
  if not entrance then
    Fail("no step to the entrance")
  elseif missing and missing > entrance then
    Fail("missing quests after the entrance")
  end
end
for _, e in ipairs(WoW.errors) do
  Fail("error: " .. tostring(e):sub(1, 300))
end
if lang then
  for _, item in ipairs(items) do
    local text = item.text or ""
    if text:find("Pick up:") or text:find("Turn in:") or text:find("Missing ") then
      Fail("English text in " .. lang .. ": " .. text)
    end
  end
end
print(string.format("ok %s %d steps %d pickups %d under way %.1f ms%s", tag, #items, pickups, ongoing, ms,
  fails > 0 and (" FAILS " .. fails) or ""))
if os.getenv("SHOW") then
  for _, step in ipairs(H.Steps()) do
    print("", step.priority, step.id, step.text)
  end
end
os.exit(fails > 0 and 1 or 0)
