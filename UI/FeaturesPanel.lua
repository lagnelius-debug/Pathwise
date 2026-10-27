local addonName, Pathwise = ...

-- Settings > Pathwise > Features: one switch per feature, applied at once
-- (no /reload). Each switch is a saved flag the feature checks itself;
-- refresh() redraws what it shows. /pw features opens the page.

local L = Pathwise.L

local FeaturesPanel = Pathwise:NewModule("FeaturesPanel")

local ROW_HEIGHT = 26

local panel
local checks = {}

local function Module(name)
  return Pathwise:GetModule(name)
end

-- { label, get(), set(on), refresh() }
local FEATURES = {
  { "FEATURE_QUESTS", function() return Pathwise.db.questGuide end,
    function(on) Pathwise.db.questGuide = on end, function() Module("QuestAdvisor"):Update() end },
  { "FEATURE_PICKUPS", function() return Pathwise.db.questPickups end,
    function(on) Pathwise.db.questPickups = on end, function() Module("QuestAdvisor"):Update() end },
  { "FEATURE_HEARTH", function() return Pathwise.db.hearthTips end,
    function(on) Pathwise.db.hearthTips = on end, function() Module("Hearthstone"):Update() end },
  { "FEATURE_TRAINER", function() return Pathwise.db.trainerTips end,
    function(on) Pathwise.db.trainerTips = on end, function() Module("Trainer"):Refresh(false) end },
  { "FEATURE_TRAINER_PANEL", function() return Pathwise.db.trainerPanel end,
    function(on) Module("TrainerPanel"):SetPanelShown(on) end },
  { "FEATURE_TALENTS", function() return Pathwise.db.talentAdvice end,
    function(on) Pathwise.db.talentAdvice = on end, function() Module("Talents"):UpdateAdvice(false) end },
  { "FEATURE_GEAR", function() return Pathwise.db.gearTooltips end,
    function(on) Pathwise.db.gearTooltips = on end },
  { "FEATURE_REWARDS", function() return Pathwise.db.rewardPicker end,
    function(on) Pathwise.db.rewardPicker = on end },
  { "FEATURE_SELL", function() return Pathwise.db.sellPrice end,
    function(on) Pathwise.db.sellPrice = on end },
  { "FEATURE_PROFESSIONS", function() return not Pathwise.charDB.professionsOff end,
    function(on) Pathwise.charDB.professionsOff = not on end, function() Module("Professions"):Update() end },
  { "FEATURE_MACRO", function() return Pathwise.db.targetMacro end,
    function(on) Pathwise.db.targetMacro = on end, function() Module("TargetMacro"):Update() end },
  { "FEATURE_HUNTER", function() return Pathwise.db.hunterTips end,
    function(on) Pathwise.db.hunterTips = on end, function() Module("Hunter"):Update() end },
  { "FEATURE_PET", function() return Pathwise.db.petGuide end,
    function(on) Pathwise.db.petGuide = on end, function()
      local guide = Module("PetGuide")
      if guide then
        guide:Update()
      end
    end },
  { "FEATURE_CHAT", function() return Pathwise.db.chatMessages end,
    function(on) Pathwise.db.chatMessages = on end },
}
FeaturesPanel.FEATURES = FEATURES

local function Refresh()
  for i, check in ipairs(checks) do
    check:SetChecked(FEATURES[i][2]() and true or false)
  end
end

-- Turns feature `index` on or off and redraws what it shows.
function FeaturesPanel:SetFeature(index, on)
  local feature = FEATURES[index]
  feature[3](on and true or false)
  if feature[4] then
    feature[4]()
  end
  Refresh()
end

local function CreatePanel()
  panel = CreateFrame("Frame", "PathwiseSettingsFeatures")
  panel.name = L.FEATURES_TITLE
  panel.parent = "Pathwise"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  title:SetText(L.FEATURES_TITLE)
  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  help:SetText(L.FEATURES_HELP)

  for index, feature in ipairs(FEATURES) do
    local check = CreateFrame("CheckButton", "PathwiseFeature" .. index, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -4, -10 - (index - 1) * ROW_HEIGHT)
    check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    check.label:SetText(L[feature[1]])
    check.featureIndex = index
    check:SetScript("OnClick", function(self)
      FeaturesPanel:SetFeature(self.featureIndex, self:GetChecked())
    end)
    checks[index] = check
  end
  panel:SetScript("OnShow", Refresh)

  -- A page under Pathwise in the settings.
  local parent = Pathwise:GetModule("SettingsPanel").category
  if Settings and Settings.RegisterCanvasLayoutSubcategory and parent then
    FeaturesPanel.category = Settings.RegisterCanvasLayoutSubcategory(parent, panel, panel.name)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function FeaturesPanel:Open()
  if Settings and Settings.OpenToCategory and self.category and self.category.GetID then
    Settings.OpenToCategory(self.category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  else
    Pathwise:GetModule("SettingsPanel"):Open()
  end
end

function FeaturesPanel:OnInitialize()
  CreatePanel()
  self:RegisterCallback("SETTINGS_RESET", Refresh)
  self:RegisterCallback("CHARACTER_RESET", Refresh)
end

Pathwise:RegisterCommand("features", function()
  FeaturesPanel:Open()
end, L.CMD_FEATURES)
