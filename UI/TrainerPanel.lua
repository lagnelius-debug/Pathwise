local addonName, Pathwise = ...

-- Spellbook "Training" panel: a tab on the spellbook's side opens a panel
-- docked to the right of the spellbook, listing spells available at the
-- trainer now and the ones coming in the next levels.
--
-- Pathwise doesn't take over one of Blizzard's skill line tabs (other addons
-- such as WhatsTraining do); its tab is its own button placed below the last
-- visible skill line tab, so they can't conflict.

local L = Pathwise.L
local Platform = Pathwise.Platform

local TrainerPanel = Pathwise:NewModule("TrainerPanel")

local PANEL_WIDTH = 290
local PANEL_HEIGHT = 430
local ROW_HEIGHT = 20
local MAX_SKILL_LINE_TABS = 12
local TAB_ICON = "Interface\\Icons\\INV_Misc_Book_11"

local tab, panel, scrollFrame, scrollChild
local rows = {}

local function MoneyText(copper)
  if GetCoinTextureString then
    return GetCoinTextureString(copper)
  end
  return Pathwise.FormatMoney(copper)
end

local function GetTrainer()
  return Pathwise:GetModule("Trainer")
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function OnRowEnter(row)
  if not row.spellID then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if GameTooltip.SetSpellByID then
    GameTooltip:SetSpellByID(row.spellID)
  else
    GameTooltip:SetText(row.left:GetText())
  end
  GameTooltip:Show()
end

local function OnRowLeave()
  GameTooltip:Hide()
end

