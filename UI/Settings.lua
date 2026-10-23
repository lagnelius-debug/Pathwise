local addonName, Pathwise = ...

-- Settings panel (Esc > Options > AddOns > Pathwise, or /pw settings).
-- For now: General (minimap button) and Appearance (one button per window
-- theme with a two-color swatch; the active theme has a gold outline). More
-- settings (module toggles, ammo thresholds, chat messages) come with M7.
--
-- Registration: the modern Settings API when the client has it, otherwise
-- the legacy Interface Options (checked at runtime).

local L = Pathwise.L

local SettingsPanel = Pathwise:NewModule("SettingsPanel")

local BUTTON_WIDTH = 220
local BUTTON_HEIGHT = 30
local COLUMN_GAP = 16
local ROW_GAP = 8
local ACTIVE_OUTLINE = "#ffd100"
local INACTIVE_OUTLINE = "#3a3a3a"

local panel
local themeButtons = {}

local function RGB(hex, alpha)
  return Pathwise.HexToRGB(hex, alpha)
end

local function UpdateOutlines()
  local active = Pathwise.Theme.GetActiveId()
  for _, button in ipairs(themeButtons) do
    if button.SetBackdropBorderColor then
      button:SetBackdropBorderColor(RGB(button.themeId == active and ACTIVE_OUTLINE or INACTIVE_OUTLINE))
    end
    button.name:SetTextColor(RGB(button.themeId == active and ACTIVE_OUTLINE or "#ffffff"))
  end
end

local function CreateThemeButton(index, themeId)
  local theme = Pathwise.Themes[themeId]
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local button = CreateFrame("Button", nil, panel, template)
  button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
  button:SetPoint("TOPLEFT", panel.themeHeader, "BOTTOMLEFT",
    column * (BUTTON_WIDTH + COLUMN_GAP), -28 - row * (BUTTON_HEIGHT + ROW_GAP))
  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 2,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
  end
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
  button.name:SetText(string.format("%d  %s", index, theme.name))

  button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
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

  -- Appearance
  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  header:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 4, -16)
  header:SetText(L.SETTINGS_APPEARANCE)
  panel.themeHeader = header

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  help:SetText(L.SETTINGS_APPEARANCE_HELP)

  for index, themeId in ipairs(Pathwise.ThemeOrder) do
    CreateThemeButton(index, themeId)
  end
  panel:SetScript("OnShow", function()
    UpdateOutlines()
    panel.minimapCheck:SetChecked(not Pathwise.db.minimap.hide)
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

function SettingsPanel:OnInitialize()
  CreatePanel()
  self:RegisterCallback("THEME_CHANGED", "OnThemeChanged")
  self:RegisterCallback("MINIMAP_BUTTON_CHANGED", "OnMinimapButtonChanged")
  UpdateOutlines()
end

Pathwise:RegisterCommand("settings", function()
  SettingsPanel:Open()
end, L.CMD_SETTINGS)
