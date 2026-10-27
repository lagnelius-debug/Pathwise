local addonName, Pathwise = ...

-- Settings panel (Esc > Options > AddOns > Pathwise, or /pw settings).
-- General (minimap and target buttons, meters or yards; feature switches
-- are on their own page, UI/FeaturesPanel.lua) and Appearance (one button per window
-- theme with a two-color swatch; the active theme has a gold outline, and
-- the Wildwood season choice while Wildwood is active).
--
-- Registration: the modern Settings API when the client has it, otherwise
-- the legacy Interface Options (checked at runtime).

local L = Pathwise.L

local SettingsPanel = Pathwise:NewModule("SettingsPanel")

-- Theme buttons in a grid, filled row by row: 13 themes = 5 rows of 3, so
-- the panel fits without scrolling (width 3 x 180 + 2 x 12 = 564 px).
local COLUMNS = 3
local BUTTON_WIDTH = 180
local BUTTON_HEIGHT = 26
local COLUMN_GAP = 12
local ROW_GAP = 6
local ACTIVE_OUTLINE = "#ffd100"
local INACTIVE_OUTLINE = "#3a3a3a"

local SEASON_BUTTON_WIDTH = 90
local SEASON_BUTTON_HEIGHT = 24

local UNITS = { "meters", "yards" }

local panel
local themeButtons = {}
local seasonButtons = {}
local unitButtons = {}

local function RGB(hex, alpha)
  return Pathwise.HexToRGB(hex, alpha)
end

local function Outline(button, active)
  if button.SetBackdropBorderColor then
    button:SetBackdropBorderColor(RGB(active and ACTIVE_OUTLINE or INACTIVE_OUTLINE))
  end
  button.name:SetTextColor(RGB(active and ACTIVE_OUTLINE or "#ffffff"))
end

local function UpdateOutlines()
  local active = Pathwise.Theme.GetActiveId()
  for _, button in ipairs(themeButtons) do
    Outline(button, button.themeId == active)
  end
  -- The season choice only matters (and is only shown) for Wildwood.
  local season = Pathwise.Theme.GetSeasonSetting()
  local seasonal = Pathwise.Themes[active].seasonal
  panel.seasonHeader:SetShown(seasonal and true or false)
  for _, button in ipairs(seasonButtons) do
    Outline(button, button.season == season)
    button:SetShown(seasonal and true or false)
  end
  local unit = Pathwise.db.distanceUnit == "yards" and "yards" or "meters"
  for _, button in ipairs(unitButtons) do
    Outline(button, button.unit == unit)
  end
end

-- A dark button with a 2 px outline (theme and season choices).
local function CreateChoiceButton(width, height)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local button = CreateFrame("Button", nil, panel, template)
  button:SetSize(width, height)
  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 2,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
  end
  button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  return button
end

local function CreateThemeButton(index, themeId)
  local theme = Pathwise.Themes[themeId]
  local button = CreateChoiceButton(BUTTON_WIDTH, BUTTON_HEIGHT)
  local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
  button:SetPoint("TOPLEFT", panel.themeHeader, "BOTTOMLEFT",
    column * (BUTTON_WIDTH + COLUMN_GAP), -28 - row * (BUTTON_HEIGHT + ROW_GAP))
  button.themeId = themeId

  -- Two-color swatch: frame (or background when there is no frame) + ornament.
  local swatchA = button:CreateTexture(nil, "ARTWORK")
  swatchA:SetSize(14, 14)
  swatchA:SetPoint("LEFT", button, "LEFT", 8, 0)
  swatchA:SetColorTexture(RGB(theme.frame or theme.bg))
  local swatchB = button:CreateTexture(nil, "ARTWORK")
  swatchB:SetSize(14, 14)
  swatchB:SetPoint("LEFT", swatchA, "RIGHT", 2, 0)
  swatchB:SetColorTexture(RGB(theme.ornament))

  button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  button.name:SetPoint("LEFT", swatchB, "RIGHT", 8, 0)
  -- (A long name ends in "..." instead of running out of the button.)
  button.name:SetPoint("RIGHT", button, "RIGHT", -6, 0)
  button.name:SetJustifyH("LEFT")
  if button.name.SetWordWrap then
    button.name:SetWordWrap(false)
  end
  button.name:SetText(string.format("%d  %s", index, theme.name))

  button:SetScript("OnClick", function(self)
    Pathwise.Theme.SetActive(self.themeId)
  end)
  themeButtons[index] = button
end

