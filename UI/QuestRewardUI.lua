local addonName, Pathwise = ...

-- Highlights the recommended quest reward: a green border around the reward
-- button and a small label ("Best upgrade" / "Best to sell") in its corner.
--
-- The reward buttons' names differ between client versions, so they are
-- looked up at runtime: QuestInfoRewardsFrame.RewardButtons (QuestInfo
-- system), then QuestInfoRewardsFrameQuestInfoItemN, then the original
-- vanilla QuestRewardItemN.

local L = Pathwise.L
local Platform = Pathwise.Platform

local QuestRewardUI = Pathwise:NewModule("QuestRewardUI")

local highlight

local function FindChoiceButton(index)
  local container = QuestInfoRewardsFrame
  if container and container.RewardButtons then
    for _, button in ipairs(container.RewardButtons) do
      if button.type == "choice" and button:GetID() == index and button:IsShown() then
        return button
      end
    end
  end
  -- Choice items come first, so choice N is button N.
  for _, prefix in ipairs({ "QuestInfoRewardsFrameQuestInfoItem", "QuestRewardItem" }) do
    local button = _G[prefix .. index]
    if button and button:IsShown() and (button.type == nil or button.type == "choice") then
      return button
    end
  end
end

local function CreateHighlight()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  highlight = CreateFrame("Frame", nil, UIParent, template)
  if highlight.SetBackdrop then
    highlight:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 14,
    })
    highlight:SetBackdropBorderColor(0.2, 1, 0.2, 1)
  end

  local shade = highlight:CreateTexture(nil, "BACKGROUND")
  if shade.SetColorTexture then
    shade:SetPoint("TOPLEFT", highlight, "TOPLEFT", 3, -3)
    shade:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", -3, 3)
    shade:SetColorTexture(0.2, 1, 0.2, 0.12)
  end

  local label = highlight:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOPRIGHT", highlight, "TOPRIGHT", -5, -3)
  label:SetTextColor(0.3, 1, 0.3)
  highlight.label = label

  highlight:Hide()
end

local function Clear()
  if highlight then
    highlight:Hide()
    highlight:SetParent(UIParent)
  end
end

function QuestRewardUI:Apply(recommendation)
  local button = FindChoiceButton(recommendation.index)
  if not button then
    self:Debugf("Reward button %d not found; no highlight.", recommendation.index)
    Clear()
    return
  end
  if not highlight then
    CreateHighlight()
  end
  -- Parented to the button so it hides and moves with the quest frame.
  highlight:SetParent(button)
  highlight:SetFrameLevel(button:GetFrameLevel() + 5)
  highlight:ClearAllPoints()
  highlight:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
  highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
  highlight.label:SetText(recommendation.reason == "SELL" and L.QUEST_LABEL_SELL or L.QUEST_LABEL_UPGRADE)
  highlight:Show()
end

function QuestRewardUI:OnRecommended(_, recommendation)
  -- The quest frame fills in its reward buttons in its own QUEST_COMPLETE
  -- handler; wait a frame so the buttons exist and are laid out.
  Platform.After(0, function()
    QuestRewardUI:Apply(recommendation)
  end)
end

function QuestRewardUI:OnCleared()
  Clear()
end

function QuestRewardUI:OnInitialize()
  self:RegisterCallback("QUEST_REWARD_RECOMMENDED", "OnRecommended")
  self:RegisterCallback("QUEST_REWARD_CLEARED", "OnCleared")
end
