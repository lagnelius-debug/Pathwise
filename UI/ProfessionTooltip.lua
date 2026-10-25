local addonName, Pathwise = ...

-- Adds "Pathwise: Skinning 50 needed (you have 52)" to the tooltip of
-- beasts when the player has Skinning: green when the skill is enough, red
-- when not. The skill comes from Core/Professions.lua.
--
-- Hooking, as in UI/Tooltip.lua: TooltipDataProcessor when the client has
-- it, else OnTooltipSetUnit (checked at runtime).

local L = Pathwise.L
local Platform = Pathwise.Platform

local ProfessionTooltip = Pathwise:NewModule("ProfessionTooltip")

local PREFIX = "Pathwise: "
local COLOR_OK = "|cff20ff20"
local COLOR_LOW = "|cffff4040"
-- UnitCreatureType's name for beasts (English client).
local BEAST = "Beast"

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

-- The line for a unit, or nil.
function ProfessionTooltip.LineFor(unit)
  local creature = Platform.GetUnitCreature(unit)
  if not creature or creature.isPlayer or creature.creatureType ~= BEAST then
    return nil
  end
  local needed, have = Pathwise:GetModule("Professions"):GetSkinning(creature.level)
  if not needed then
    return nil
  end
  local color = have >= needed and COLOR_OK or COLOR_LOW
  return color .. PREFIX .. string.format(L.SKINNING_LINE, needed, have) .. "|r"
end

-- Returns true if a line was added.
local function AddLine(tooltip)
  if tooltip ~= GameTooltip or HasPathwiseLine(tooltip) then
    return false
  end
  local _, unit = tooltip:GetUnit()
  local line = ProfessionTooltip.LineFor(unit or "mouseover")
  if line then
    tooltip:AddLine(line)
    return true
  end
  return false
end

function ProfessionTooltip:OnInitialize()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
    and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddLine)
  else
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
      if AddLine(tooltip) then
        tooltip:Show() -- resize for the new line
      end
    end)
  end
end
