local addonName, Pathwise = ...

-- Adds a "Pathwise: ..." line to item tooltips with the gear advisor's
-- verdict (upgrade / downgrade / not usable).
--
-- Hooking: newer clients route tooltips through TooltipDataProcessor and may
-- no longer fire OnTooltipSetItem; older ones only have OnTooltipSetItem.
-- Which one Classic Era 1.15.9 has is checked at runtime.

local L = Pathwise.L
local Platform = Pathwise.Platform

local Tooltip = Pathwise:NewModule("Tooltip")

-- The default WoW font has no arrow glyphs (a "▲" would show as a box), so
-- the lines use plain + and - signs.
local COLOR_UP = "|cff20ff20"
local COLOR_DOWN = "|cffff4040"
local COLOR_NEUTRAL = "|cffffd200"
local COLOR_GREY = "|cff9d9d9d"
local PREFIX = "Pathwise: "

-- Turns a GearScore:Compare result into a colored tooltip line.
function Tooltip.FormatResult(result)
  local kind = result.kind
  local text, color

  if kind == "equipped" then
    return nil
  elseif kind == "unusable" then
    return COLOR_GREY .. PREFIX .. L.TOOLTIP_UNUSABLE .. "|r"
  elseif kind == "upgrade" then
    color = COLOR_UP
    if result.empty and result.percent then
      text = string.format(L.TOOLTIP_UPGRADE_EMPTY_PERCENT, result.percent)
    elseif result.empty then
      text = L.TOOLTIP_UPGRADE_EMPTY
    elseif result.percent then
      text = string.format(L.TOOLTIP_UPGRADE_PERCENT, result.percent)
    else
      text = L.TOOLTIP_UPGRADE
    end
  elseif kind == "downgrade" then
    color = COLOR_DOWN
    if result.percent then
      text = string.format(L.TOOLTIP_DOWNGRADE_PERCENT, -result.percent)
    else
      text = L.TOOLTIP_DOWNGRADE
    end
  else
    color, text = COLOR_NEUTRAL, L.TOOLTIP_SAME
  end

  if result.reason == "LEVEL" then
    text = text .. " " .. string.format(L.TOOLTIP_AT_LEVEL, result.level)
  elseif result.reason == "TRAIN" then
    local skill = Platform.GetSpellDisplay(result.skillSpell) or "?"
    text = text .. " " .. string.format(L.TOOLTIP_NEEDS_SKILL, skill)
  end
  if Pathwise.db.debug then
    text = text .. string.format(" (%.1f vs %.1f)", result.newScore, result.oldScore or 0)
  end
  return color .. PREFIX .. text .. "|r"
end

-- OnTooltipSetItem can fire more than once for the same tooltip, so check
-- whether our line is already there. Scanning the lines works in every client,
-- unlike relying on OnTooltipCleared.
local function HasPathwiseLine(tooltip)
  local name = tooltip:GetName()
  for i = tooltip:NumLines(), 1, -1 do
    local fontString = _G[name .. "TextLeft" .. i]
    local text = fontString and fontString:GetText()
    if text and text:find(PREFIX, 1, true) then
      return true
    end
  end
  return false
end

-- Adds the Pathwise line; returns true if a line was added.
local function AddPathwiseLine(tooltip)
  if not Tooltip.enabled then
    return false
  end
  -- Only the main and chat-link tooltips; the comparison tooltips show the
  -- equipped item, where a verdict makes no sense.
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
    return false
  end
  local _, link = tooltip:GetItem()
  if not link or HasPathwiseLine(tooltip) then
    return false
  end

  local result = Pathwise:GetModule("GearScore"):Compare(link)
  local line = result and Tooltip.FormatResult(result)
  if line then
    tooltip:AddLine(line)
    return true
  end
  return false
end

-- OnTooltipSetItem runs after the tooltip was laid out, so it must be
-- re-shown to resize for the new line. TooltipDataProcessor post-calls run
-- before that, so they don't.
-- Adds all Pathwise lines (gear verdict, sell price); true if any added.
local function AddLines(tooltip)
  local added = AddPathwiseLine(tooltip)
  if Pathwise:GetModule("SellPrice").AddLine(tooltip) then
    added = true
  end
  return added
end

local function OnTooltipSetItem(tooltip)
  if AddLines(tooltip) then
    tooltip:Show()
  end
end

local function OnTooltipPostCall(tooltip)
  AddLines(tooltip)
end

function Tooltip:OnInitialize()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipPostCall)
    self.hookMethod = "TooltipDataProcessor"
  else
    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    self.hookMethod = "OnTooltipSetItem"
  end
end

function Tooltip:OnEnable()
  self:Debugf("Tooltip hook: %s", self.hookMethod)
end
