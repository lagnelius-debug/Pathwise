-- M3: quest reward picker.
local WoW, Pathwise, check, section = ...

local QuestRewards = Pathwise:GetModule("QuestRewards")

local function TurnIn(...)
  WoW.questChoices = { ... }
  WoW.SetupRewardButtons(#WoW.questChoices)
  WoW.ClearChat()
  WoW.FireEvent("QUEST_COMPLETE")
  WoW.RunTimers() -- the highlight is applied a frame later
end

-- The highlight frame is the child frame with a label.
local function Highlight()
  for _, frame in ipairs(WoW.frames) do
    if frame.label and frame._parent and frame._parent.type == "choice" then
      return frame
    end
  end
  for _, frame in ipairs(WoW.frames) do
    if frame.label then return frame end
  end
end

---------------------------------------------------------------------------
section("M3: pure helpers")

check("Pick: nothing", QuestRewards.Pick({}) == nil)
check("Pick: no value at all", QuestRewards.Pick({ { index = 1, sellPrice = 0 } }) == nil)
local pick = QuestRewards.Pick({
  { index = 1, sellPrice = 500 },
  { index = 2, compare = { kind = "upgrade", newScore = 3, oldScore = 1 } },
  { index = 3, compare = { kind = "upgrade", newScore = 5, oldScore = 2 } },
})
check("Pick: biggest upgrade wins over sell value", pick.index == 3 and pick.reason == "UPGRADE")
pick = QuestRewards.Pick({
  { index = 1, compare = { kind = "upgrade", reason = "LEVEL", level = 30, newScore = 9, oldScore = 1 } },
  { index = 2, compare = { kind = "upgrade", newScore = 2, oldScore = 1 } },
})
check("Pick: usable-now upgrade beats later upgrade", pick.index == 2)
-- Reported in game: Defender Axe (small upgrade, needs Axes) was picked
-- over Thornroot Club, which sells for 5s 12c.
pick = QuestRewards.Pick({
  { index = 1, sellPrice = 100, compare = { kind = "upgrade", reason = "TRAIN", percent = 4, newScore = 2, oldScore = 1 } },
  { index = 2, sellPrice = 512, compare = { kind = "unusable", reason = "TYPE" } },
})
check("Pick: small upgrade that needs training loses to the best sell value", pick.index == 2
  and pick.reason == "SELL" and pick.passedOver.index == 1)
pick = QuestRewards.Pick({
  { index = 1, sellPrice = 100, compare = { kind = "upgrade", reason = "TRAIN", percent = 25, newScore = 9, oldScore = 1 } },
  { index = 2, sellPrice = 512 },
})
check("Pick: big upgrade that needs training still wins", pick.index == 1 and pick.reason == "UPGRADE_LATER")
pick = QuestRewards.Pick({
  { index = 1, sellPrice = 0, compare = { kind = "upgrade", reason = "LEVEL", level = 8, percent = 3, newScore = 2, oldScore = 1 } },
  { index = 2, sellPrice = 0 },
})
check("Pick: nothing sells: the small later upgrade is still recommended", pick.index == 1
  and pick.reason == "UPGRADE_LATER" and pick.passedOver == nil)
pick = QuestRewards.Pick({
  { index = 1, sellPrice = 30, count = 5, compare = { kind = "downgrade", newScore = 1, oldScore = 2 } },
  { index = 2, sellPrice = 100 },
})
check("Pick: sell value counts stack size", pick.index == 1 and pick.reason == "SELL" and pick.value == 150)
pick = QuestRewards.Pick({
  { index = 1, sellPrice = 25, count = 5 },
  { index = 2, sellPrice = 25, count = 5 },
  { index = 3, sellPrice = 100 },
})
check("Pick: the same sell value: both", pick.reason == "SELL" and pick.index == 1
  and pick.ties and table.concat(pick.ties, ",") == "1,2")
pick = QuestRewards.Pick({
  { index = 1, sellPrice = 50 },
  { index = 2, sellPrice = 50 },
  { index = 3, compare = { kind = "upgrade", newScore = 3, oldScore = 1 } },
})
check("Pick: an upgrade wins, no ties", pick.index == 3 and pick.ties == nil)
check("Pick: one best: no ties", QuestRewards.Pick({ { index = 1, sellPrice = 5 }, { index = 2, sellPrice = 6 } }).ties == nil)
check("FormatMoney", QuestRewards.FormatMoney(12345) == "1g 23s 45c" and QuestRewards.FormatMoney(120) == "1s 20c"
  and QuestRewards.FormatMoney(0) == "0c" and QuestRewards.FormatMoney(10000) == "1g")

---------------------------------------------------------------------------
section("M3: turn-ins")

-- Agile Boots (+2.16 over the equipped boots), Plate Helm (unusable),
-- Ring of Stamina (+1.0 over the spirit ring).
TurnIn(9001, 9004, 9008)
check("announces the best upgrade", WoW.ChatContains("Best reward: [Agile Boots] (+"))
local highlight = Highlight()
check("highlight on choice 1", highlight and highlight:IsShown() and highlight._parent == QuestInfoRewardsFrame.RewardButtons[1])
check("label says best upgrade", highlight.label:GetText() == "Best upgrade")

WoW.FireEvent("QUEST_FINISHED")
check("highlight hidden when the window closes", not highlight:IsShown())

-- Your screenshot: Maul (maces: never), Dagger (usable), Staff and Blade
-- (usable after learning the weapon skill). A usable-now upgrade wins.
TurnIn(9014, 9015, 9013, 9016)
check("usable dagger beats untrained staff", WoW.ChatContains("Best reward: [Thistlewood Dagger]")
  and highlight._parent == QuestInfoRewardsFrame.RewardButtons[2] and highlight.label:GetText() == "Best upgrade")
WoW.FireEvent("QUEST_FINISHED")
-- Only a small untrained upgrade: the reward that sells for more wins, and
-- chat says why the upgrade was passed over.
TurnIn(9014, 9013)
check("small untrained upgrade: best to sell instead", WoW.ChatContains("Best reward: [Thistlewood Maul] sells for the most")
  and WoW.ChatContains("[Thistlewood Staff] would only be a small upgrade") and highlight.label:GetText() == "Best to sell")
WoW.FireEvent("QUEST_FINISHED")

TurnIn(9004, 9005)
check("no upgrade: best to sell", WoW.ChatContains("No upgrade among the rewards. [Heavy Mace] sells for the most (1s 20c)."))
check("sell highlight on choice 2", highlight:IsShown() and highlight._parent == QuestInfoRewardsFrame.RewardButtons[2]
  and highlight.label:GetText() == "Best to sell")
WoW.FireEvent("QUEST_FINISHED")

-- Your screenshot: Tough Jerky and Refreshing Spring Water, same value.
TurnIn(9017, 9018)
local shown = {}
for _, frame in ipairs(WoW.frames) do
  if frame.label and frame._shown and frame._parent and frame._parent.type == "choice" then
    shown[#shown + 1] = frame
  end
end
check("same value: both highlighted", #shown == 2 and shown[1]._parent ~= shown[2]._parent
  and shown[1].label:GetText() == "Same value" and shown[2].label:GetText() == "Same value")
check("chat: either one", WoW.ChatContains("[Tough Jerky] and [Refreshing Spring Water] sell for the same (6c)"))
WoW.FireEvent("QUEST_FINISHED")
check("both hidden when the window closes", not shown[1]:IsShown() and not shown[2]:IsShown())
TurnIn(9004, 9005)
local count = 0
for _, frame in ipairs(WoW.frames) do
  if frame.label and frame._shown and frame._parent and frame._parent.type == "choice" then count = count + 1 end
end
check("next time one best: one highlight", count == 1)
WoW.FireEvent("QUEST_FINISHED")

TurnIn(9004, 9003)
check("an upgrade only at level 40 doesn't count: best to sell instead",
  WoW.ChatContains("No upgrade among the rewards. [Plate Helm] sells for the most")
  and not WoW.ChatContains("Chain Vest"))
WoW.FireEvent("QUEST_FINISHED")

TurnIn(9001)
check("single reward: nothing to choose", #WoW.chat == 0 and not highlight:IsShown())
WoW.FireEvent("QUEST_FINISHED")

-- Item data arriving late
WoW.uncachedItems[9001] = true
TurnIn(9001, 9008)
check("waits for missing item data", #WoW.chat == 0)
WoW.uncachedItems[9001] = nil
WoW.FireEvent("GET_ITEM_INFO_RECEIVED", 9001, true)
WoW.RunTimers()
check("evaluates once data arrives", WoW.ChatContains("Best reward: [Agile Boots]"))
WoW.FireEvent("QUEST_FINISHED")
WoW.ClearChat()
WoW.FireEvent("GET_ITEM_INFO_RECEIVED", 9001, true)
check("stops listening after the window closes", #WoW.chat == 0)

-- Unknown reward frame layout: no error, chat line still shown
WoW.questChoices = { 9001, 9008 }
QuestInfoRewardsFrame = nil
WoW.ClearChat()
WoW.FireEvent("QUEST_COMPLETE")
WoW.RunTimers()
check("works without reward buttons", WoW.ChatContains("Best reward: [Agile Boots]"))
WoW.FireEvent("QUEST_FINISHED")

-- Chat messages can be turned off
Pathwise.db.chatMessages = false
TurnIn(9001, 9008)
check("no chat line when chat messages are off", #WoW.chat == 0 and highlight:IsShown())
Pathwise.db.chatMessages = true
WoW.FireEvent("QUEST_FINISHED")
