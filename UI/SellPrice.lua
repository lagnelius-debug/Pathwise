local addonName, Pathwise = ...

-- Vendor sell price line in item tooltips ("Sell price: 1s 25c"). For a
-- stack in the bags it shows the stack's total and the price per item.
-- Skipped at a merchant, where the client shows its own price.
-- Called from UI/Tooltip.lua's tooltip hook.

local L = Pathwise.L
local Platform = Pathwise.Platform

local SellPrice = Pathwise:NewModule("SellPrice")

local function MoneyText(copper)
  if GetCoinTextureString then
    return GetCoinTextureString(copper)
  end
  return Pathwise.FormatMoney(copper)
end

local function HasSellLine(tooltip)
  local name = tooltip:GetName()
  for i = tooltip:NumLines(), 1, -1 do
    local fontString = _G[name .. "TextLeft" .. i]
    local text = fontString and fontString:GetText()
    if text and text:find(L.SELL_PRICE_PREFIX, 1, true) then
      return true
    end
  end
  return false
end

-- Bag and bank item buttons keep their stack size in .count (set by the
-- default UI's SetItemButtonCount).
local function StackCount(tooltip)
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  local count = owner and owner.count
  if type(count) == "number" and count > 1 then
    return count
  end
  return 1
end

-- Adds the line; returns true if one was added.
function SellPrice.AddLine(tooltip)
  if not SellPrice.enabled or not Pathwise.db.sellPrice then
    return false
  end
  if MerchantFrame and MerchantFrame:IsShown() then
    return false
  end
  -- Another source (e.g. the client at a merchant) already shows money.
  if tooltip.shownMoneyFrames and tooltip.shownMoneyFrames > 0 then
    return false
  end
  local _, link = tooltip:GetItem()
  if not link or HasSellLine(tooltip) then
    return false
  end
  local info = Platform.GetItemInfo(link)
  if not info or (info.sellPrice or 0) <= 0 then
    return false
  end
  local count = StackCount(tooltip)
  local text
  if count > 1 then
    text = string.format(L.SELL_PRICE_STACK, MoneyText(info.sellPrice * count), count, MoneyText(info.sellPrice))
  else
    text = string.format(L.SELL_PRICE, MoneyText(info.sellPrice))
  end
  tooltip:AddLine(text, 1, 1, 1)
  return true
end
