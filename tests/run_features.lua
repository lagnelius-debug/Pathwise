-- Settings > Pathwise > Features: switches that apply at once.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Features = Pathwise:GetModule("FeaturesPanel")
local NextSteps = Pathwise:GetModule("NextSteps")

local function Has(prefix)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id:sub(1, #prefix) == prefix then return true end
  end
  return false
end
local function Index(label)
  for i, feature in ipairs(Features.FEATURES) do
    if feature[1] == label then return i end
  end
end
local function Switch(label, on)
  Features:SetFeature(Index(label), on)
  WoW.RunTimers()
end

---------------------------------------------------------------------------
section("Features: the page")

local panel = _G.PathwiseSettingsFeatures
check("a Features page under Pathwise", panel ~= nil and panel.parent == "Pathwise")
local boxes = 0
for i = 1, #Features.FEATURES do
  if _G["PathwiseFeature" .. i] then boxes = boxes + 1 end
end
check("one checkbox per feature, all on by default", boxes == #Features.FEATURES and boxes >= 14
  and Pathwise.db.questGuide and Pathwise.db.talentAdvice and Pathwise.db.hunterTips)

---------------------------------------------------------------------------
section("Features: switches apply at once")

-- Something to show: a quest, an unspent talent point, no ammo (hunter)
WoW.questLog = { { header = true, title = "Teldrassil" },
  { title = "Some Quest", level = S.level, questID = 8001, objectives = { { text = "Thing: 0/5" } } } }
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
check("quest step there", Has("quest:"))
Switch("FEATURE_QUESTS", false)
check("quest guide off: no quest steps", not Has("quest:"))
Switch("FEATURE_QUESTS", true)
check("quest guide on: back", Has("quest:"))

local hadTalent = Has("talent")
Switch("FEATURE_TALENTS", false)
check("talent advice off: no talent line, no glow target", not Has("talent")
  and Pathwise:GetModule("Talents"):GetNextPoint() == nil)
Switch("FEATURE_TALENTS", true)
check("talent advice on: as before", Has("talent") == hadTalent)

local hadHunter = Has("ammo") or Has("pet") or Has("taming")
Switch("FEATURE_HUNTER", false)
check("hunter reminders off", not (Has("ammo") or Has("pet") or Has("taming")))
Switch("FEATURE_HUNTER", true)
check("hunter reminders on: as before", (Has("ammo") or Has("pet") or Has("taming")) == hadHunter)

local hadTrainer = Has("trainer")
Switch("FEATURE_TRAINER", false)
check("trainer reminder off", not Has("trainer"))
Switch("FEATURE_TRAINER", true)
check("trainer reminder on: as before", Has("trainer") == hadTrainer)

Switch("FEATURE_GEAR", false)
check("gear tooltip line off", WoW.HoverItem(9001) == nil)
Switch("FEATURE_GEAR", true)
check("gear tooltip line on", WoW.HoverItem(9001) ~= nil)

Switch("FEATURE_PROFESSIONS", false)
check("professions off (this character)", Pathwise.charDB.professionsOff == true and not Has("prof:"))
Switch("FEATURE_PROFESSIONS", true)
check("professions on", Pathwise.charDB.professionsOff == false)

-- The checkbox follows, and clicking it switches
local box = _G["PathwiseFeature" .. Index("FEATURE_CHAT")]
box:SetChecked(false)
box._scripts.OnClick(box)
check("clicking a checkbox switches the feature", Pathwise.db.chatMessages == false)
box:SetChecked(true)
box._scripts.OnClick(box)
check("and back", Pathwise.db.chatMessages == true)

WoW.questLog = {}
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