local function CreatePanel()
  panel = CreateFrame("Frame", "PathwiseSettingsPanel")
  panel.name = "Pathwise"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  title:SetText(L.SETTINGS_TITLE)

  -- General
  local general = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  general:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
  general:SetText(L.SETTINGS_GENERAL)

  local minimap = CreateFrame("CheckButton", "PathwiseSettingsMinimap", panel, "UICheckButtonTemplate")
  minimap:SetPoint("TOPLEFT", general, "BOTTOMLEFT", -4, -4)
  minimap.label = minimap:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  minimap.label:SetPoint("LEFT", minimap, "RIGHT", 2, 1)
  minimap.label:SetText(L.SETTINGS_MINIMAP)
  minimap:SetScript("OnClick", function(self)
    Pathwise:GetModule("MinimapButton"):SetShown(self:GetChecked() and true or false)
  end)
  panel.minimapCheck = minimap

  local targetButton = CreateFrame("CheckButton", "PathwiseSettingsTargetButton", panel, "UICheckButtonTemplate")
  targetButton:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, 2)
  targetButton.label = targetButton:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  targetButton.label:SetPoint("LEFT", targetButton, "RIGHT", 2, 1)
  targetButton.label:SetText(L.SETTINGS_TARGET_BUTTON)
  targetButton:SetScript("OnClick", function(self)
    Pathwise:GetModule("TargetButton"):SetShown(self:GetChecked() and true or false)
  end)
  panel.targetButtonCheck = targetButton

  -- Distances: Meters / Yards
  local units = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  units:SetPoint("TOPLEFT", targetButton, "BOTTOMLEFT", 4, -10)
  units:SetText(L.SETTINGS_UNITS)
  for index, unit in ipairs(UNITS) do
    local button = CreateChoiceButton(SEASON_BUTTON_WIDTH, SEASON_BUTTON_HEIGHT)
    button:SetPoint("LEFT", units, "RIGHT", 10 + (index - 1) * (SEASON_BUTTON_WIDTH + ROW_GAP), 0)
    button.unit = unit
    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.name:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.name:SetText(L["SETTINGS_UNITS_" .. unit:upper()])
    button:SetScript("OnClick", function(self)
      Pathwise:GetModule("QuestAdvisor"):SetDistanceUnit(self.unit)
    end)
    unitButtons[index] = button
  end

  local featuresHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  featuresHint:SetPoint("TOPLEFT", units, "BOTTOMLEFT", 0, -16)
  featuresHint:SetText(L.SETTINGS_FEATURES_HINT)

  -- Appearance
  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  header:SetPoint("TOPLEFT", featuresHint, "BOTTOMLEFT", 0, -16)
  header:SetText(L.SETTINGS_APPEARANCE)
  panel.themeHeader = header

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  help:SetText(L.SETTINGS_APPEARANCE_HELP)

  for index, themeId in ipairs(Pathwise.ThemeOrder) do
    CreateThemeButton(index, themeId)
  end

  -- Wildwood season: Summer / Autumn / Auto, under the theme buttons.
  local seasonHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  local rows = math.ceil(#Pathwise.ThemeOrder / COLUMNS)
  seasonHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -28 - rows * (BUTTON_HEIGHT + ROW_GAP) - 8)
  seasonHeader:SetText(L.SETTINGS_SEASON)
  panel.seasonHeader = seasonHeader
  for index, season in ipairs(Pathwise.WildwoodSeasons) do
    local button = CreateChoiceButton(SEASON_BUTTON_WIDTH, SEASON_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", seasonHeader, "BOTTOMLEFT", (index - 1) * (SEASON_BUTTON_WIDTH + ROW_GAP), -6)
    button.season = season
    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.name:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.name:SetText(L["SEASON_" .. season:upper()])
    button:SetScript("OnClick", function(self)
      Pathwise.Theme.SetSeason(self.season)
    end)
    seasonButtons[index] = button
  end
  panel:SetScript("OnShow", function()
    UpdateOutlines()
    panel.minimapCheck:SetChecked(not Pathwise.db.minimap.hide)
    panel.targetButtonCheck:SetChecked(Pathwise.db.targetButton.shown)
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    SettingsPanel.category = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function SettingsPanel:Open()
  if Settings and Settings.OpenToCategory and self.category then
    Settings.OpenToCategory(self.category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    -- Called twice: the legacy panel often opens on the wrong page the
    -- first time an addon category is requested.
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

function SettingsPanel:OnThemeChanged()
  UpdateOutlines()
end

function SettingsPanel:OnMinimapButtonChanged(_, shown)
  panel.minimapCheck:SetChecked(shown)
end

function SettingsPanel:OnTargetButtonChanged(_, shown)
  panel.targetButtonCheck:SetChecked(shown)
end

function SettingsPanel:OnInitialize()
  CreatePanel()
  self:RegisterCallback("THEME_CHANGED", "OnThemeChanged")
  self:RegisterCallback("THEME_SEASON_CHANGED", "OnThemeChanged")
  self:RegisterCallback("MINIMAP_BUTTON_CHANGED", "OnMinimapButtonChanged")
  self:RegisterCallback("TARGET_BUTTON_CHANGED", "OnTargetButtonChanged")
  self:RegisterCallback("DISTANCE_UNIT_CHANGED", "OnThemeChanged") -- refreshes all outlines
  UpdateOutlines()
end

Pathwise:RegisterCommand("settings", function()
  SettingsPanel:Open()
end, L.CMD_SETTINGS)
