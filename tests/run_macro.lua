-- Target macro and sell price line.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local TargetMacro = Pathwise:GetModule("TargetMacro")
local Waypoints = Pathwise:GetModule("Waypoints")

local function Macro()
  local index = GetMacroIndexByName("Pathwise")
  return index > 0 and WoW.macros[index] or nil
end

---------------------------------------------------------------------------
section("Macro: body")

local body = TargetMacro.BuildBody({ "Webwood Spider", "Githyiss the Vile" })
check("body: clear, least important first, most important last, skull mark",
  body == "/cleartarget\n/targetexact Githyiss the Vile\n/targetexact Webwood Spider\n"
    .. '/run if UnitCanAttack("player","target") and not UnitIsDead("target") then SetRaidTarget("target",8) end')
check("body without names: harmless message", TargetMacro.BuildBody({}):find("^/run print") ~= nil)
local many = {}
for i = 1, 20 do many[i] = "A very long mob name number " .. i end
body = TargetMacro.BuildBody(many)
check("body fits the 255 character limit", #body <= 255)
check("most important name kept when space runs out", body:find("number 1\n", 1, true) ~= nil
  and not body:find("number 20", 1, true))

---------------------------------------------------------------------------
section("Macro: follows the arrow")

S.mapID, S.mapX, S.mapY, S.facing = 1438, 0.58, 0.40, 0
S.zone, S.subZone = "Teldrassil", "Aldrassil"
WoW.questLog = {
  { header = true, title = "Shadowglen" },
  { title = "Webwood Venom", level = 4, questID = 916, objectives = { { text = "Webwood Venom Sac: 0/10" } } },
}
WoW.now = WoW.now + 1000 -- forget visited spots from earlier tests
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
local macro = Macro()
check("macro created per character", macro and macro.perCharacter == true)
check("macro targets the quest mob", macro and macro.body:find("/targetexact Webwood Spider", 1, true) ~= nil)

-- Complete: turn-in NPC
WoW.questLog[2].complete = 1
WoW.questLog[2].objectives[1] = { text = "Webwood Venom Sac: 10/10", finished = true }
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("macro switches to the turn-in NPC", Macro().body:find("/targetexact Gilshalan Windwalker", 1, true) ~= nil
  and not Macro().body:find("Webwood Spider", 1, true))
check("only one Pathwise macro", select(2, GetNumMacros()) == 1)

-- Combat: wait until it ends
S.inCombat = true
WoW.questLog[2].complete = nil
WoW.questLog[2].objectives[1] = { text = "Webwood Venom Sac: 9/10" }
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("not edited in combat", Macro().body:find("Gilshalan", 1, true) ~= nil)
S.inCombat = false
WoW.FireEvent("PLAYER_REGEN_ENABLED")
check("edited when combat ends", Macro().body:find("Webwood Spider", 1, true) ~= nil)

-- /pw macro puts it on the cursor
WoW.ClearChat()
WoW.Slash("macro")
check("/pw macro picks it up", WoW.cursor == Macro() and WoW.ChatContains("Drop the Pathwise macro"))
WoW.Slash("macro off")
WoW.questLog[2].complete = 1
WoW.questLog[2].objectives[1] = { text = "Webwood Venom Sac: 10/10", finished = true }
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("/pw macro off stops updates", Macro().body:find("Webwood Spider", 1, true) ~= nil)
WoW.Slash("macro on")
check("/pw macro on resumes", Macro().body:find("Gilshalan", 1, true) ~= nil)

-- Learned turn-in: the quest giver's name is remembered when accepting
Pathwise.db.questLocations = {}
S.npcName = "Conservator Ilthalaine"
WoW.FireEvent("QUEST_ACCEPTED", 1, 4500)
S.npcName = nil
check("quest giver name recorded", Pathwise.db.questLocations[4500].pickup.npcName == "Conservator Ilthalaine")

-- Full macro slots: one warning
WoW.macros = {}
for i = 1, 18 do WoW.macros[i] = { name = "M" .. i, perCharacter = true, body = "" } end
WoW.ClearChat()
WoW.Slash("macro")
check("full macro slots: warning", WoW.ChatContains("character macros are full"))

WoW.questLog = {}
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()

---------------------------------------------------------------------------
section("Sell price")

local function SellLine(itemID, owner)
  WoW.HoverItem(itemID, GameTooltip, owner)
  for _, line in ipairs(WoW.TooltipLines(GameTooltip)) do
    if line:find("Sell price", 1, true) then return line end
  end
end

check("single item", SellLine(9005) == "Sell price: 1s 20c")
check("stack in bags: total and per item", SellLine(9005, { count = 5 }) == "Sell price: 6s (5 x 1s 20c)")
check("no line for unsellable items", SellLine(9012) == nil)
MerchantFrame._shown = true
check("skipped at a merchant", SellLine(9005) == nil)
MerchantFrame._shown = false
GameTooltip.shownMoneyFrames = 1
check("skipped when money is already shown", SellLine(9005) == nil)
GameTooltip.shownMoneyFrames = nil
Pathwise.db.sellPrice = false
check("can be turned off", SellLine(9005) == nil)
Pathwise.db.sellPrice = true
WoW.HoverItem(9005)
GameTooltip._scripts.OnTooltipSetItem(GameTooltip)
local count = 0
for _, line in ipairs(WoW.TooltipLines(GameTooltip)) do
  if line:find("Sell price", 1, true) then count = count + 1 end
end
check("no duplicate sell line", count == 1)
