-- Reported cases, with real data (tests/sim/run.sh). Each runs in a process
-- of its own:  lua5.1 tests/sim/regressions.lua [case]  (no case: all).

local CASES = { "desolace_questline", "stv_questline", "westfall_chain", "sm_wings" }

local case = arg[1]
if not case then
  local failed = 0
  for _, name in ipairs(CASES) do
    local pipe = io.popen("lua5.1 tests/sim/regressions.lua " .. name .. " 2>&1")
    local output = pipe:read("*a")
    pipe:close()
    io.write(output)
    if not output:find("^ok ") then
      failed = failed + 1
    end
  end
  os.exit(failed > 0 and 1 or 0)
end

local H = dofile("tests/sim/harness.lua")
local results = {}
local function Check(description, condition)
  results[#results + 1] = { description, condition }
end
local function Position(id)
  for i, step in ipairs(H.Steps()) do
    if step.id == id then return i end
  end
end
local function Item(id)
  local i = Position(id)
  return i and H.Steps()[i].item or nil
end
local function Without(done, ids)
  for _, id in ipairs(ids) do done[id] = nil end
  return done
end

if case == "desolace_questline" then
  -- In Desolace with its quests under way (two of them follow-ups, so on a
  -- questline too): the questline in Hillsbrad (Hints of a New Plague?)
  -- waits (0.54.2).
  local done = Without(H.TypicalDone(30, {}, "Alliance"), { 658, 1387, 1382, 1385, 261 })
  done[657] = true
  local Pathwise = H.Load({ level = 36, mapID = 1443, x = 0.34, y = 0.273, done = done })
  Pathwise.charDB.questline = { [658] = true, [1382] = true, [1385] = true }
  H.SetLog({ H.LogEntry(1387, true), H.LogEntry(1382, true), H.LogEntry(1385), H.LogEntry(261), H.LogEntry(658) })
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local hints = Item("quest:658")
  Check("the questline elsewhere waits", hints and hints.priority ~= P.QUEST_CHAIN)
  Check("Desolace's quests first", Position("quest:1387") and Position("quest:658")
    and Position("quest:1387") < Position("quest:658"))
elseif case == "stv_questline" then
  -- Stranglethorn: a questline turn-in in Booty Bay (Water Elementals, 2 km)
  -- doesn't come before quests a few hundred metres away (0.54.3).
  local done = Without(H.TypicalDone(30, {}, "Alliance"), { 575, 189, 605, 213, 601, 627, 205 })
  local Pathwise = H.Load({ level = 37, mapID = 1434, x = 0.21, y = 0.217, done = done })
  Pathwise.charDB.questline = { [601] = true }
  H.SetLog({ H.LogEntry(575, true), H.LogEntry(189, true), H.LogEntry(601, true), H.LogEntry(605), H.LogEntry(213),
    H.LogEntry(627), H.LogEntry(205) })
  Check("the near work before the questline turn-in 2 km away", Position("quest:605") and Position("quest:601")
    and Position("quest:605") < Position("quest:601"))
elseif case == "westfall_chain" then
  -- Turned in The People's Militia: part 2 is the next step (0.54.0).
  local done = Without(H.TypicalDone(9, {}, "Alliance"), { 12, 13, 14 })
  local Pathwise = H.Load({ level = 14, mapID = 1436, x = 0.56, y = 0.47, done = done })
  local log = {}
  for _, id in ipairs(H.ZoneQuests(1436, 14, 3, "Alliance", done)) do
    if id ~= 12 and id ~= 13 and id ~= 14 then log[#log + 1] = H.LogEntry(id) end
  end
  H.SetLog(log)
  done[12] = true
  H.WoW.FireEvent("QUEST_TURNED_IN", 12)
  H.SetLog(log)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local nextStep = Item("pickup:13")
  Check("part 2 to pick up, as the questline", nextStep and nextStep.priority == P.QUEST_CHAIN)
elseif case == "sm_wings" then
  -- Scarlet Monastery: Down the Scarlet Path (the Cathedral's chain) only
  -- for the Cathedral (0.53.0).
  local done = H.TypicalDone(30, {}, "Alliance")
  done[261], done[1052], done[1053], done[1050] = nil, nil, nil, nil
  local Pathwise = H.Load({ level = 37, mapID = 1453, x = 0.6, y = 0.6, done = done })
  H.SetLog({})
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  DungeonGuide:SetDungeon("SMLibrary")
  for _ = 1, 20 do H.WoW.RunTimers() end
  Check("the Library: not Down the Scarlet Path", Item("pickup:261") == nil)
  DungeonGuide:SetDungeon("SMCathedral")
  for _ = 1, 20 do H.WoW.RunTimers() end
  Check("the Cathedral: Down the Scarlet Path", Item("pickup:261") ~= nil)
else
  print("FAIL unknown case " .. tostring(case))
  os.exit(1)
end

local failed = {}
for _, result in ipairs(results) do
  if not result[2] then failed[#failed + 1] = result[1] end
end
for _, e in ipairs(H.WoW.errors) do
  failed[#failed + 1] = "error: " .. tostring(e):sub(1, 200)
end
if #failed > 0 then
  for _, description in ipairs(failed) do
    print("FAIL [" .. case .. "] " .. description)
  end
  os.exit(1)
end
print("ok [" .. case .. "] " .. #results .. " checks")
