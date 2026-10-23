-- Floating target button for quest mobs, and no distance on spawn spots.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local button = _G.PathwiseTargetButton
local arrow = _G.PathwiseArrow
local Arrow = Pathwise:GetModule("Arrow")

local function UpdateLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
end

-- (Quest level = player level: earlier tests levelled up, a level 4 quest
-- would be grey and never get the arrow.)
local function Venom(done)
  return { { header = true, title = "Shadowglen" },
    { title = "Webwood Venom", level = S.level, questID = 916, complete = done and 1 or nil,
      objectives = { { text = "Webwood Venom Sac: " .. (done and "10" or "0") .. "/10", finished = done } } } }
end

---------------------------------------------------------------------------
section("Target button")

check("secure action button running a macro", button ~= nil and button._template == "SecureActionButtonTemplate"
  and button:GetAttribute("type") == "macro")
check("hidden without a quest mob", not button:IsShown())

Pathwise.db.questLocations = {}
S.mapID, S.mapX, S.mapY, S.facing = 1438, 0.58, 0.40, 0
WoW.now = WoW.now + 1000 -- forget visited spots from earlier tests
UpdateLog(Venom(false))
local t = Pathwise:GetModule("Waypoints"):GetTarget(); check("shown for a kill/loot step", button:IsShown())
check("targets the mob like the macro", button:GetAttribute("macrotext")
  == Pathwise:GetModule("TargetMacro").BuildBody({ "Webwood Spider" }))
check("label names the mob", button.label:GetText() == "Target: Webwood Spider")

---------------------------------------------------------------------------
section("Arrow: no distance on spawn spots")

Arrow:Update()
check("spawn spot: no yard count", arrow.distance:GetText() == "" and arrow.arrow:IsShown())
local spot = Pathwise:GetModule("Waypoints"):GetTarget()
S.mapX, S.mapY = spot.x, spot.y
Arrow:Update()
check("at a spawn spot: look around", arrow.distance:GetText() == "Look around here")
S.mapX, S.mapY = 0.58, 0.40

---------------------------------------------------------------------------
section("Target button: turn-in and combat")

UpdateLog(Venom(true))
check("turn-in step: no button", not button:IsShown())
Arrow:Update()
check("turn-in NPC keeps the distance", arrow.distance:GetText():find("yd", 1, true) ~= nil)

S.inCombat = true
UpdateLog(Venom(false))
check("in combat: unchanged (secure frame)", not button:IsShown())
S.inCombat = false
WoW.FireEvent("PLAYER_REGEN_ENABLED")
check("after combat: shown", button:IsShown() and button:GetAttribute("macrotext"):find("Webwood Spider", 1, true) ~= nil)

---------------------------------------------------------------------------
section("Target button: on/off")

WoW.ClearChat()
WoW.Slash("targetbutton")
check("/pw targetbutton hides it", not button:IsShown() and Pathwise.db.targetButton.shown == false
  and WoW.ChatContains("Target button off"))
local checkbox = _G.PathwiseSettingsTargetButton
check("settings checkbox follows", checkbox:GetChecked() == false)
checkbox:SetChecked(true)
checkbox._scripts.OnClick(checkbox)
check("settings checkbox shows it", button:IsShown() and Pathwise.db.targetButton.shown == true)

button._scripts.OnDragStart(button)
button._points = { { "CENTER", UIParent, "CENTER", 10, 20 } }
button._scripts.OnDragStop(button)
check("position saved", Pathwise.db.targetButton.point == "CENTER" and Pathwise.db.targetButton.x == 10)

UpdateLog({})
check("no quests: hidden", not button:IsShown())
