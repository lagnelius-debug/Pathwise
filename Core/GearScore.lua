local addonName, Pathwise = ...

-- Gear advisor: scores items with the stat weights of the player's class and
-- active spec, and compares an item with what is currently equipped.
--
-- Score = sum of (stat * weight). Weapon DPS is weighted with
-- RANGED_WEAPON_DPS or MELEE_WEAPON_DPS depending on the weapon type.

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local GearScore = Pathwise:NewModule("GearScore")

-- Differences smaller than this (in percent) count as "about the same".
local SAME_THRESHOLD_PERCENT = 1

local DPS_STAT = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"

-- Item scores by link; cleared when the active spec changes.
local scoreCache = {}

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

-- Returns the weights table for the player's class and active spec, the spec
-- key actually used, or nil if there are no weights for this class.
function GearScore:GetWeights()
  local classWeights = Data.StatWeights[GetSnapshot().class]
  if not classWeights then
    return nil
  end
  local spec = Pathwise:GetModule("Talents"):GetSpecInfo().active
  if classWeights[spec] then
    return classWeights[spec], spec
  end
  return classWeights[Data.DefaultGoal], Data.DefaultGoal
end

-- Pure function: score of a stats table with a weights table.
function GearScore.ScoreStats(stats, weights, isRanged)
  local score = 0
  for key, value in pairs(stats) do
    if key == DPS_STAT then
      local weight = isRanged and weights.RANGED_WEAPON_DPS or weights.MELEE_WEAPON_DPS
      score = score + value * (weight or 0)
    else
      score = score + value * (weights[key] or 0)
    end
  end
  return score
end

-- Returns { score, info } for an item link, or nil if the item can't be
-- scored (not cached yet, not equippable, or no weights for this class).
function GearScore:ScoreItem(link)
  if not link then
    return nil
  end
  local cached = scoreCache[link]
  if cached then
    return cached
  end
  local weights = self:GetWeights()
  if not weights then
    return nil
  end
  local info = Platform.GetItemInfo(link)
  if not info or not info.slots then
    return nil
  end
  local stats = Platform.GetItemStats(link)
  if not stats then
    return nil
  end
  local result = { score = GearScore.ScoreStats(stats, weights, info.isRanged), info = info }
  scoreCache[link] = result
  return result
end

