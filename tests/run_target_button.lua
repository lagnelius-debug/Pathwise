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

-- An object (a moonwell, a herb) stays put: it keeps its distance.
local Waypoints = Pathwise:GetModule("Waypoints")
Waypoints:SetManual({ mapID = 1438, x = 0.58, y = 0.30, label = "Filled Tourmaline Phial (Pools of Arlithrien Moonwell)",
  spawn = true })
Arrow:Update()
check("object spot: distance shown, in meters", arrow.distance:GetText() == "274 m")
WoW.ClearChat()
WoW.Slash("units yards")
Arrow:Update()
check("/pw units yards", arrow.distance:GetText() == "300 yd" and WoW.ChatContains("shown in yards"))
WoW.Slash("units meters")
Arrow:Update()
check("/pw units meters", arrow.distance:GetText() == "274 m")
-- Settings: General > Distances: Meters / Yards
local unitButtons = {}
for _, f in ipairs(WoW.frames) do
  if f.unit and f._parent == _G.PathwiseSettingsPanel then unitButtons[f.unit] = f end
end
local gold = Pathwise.HexToRGB("#ffd100")
check("settings: Meters and Yards buttons", unitButtons.meters and unitButtons.yards
  and unitButtons.meters.name:GetText() == "Meters" and unitButtons.yards.name:GetText() == "Yards")
unitButtons.yards:Click()
Arrow:Update()
local function QuestLine()
  for _, item in ipairs(Pathwise:GetModule("NextSteps"):GetItems()) do
    if item.id == "quest:916" then return item.text end
  end
  return ""
end
check("clicking Yards: arrow and To-do lines in yards", Pathwise.db.distanceUnit == "yards"
  and arrow.distance:GetText() == "300 yd" and QuestLine():find("%d+ yd") ~= nil)
check("Yards outlined", math.abs(unitButtons.yards._borderColor[1] - gold) < 1e-6
  and math.abs(unitButtons.meters._borderColor[1] - gold) > 1e-6)
WoW.Slash("units meters")
Arrow:Update()
check("/pw units meters: outline follows", math.abs(unitButtons.meters._borderColor[1] - gold) < 1e-6
  and arrow.distance:GetText() == "274 m" and QuestLine():find("%d+ m") ~= nil)

WoW.ClearChat()
WoW.Slash("units feet")
check("unknown unit: usage", WoW.ChatContains("Usage: /pw units meters|yards"))
Waypoints:ClearManual()

---------------------------------------------------------------------------
section("Target button: turn-in and combat")

UpdateLog(Venom(true))
check("turn-in step: no button", not button:IsShown())
Arrow:Update()
check("turn-in NPC keeps the distance", arrow.distance:GetText():find("%d+ m$") ~= nil)

S.inCombat = true
UpdateLog(Venom(false))
check("in combat: unchanged (secure frame)", not button:IsShown())
S.inCombat = false
WoW.FireEvent("PLAYER_REGEN_ENABLED")
check("after combat: shown", button:IsShown() and button:GetAttribute("macrotext"):find("Webwood Spider", 1, true) ~= nil)

---------------------------------------------------------------------------
section("Target button: several kinds of mobs, in turn")

local TargetMacro = Pathwise:GetModule("TargetMacro")
local function MacroBody()
  local index = GetMacroIndexByName("Pathwise")
  return index > 0 and WoW.macros[index].body or ""
end
-- The last /targetexact line wins: the mob the next press goes for.
local function GoesFor(body)
  local last
  for name in body:gmatch("/targetexact ([^\n]+)") do last = name end
  return last
end
Pathwise.db.targetMacro = true
WoW.macros = {} -- (the macro tests left the slots full)
Waypoints:SetManual({ mapID = 1438, x = 0.6, y = 0.4, label = "Small Crag Boar +2 quests", spawn = true,
  names = { "Small Crag Boar", "Rockjaw Trogg", "Frostmane Troll Whelp" } })
check("first: the list's own order", GoesFor(button:GetAttribute("macrotext")) == "Small Crag Boar"
  and GoesFor(MacroBody()) == "Small Crag Boar" and button.label:GetText() == "Target: Small Crag Boar +2")
-- One press of the macro changes the target once per /targetexact line
-- that finds something: only where it ends up counts, after the press.
S.targetName = "Frostmane Troll Whelp"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
S.targetName = "Small Crag Boar"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
check("not changed while the macro runs", GoesFor(MacroBody()) == "Small Crag Boar")
WoW.RunTimers()
check("a boar targeted: the next press goes for a trogg (" .. tostring(GoesFor(MacroBody())) .. ")",
  GoesFor(button:GetAttribute("macrotext")) == "Rockjaw Trogg" and GoesFor(MacroBody()) == "Rockjaw Trogg"
  and button.label:GetText() == "Target: Rockjaw Trogg +2")