local function GetRow(index)
  local row = rows[index]
  if not row then
    row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(PANEL_WIDTH - 50, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetJustifyH("LEFT")

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.right:SetJustifyH("RIGHT")
    rows[index] = row
  end
  return row
end

-- kind: "header", "item", "text" or "spacer"
local function SetRow(index, kind, text, rightText, spellID, dim)
  local row = GetRow(index)
  row.spellID = spellID
  row.left:ClearAllPoints()
  if kind == "item" then
    local _, _, icon = Platform.GetSpellDisplay(spellID)
    row.icon:SetTexture(icon)
    row.icon:Show()
    row.left:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.left:SetFontObject(dim and "GameFontDisableSmall" or "GameFontHighlightSmall")
  else
    row.icon:Hide()
    row.left:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.left:SetFontObject(kind == "header" and "GameFontNormal" or "GameFontHighlightSmall")
  end
  row.left:SetText(text or "")
  row.right:SetText(rightText or "")
  row:Show()
end

function TrainerPanel:Render()
  if not panel or not panel:IsShown() then
    return
  end
  local list = GetTrainer():GetList()
  local Trainer = GetTrainer()
  local index = 0
  local function Add(...)
    index = index + 1
    SetRow(index, ...)
  end

  local specName = list.spec and L["SPEC_" .. list.spec] or ""
  if #list.available == 0 then
    Add("header", L.PANEL_NOTHING_NOW)
  end
  if #list.recommended > 0 then
    Add("header", string.format(L.PANEL_RECOMMENDED, specName))
    for _, item in ipairs(list.recommended) do
      Add("item", Trainer.FormatName(item), MoneyText(item.cost or 0), item.id)
    end
    Add("text", L.PANEL_TOTAL, MoneyText(Trainer.TotalCost(list.recommended)))
  end
  if #list.optional > 0 then
    Add("spacer")
    Add("header", L.PANEL_OPTIONAL)
    for _, item in ipairs(list.optional) do
      Add("item", Trainer.FormatName(item), MoneyText(item.cost or 0), item.id, true)
    end
  end

  Add("spacer")
  if #list.upcoming > 0 then
    Add("header", L.PANEL_UPCOMING)
    for _, item in ipairs(list.upcoming) do
      local text = Trainer.FormatName(item)
      if item.optional then
        text = text .. " " .. L.TRAINER_OPTIONAL_TAG
      end
      Add("item", text, string.format(L.PANEL_LEVEL, item.level), item.id, true)
    end
  else
    Add("text", L.PANEL_NOTHING_SOON)
  end

  for i = index + 1, #rows do
    rows[i]:Hide()
  end
  scrollChild:SetHeight(math.max(index * ROW_HEIGHT, 1))
end

---------------------------------------------------------------------------
-- Tab and panel
---------------------------------------------------------------------------

-- Places the tab under the last visible skill line tab (Blizzard's or
-- another addon's), and the panel to the right of the tab.
local function Position()
  local last
  for i = 1, MAX_SKILL_LINE_TABS do
    local skillTab = _G["SpellBookSkillLineTab" .. i]
    if skillTab and skillTab:IsShown() then
      last = skillTab
    end
  end
  tab:ClearAllPoints()
  if last then
    tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -17)
  else
    tab:SetPoint("TOPLEFT", SpellBookFrame, "TOPRIGHT", -32, -65)
  end

  local xOffset = 0
  local tabRight, bookRight = tab:GetRight(), SpellBookFrame:GetRight()
  if tabRight and bookRight and tabRight > bookRight then
    xOffset = tabRight - bookRight + 4
  end
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", SpellBookFrame, "TOPRIGHT", xOffset, -12)
end

local function UpdateTab()
  local count = #GetTrainer():GetList().recommended
  tab.count:SetText(count > 0 and count or "")
  tab:SetChecked(panel:IsShown())
end

function TrainerPanel:SetPanelShown(shown)
  Pathwise.db.trainerPanel = shown
  panel:SetShown(shown)
  UpdateTab()
  if shown then
    self:Render()
  end
end

local function OnSpellBookShow()
  -- Skill line tabs are laid out by the spellbook's own OnShow/update code;
  -- position after it has run.
  Position()
  panel:SetShown(Pathwise.db.trainerPanel)
  UpdateTab()
  TrainerPanel:Render()
  Platform.After(0, Position)
end

local function CreateTab()
  tab = CreateFrame("CheckButton", "PathwiseSpellBookTab", SpellBookFrame)
  tab:SetSize(32, 32)

  local background = tab:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
  background:SetSize(64, 64)
  background:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)

  tab:SetNormalTexture(TAB_ICON)
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")

  tab.count = tab:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  tab.count:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)

  tab:SetScript("OnClick", function()
    TrainerPanel:SetPanelShown(not panel:IsShown())
  end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.PANEL_TITLE)
    local list = GetTrainer():GetList()
    GameTooltip:AddLine(string.format(L.PANEL_TAB_TOOLTIP, #list.recommended, #list.optional), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function CreatePanel()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  panel = CreateFrame("Frame", "PathwiseTrainingPanel", SpellBookFrame, template)
  panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
  if panel.SetBackdrop then
    panel:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end

  local shade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
  if shade.SetColorTexture then
    shade:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -12)
    shade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 11)
    shade:SetColorTexture(0, 0, 0, 0.6)
  end

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -20)
  title:SetText(L.PANEL_TITLE)

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function()
    TrainerPanel:SetPanelShown(false)
  end)

  scrollFrame = CreateFrame("ScrollFrame", "PathwiseTrainingScroll", panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -48)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 18)

  scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(PANEL_WIDTH - 54, 1)
  scrollFrame:SetScrollChild(scrollChild)

  panel:Hide()
end

function TrainerPanel:OnTrainingUpdated()
  if tab then
    UpdateTab()
    self:Render()
  end
end

function TrainerPanel:OnInitialize()
  if not SpellBookFrame then
    self:Debug("No SpellBookFrame; training panel disabled.")
    return
  end
  CreateTab()
  CreatePanel()
  SpellBookFrame:HookScript("OnShow", OnSpellBookShow)
  -- Re-place the tab when the spellbook rebuilds its skill line tabs (the
  -- function is a method in 1.15.x and a global in older clients).
  if SpellBookFrame.UpdateSkillLineTabs then
    hooksecurefunc(SpellBookFrame, "UpdateSkillLineTabs", Position)
  elseif SpellBookFrame_UpdateSkillLineTabs then
    hooksecurefunc("SpellBookFrame_UpdateSkillLineTabs", Position)
  end
  self:RegisterCallback("TRAINING_UPDATED", "OnTrainingUpdated")
end
