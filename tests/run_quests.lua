-- Quest log advisor and Next Steps window.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local QuestAdvisor = Pathwise:GetModule("QuestAdvisor")
local NextSteps = Pathwise:GetModule("NextSteps")
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()

local function Strip(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function QuestTexts()
  local texts = {}
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id:find("^quest:") then texts[#texts + 1] = Strip(item.text) end
  end
  return texts
end

local function UpdateLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

---------------------------------------------------------------------------
section("Quests: pure helpers")

local D = QuestAdvisor.Difficulty
check("difficulty colors", D(15, 10, 5) == "RED" and D(13, 10, 5) == "ORANGE" and D(12, 10, 5) == "YELLOW"
  and D(8, 10, 5) == "YELLOW" and D(5, 10, 5) == "GREEN" and D(4, 10, 5) == "GREY")
check("progress from counts", QuestAdvisor.Progress({ objectives = {
  { have = 6, need = 10 }, { finished = true } } }) == 7 / 11)
check("progress without objectives", QuestAdvisor.Progress({ objectives = {} }) == nil)

---------------------------------------------------------------------------
section("Quests: plan")

snapshot.level = nil
S.level = 8
WoW.FireEvent("PLAYER_LEVEL_UP", 8)
S.zone, S.subZone = "Teldrassil", "Dolanaar"
WoW.FireEvent("ZONE_CHANGED_NEW_AREA")
WoW.RunTimers()

UpdateLog({
  { header = true, title = "Teldrassil" },
  { title = "Webwood Venom", level = 7, questID = 1, objectives = { { text = "Webwood Venom Sac: 6/10" } } },
  { title = "The Balance of Nature", level = 7, questID = 2, complete = 1,
    objectives = { { text = "Nightsaber slain: 7/7", finished = true } } },
  { title = "Seek Redemption!", level = 7, questID = 3, objectives = { { text = "Fel Cone: 0/3" } } },
  { title = "Crown of the Earth", level = 12, questID = 4, objectives = { { text = "Moonwell water", finished = false } } },
  { title = "The Relics of Wakening", level = 14, questID = 5, objectives = { { text = "Relic: 0/1" } } },
  { title = "Rellian Greenspyre", level = 2, questID = 6, objectives = { { text = "Sample: 0/1" } } },
  { title = "Lost Supplies", level = 8, questID = 7, complete = -1, objectives = {} },
  { header = true, title = "Darkshore" },
  { title = "Buzzbox 827", level = 9, questID = 8, objectives = { { text = "Tide Crawler Legs: 0/6" } } },
  { title = "The Tower of Althalaxx", level = 10, questID = 9, group = 3, objectives = { { text = "Cultist slain: 0/12" } } },
})
local texts = QuestTexts()
check("1: turn in first", texts[1] == "Turn in: [7] The Balance of Nature")
check("2: failed quest", texts[2] == "Failed: [8] Lost Supplies - abandon and pick it up again")
check("3: almost done", texts[3] == "Almost done: [7] Webwood Venom (60%)")
check("4: do here", texts[4] == "Do: [7] Seek Redemption!")
check("5: orange quest here marked hard", texts[5] == "Do: [12] Crown of the Earth (hard)")
check("6: elsewhere", texts[6] == "Do: [9] Buzzbox 827 in Darkshore")
check("7/8: later (red, group)", texts[7] == "Later (level 12): [14] The Relics of Wakening"
  and texts[8] == "Group quest: [10] The Tower of Althalaxx (3 players)")
check("9: grey last", texts[9] == "Low XP: [2] Rellian Greenspyre - consider abandoning")
-- "Talk to" quests have no objectives and never report complete: turn in.
UpdateLog({
  { header = true, title = "Shadowglen" },
  { title = "Tenaron's Summons", level = 5, questID = 77, objectives = {} },
})
check("quest without objectives is a turn-in", QuestTexts()[1] == "Turn in: [5] Tenaron's Summons")
WoW.ClearChat()
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("no 'quest complete' nudge for talk-to quests", not WoW.ChatContains("Quest complete"))
UpdateLog({
  { header = true, title = "Teldrassil" },
  { title = "Webwood Venom", level = 7, questID = 1, objectives = { { text = "Webwood Venom Sac: 6/10" } } },
  { title = "The Balance of Nature", level = 7, questID = 2, complete = 1,
    objectives = { { text = "Nightsaber slain: 7/7", finished = true } } },
  { title = "Seek Redemption!", level = 7, questID = 3, objectives = { { text = "Fel Cone: 0/3" } } },
})

check("trainer step between turn-ins and quests",
  NextSteps:GetItems()[1].priority >= NextSteps:GetItems()[#NextSteps:GetItems()].priority)

---------------------------------------------------------------------------
section("Quests: live updates")

WoW.ClearChat()
WoW.questLog[2].objectives[1] = { text = "Webwood Venom Sac: 10/10", finished = true }
WoW.questLog[2].complete = 1
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("chat nudge when a quest completes", WoW.ChatContains("Quest complete: Webwood Venom - turn it in."))
local count = 0
for _, line in ipairs(WoW.chat) do if line:find("Quest complete", 1, true) then count = count + 1 end end
check("one nudge for a burst of updates", count == 1)
check("now listed as turn-in", QuestTexts()[1]:find("Turn in:", 1, true) ~= nil)

WoW.ClearChat()
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("no repeat nudge", #WoW.chat == 0)

table.remove(WoW.questLog, 3) -- turned in The Balance of Nature
WoW.FireEvent("QUEST_TURNED_IN", 2)
WoW.RunTimers()
for _, text in ipairs(QuestTexts()) do
  check("turned-in quest removed: " .. text, not text:find("Balance of Nature", 1, true))
end

-- Collapsed header
UpdateLog({ { header = true, title = "Teldrassil", collapsed = true } })
check("collapsed header hint", QuestTexts()[1] == "Expand these quest log headers to include their quests: Teldrassil")
UpdateLog({})
WoW.ClearChat()
WoW.Slash("quests")
check("/pw quests empty", WoW.ChatContains("Your quest log is empty."))

---------------------------------------------------------------------------
section("Next Steps window")

local frame = _G.PathwiseNextSteps
Pathwise:GetModule("NextStepsFrame"):SetShown(true)
UpdateLog({
  { header = true, title = "Teldrassil" },
  { title = "The Balance of Nature", level = 7, questID = 2, complete = 1, objectives = {} },
})
local turnInRow
for _, f in ipairs(WoW.frames) do
  if f.text and f._parent == frame and f._shown and f.item and Strip(f.text:GetText()):find("Turn in", 1, true) then
    turnInRow = f
  end
end
check("window shows the turn-in step", turnInRow ~= nil)
WoW.Slash("")
check("/pw hides the window and remembers", not frame:IsShown() and Pathwise.db.nextSteps.shown == false)
WoW.Slash("")
check("/pw shows it again", frame:IsShown() and Pathwise.db.nextSteps.shown == true)