check("the others stay as fallbacks", select(2, MacroBody():gsub("/targetexact", "")) == 3)
S.targetName = "Rockjaw Trogg"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
check("a trogg: then a whelp", GoesFor(MacroBody()) == "Frostmane Troll Whelp")
S.targetName = "Frostmane Troll Whelp"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
check("a whelp: back to the boars", GoesFor(MacroBody()) == "Small Crag Boar")
S.targetName = "Some Other Mob"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
S.targetName = nil
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
check("another mob, or no target: unchanged", GoesFor(MacroBody()) == "Small Crag Boar")
S.targetName = "Small Crag Boar"
S.inCombat = true
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
check("in combat: the macro and button wait", GoesFor(MacroBody()) == "Small Crag Boar"
  and GoesFor(button:GetAttribute("macrotext")) == "Small Crag Boar")
S.inCombat = false
WoW.FireEvent("PLAYER_REGEN_ENABLED")
check("after the fight: trogg next", GoesFor(MacroBody()) == "Rockjaw Trogg"
  and GoesFor(button:GetAttribute("macrotext")) == "Rockjaw Trogg")
Waypoints:SetManual({ mapID = 1438, x = 0.6, y = 0.4, label = "Webwood Spider", spawn = true,
  names = { "Webwood Spider", "Githyiss the Vile" } })
check("another step: its own order", GoesFor(MacroBody()) == "Webwood Spider")
S.targetName = nil
Waypoints:ClearManual()
UpdateLog(Venom(false))

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

---------------------------------------------------------------------------
section("Arrow: the targeted mob's nearest spawn")

-- (Addons can't see where a mob is: the arrow goes to its nearest spawn.)
local NextSteps = Pathwise:GetModule("NextSteps")
local function Near(a, b) return a ~= nil and math.abs(a - b) < 1e-6 end
Pathwise.db.arrowAuto = true
S.mapID, S.mapX, S.mapY = 1438, 0.5, 0.5
S.targetName, S.targetDead = nil, nil
local function SpawnAt(x, y, name)
  return { mapID = 1438, x = x, y = y, spawn = true, npcName = name, label = name }
end
local troggNear, troggFar = SpawnAt(0.52, 0.5, "Rockjaw Trogg"), SpawnAt(0.5, 0.7, "Rockjaw Trogg")
local whelp = SpawnAt(0.5, 0.45, "Frostmane Troll Whelp")
local function Step(id)
  return { id = id or "focus:1", priority = 99, text = "Do together",
    target = { mapID = 1438, x = 0.5, y = 0.49, label = "Small Crag Boar +2 quests", spawn = true,
      names = { "Small Crag Boar", "Rockjaw Trogg", "Frostmane Troll Whelp" },
      spawnPoints = { SpawnAt(0.5, 0.49, "Small Crag Boar"), troggFar, troggNear, whelp } } }
end
NextSteps:SetItems("focustest", { Step() })
local function Points() local t = Waypoints:GetTarget() return t and t.x, t and t.y, t and t.label end
local x, y = Points()
check("first: the step's own nearest spawn", Near(x, 0.5) and Near(y, 0.49))

local changes = 0
local counter = { Count = function() changes = changes + 1 end }
Pathwise:RegisterCallback("WAYPOINT_CHANGED", counter, "Count")
S.targetName = "Rockjaw Trogg"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
local label
x, y, label = Points()
check("a trogg targeted: the arrow goes to the nearest trogg spawn", Near(x, 0.52) and Near(y, 0.5)
  and label == "Rockjaw Trogg" and changes > 0)
check("the macro keeps the step's mobs", table.concat(Waypoints:GetTarget().names, ",")
  == "Small Crag Boar,Rockjaw Trogg,Frostmane Troll Whelp")

NextSteps:SetItems("focustest", { Step() }) -- the plan made again (moving, progress)
x, y = Points()
check("stays on the trogg when the plan is made again", Near(x, 0.52))

Waypoints:Next()
WoW.RunTimers()
x, y = Points()
check("Next: the next trogg spawn", Near(x, 0.5) and Near(y, 0.7))

S.targetName, S.targetDead = "Frostmane Troll Whelp", true
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
x, y = Points()
check("a dead mob (looting): unchanged", Near(y, 0.7))
S.targetName, S.targetDead = "Somebody Else", nil
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
x, y = Points()
check("a mob of no quest: unchanged", Near(y, 0.7))
S.targetName = "Frostmane Troll Whelp"
WoW.FireEvent("PLAYER_TARGET_CHANGED")
WoW.RunTimers()
x, y = Points()
check("a whelp: its spawn", Near(x, 0.5) and Near(y, 0.45))

NextSteps:SetItems("focustest", { Step("focus:2") })
x, y = Points()
check("another step: back to its own nearest spawn", Near(x, 0.5) and Near(y, 0.49))

S.targetName = nil
WoW.now = WoW.now + 1000
NextSteps:SetItems("focustest", {})
Pathwise:UnregisterCallback("WAYPOINT_CHANGED", counter)
