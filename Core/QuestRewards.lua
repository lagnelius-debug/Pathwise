local addonName, Pathwise = ...

-- Quest reward picker: when a quest with reward choices is turned in,
-- recommends the biggest upgrade, or the item that sells for the most if none
-- is an upgrade. Pathwise only recommends; it never selects a reward.
--
-- Callbacks fired:
--   QUEST_REWARD_RECOMMENDED (recommendation)  see QuestRewards.Pick
--   QUEST_REWARD_CLEARED     ()                window closed / no choice

local L = Pathwise.L
local Platform = Pathwise.Platform

local QuestRewards = Pathwise:NewModule("QuestRewards")

-- Item data can arrive late; give up waiting after this many item events.
local MAX_ITEM_INFO_WAITS = 20

local questOpen = false
local waits = 0

-- Pure function. candidates: { { index, compare, sellPrice, count } } where
-- compare is a GearScore:Compare result or nil. Returns nil or
--   { index, reason = "UPGRADE" | "UPGRADE_LATER" | "SELL", compare, value }
-- Upgrades usable now beat upgrades that need a level or a weapon/armor
-- skill first, which beat the highest vendor value.
function QuestRewards.Pick(candidates)
  local best = {}
  for _, candidate in ipairs(candidates) do
    local compare = candidate.compare
    local tier, value
    if compare and compare.kind == "upgrade" then
      tier = compare.reason and "UPGRADE_LATER" or "UPGRADE"
      value = compare.newScore - (compare.oldScore or 0)
    elseif (candidate.sellPrice or 0) > 0 then
      tier = "SELL"
      value = candidate.sellPrice * (candidate.count or 1)
    end
    if tier and (not best[tier] or value > best[tier].value) then
      best[tier] = { index = candidate.index, reason = tier, compare = compare, value = value }
    end
  end
  return best.UPGRADE or best.UPGRADE_LATER or best.SELL
end

QuestRewards.FormatMoney = Pathwise.FormatMoney

local function Announce(recommendation, link)
  if not Pathwise.db.chatMessages then
    return
  end
  local compare = recommendation.compare
  if recommendation.reason == "UPGRADE" then
    if compare.percent then
      Pathwise:Printf(L.QUEST_BEST_UPGRADE_PERCENT, link, compare.percent)
    else
      Pathwise:Printf(L.QUEST_BEST_UPGRADE, link)
    end
  elseif recommendation.reason == "UPGRADE_LATER" and compare.reason == "TRAIN" then
    local skill = Platform.GetSpellDisplay(compare.skillSpell) or "?"
    Pathwise:Printf(L.QUEST_BEST_UPGRADE_TRAIN, link, skill)
  elseif recommendation.reason == "UPGRADE_LATER" then
    Pathwise:Printf(L.QUEST_BEST_UPGRADE_LATER, link, compare.level)
  else
    Pathwise:Printf(L.QUEST_BEST_SELL, link, QuestRewards.FormatMoney(recommendation.value))
  end
end

function QuestRewards:Evaluate()
  local choices = Platform.GetQuestRewardChoices()
  if #choices < 2 then
    Pathwise:FireCallback("QUEST_REWARD_CLEARED")
    return
  end

  local GearScore = Pathwise:GetModule("GearScore")
  local candidates, pending = {}, false
  for _, choice in ipairs(choices) do
    local info = choice.link and Platform.GetItemInfo(choice.link)
    if not info then
      pending = true
    else
      candidates[#candidates + 1] = {
        index = choice.index,
        link = choice.link,
        compare = GearScore:Compare(choice.link),
        sellPrice = info.sellPrice,
        count = choice.count,
      }
    end
  end

  if pending and waits < MAX_ITEM_INFO_WAITS then
    -- Re-evaluate when the client receives the missing item data.
    self:Debug("Waiting for reward item data.")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
    return
  end
  self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")

  local recommendation = QuestRewards.Pick(candidates)
  if not recommendation then
    Pathwise:FireCallback("QUEST_REWARD_CLEARED")
    return
  end
  for _, candidate in ipairs(candidates) do
    if candidate.index == recommendation.index then
      recommendation.link = candidate.link
    end
  end
  self:Debugf("Recommend choice %d (%s)", recommendation.index, recommendation.reason)
  Announce(recommendation, recommendation.link)
  Pathwise:FireCallback("QUEST_REWARD_RECOMMENDED", recommendation)
end

function QuestRewards:OnItemInfoReceived()
  if not questOpen then
    self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    return
  end
  waits = waits + 1
  self:Evaluate()
end

function QuestRewards:QUEST_COMPLETE()
  questOpen = true
  waits = 0
  self:Evaluate()
end

function QuestRewards:QUEST_FINISHED()
  questOpen = false
  self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
  Pathwise:FireCallback("QUEST_REWARD_CLEARED")
end

function QuestRewards:OnEnable()
  self:RegisterEvent("QUEST_COMPLETE")
  self:RegisterEvent("QUEST_FINISHED")
end