-- Returns usable, reason, level, skillSpell. reason is "TYPE" (class can
-- never use it), "LEVEL" (usable from `level`), "TRAIN" (the weapon/armor
-- skill skillSpell isn't learned yet), or nil.
function GearScore:CheckUsable(info)
  local snapshot = GetSnapshot()
  local level = snapshot.level or 1
  local gear = Data.ClassGear[snapshot.class]

  local typeLevel = 1
  if gear then
    local allowed
    if info.classID == Platform.ITEM_CLASS_ARMOR then
      allowed = gear.armor
    elseif info.classID == Platform.ITEM_CLASS_WEAPON then
      allowed = gear.weapons
    end
    if allowed then
      typeLevel = allowed[info.subclassID]
      if not typeLevel then
        return false, "TYPE"
      end
    end
  end

  local needed = math.max(typeLevel, info.minLevel or 0)
  if needed > level then
    return false, "LEVEL", needed
  end

  -- The class can use it, but has the player learned the skill yet (e.g.
  -- Staves from a weapon master, Mail from the class trainer at 40)?
  local skills
  if info.classID == Platform.ITEM_CLASS_ARMOR then
    skills = Data.Proficiencies.armor
  elseif info.classID == Platform.ITEM_CLASS_WEAPON then
    skills = Data.Proficiencies.weapons
  end
  local skillSpell = skills and skills[info.subclassID]
  if skillSpell and not Platform.IsSpellKnown(skillSpell) then
    return false, "TRAIN", nil, skillSpell
  end
  return true
end

local function CanDualWield()
  local snapshot = GetSnapshot()
  local gear = Data.ClassGear[snapshot.class]
  if not gear then
    return true
  end
  return gear.dualWieldLevel ~= nil and (snapshot.level or 1) >= gear.dualWieldLevel
end

-- Score of what's equipped in a slot: score, isEmpty, scored item (or nil).
local function EquippedScore(slot)
  local item = GetSnapshot().equipment[slot]
  if not item then
    return 0, true
  end
  local scored = GearScore:ScoreItem(item.link)
  if not scored then
    return nil
  end
  return scored.score, false, scored
end

-- Sum of the scores of all equipped items (items that can't be scored, like
-- shirts, ammo or not-yet-cached items, count as 0).
function GearScore:GetEquippedTotal()
  local total = 0
  for _, item in pairs(GetSnapshot().equipment) do
    local scored = self:ScoreItem(item.link)
    if scored then
      total = total + scored.score
    end
  end
  return total
end

-- Compares an item with the equipped gear. Returns nil if it can't be
-- scored, otherwise a table:
--   kind     = "upgrade", "downgrade", "same", "equipped" or "unusable"
--   percent  = change to the total score of all equipped gear, in percent
--              (nil when nothing equipped scores above 0)
--   empty    = true if compared against an empty slot
--   reason, level, skillSpell = from CheckUsable, for "unusable" and for
--              upgrades that need a level or a weapon/armor skill first
--   newScore, oldScore
function GearScore:Compare(link)
  local scored = self:ScoreItem(link)
  if not scored then
    return nil
  end
  local info = scored.info
  local equipment = GetSnapshot().equipment

  for _, slot in ipairs(info.slots) do
    local item = equipment[slot]
    if item and item.link == link then
      return { kind = "equipped", newScore = scored.score }
    end
  end

  local usable, reason, level, skillSpell = self:CheckUsable(info)
  if not usable and reason == "TYPE" then
    return { kind = "unusable", reason = reason, newScore = scored.score }
  end

  -- Which equipped score to compare against.
  local oldScore, empty
  local mainHand, offHand = Platform.SLOT_MAINHAND, Platform.SLOT_OFFHAND
  if info.isTwoHand then
    -- A two-hander replaces both hands.
    local mainScore, mainEmpty = EquippedScore(mainHand)
    local offScore, offEmpty = EquippedScore(offHand)
    if not mainScore or not offScore then
      return nil
    end
    oldScore, empty = mainScore + offScore, mainEmpty and offEmpty
  else
    local slots = info.slots
    local _, _, mainItem = EquippedScore(mainHand)
    if #slots == 2 and slots[2] == offHand and (not CanDualWield() or (mainItem and mainItem.info.isTwoHand)) then
      -- One-hander without dual wield (or replacing a two-hander): main hand only.
      slots = { mainHand }
    end
    -- Rings, trinkets, dual-wield one-handers: compare with the weaker one;
    -- an empty slot is always the weakest.
    for _, slot in ipairs(slots) do
      local slotScore, slotEmpty = EquippedScore(slot)
      if not slotScore then
        return nil
      end
      if slotEmpty then
        oldScore, empty = 0, true
        break
      end
      if not oldScore or slotScore < oldScore then
        oldScore = slotScore
      end
    end
  end

  local result = { newScore = scored.score, oldScore = oldScore, empty = empty }
  if not usable then
    result.reason, result.level, result.skillSpell = reason, level, skillSpell
  end

  -- The percentage is the change to the total score of all equipped gear,
  -- not item vs item: comparing two items directly gives lopsided numbers
  -- (2 -> 17 armor is +750%, but 17 -> 2 is only -88%).
  local diff = scored.score - oldScore
  local total = self:GetEquippedTotal()
  if total > 0 then
    result.percent = diff / total * 100
  end
  if empty then
    result.kind = "upgrade"
  elseif result.percent and math.abs(result.percent) < SAME_THRESHOLD_PERCENT then
    result.kind = "same"
  elseif diff > 0 then
    result.kind = "upgrade"
  elseif diff < 0 then
    result.kind = "downgrade"
  else
    result.kind = "same"
  end
  return result
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function GearScore:ClearCache()
  scoreCache = {}
end

function GearScore:OnInitialize()
  self:RegisterCallback("SPEC_CHANGED", "ClearCache")
end

---------------------------------------------------------------------------
-- /pw score
---------------------------------------------------------------------------

function GearScore:PrintScores()
  local weights, spec = self:GetWeights()
  local snapshot = GetSnapshot()
  if not weights then
    Pathwise:Printf(L.SCORE_NO_WEIGHTS, snapshot.classLocalized or "?")
    return
  end
  Pathwise:Printf(L.SCORE_HEADER, snapshot.classLocalized or "?", L["SPEC_" .. spec])
  local total = 0
  for _, slot in ipairs(Platform.GetEquipmentSlots()) do
    local item = snapshot.equipment[slot.id]
    if item then
      local scored = self:ScoreItem(item.link)
      if scored then
        total = total + scored.score
        Pathwise:PrintLine(string.format("  %s: %s %.1f", L["SLOT_" .. slot.key], item.link, scored.score))
      end
    end
  end
  Pathwise:PrintLine(string.format("  " .. L.SCORE_TOTAL, total))
end

Pathwise:RegisterCommand("score", function()
  GearScore:PrintScores()
end, L.CMD_SCORE)

-- /pw stats <item link>: raw stats as the client reports them, for checking
-- stat keys and tuning weights. Shift-click an item into the chat box.
Pathwise:RegisterCommand("stats", function(args)
  local info = args ~= "" and Platform.GetItemInfo(args)
  if not info then
    Pathwise:Print(L.STATS_USAGE)
    return
  end
  local scored = GearScore:ScoreItem(info.link)
  Pathwise:Printf(L.STATS_HEADER, info.link, tostring(info.equipLoc), tostring(info.classID),
    tostring(info.subclassID), info.minLevel, scored and string.format("%.2f", scored.score) or "-")
  local stats = Platform.GetItemStats(info.link) or {}
  local keys = {}
  for key in pairs(stats) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    Pathwise:PrintLine(string.format("  %s = %s", key, tostring(stats[key])))
  end
end, L.CMD_STATS)
