local addonName, Pathwise = ...

-- Talent trees and selectable goals per class (Classic Era).
--
-- trees: spec key for each talent tab, in tab order as returned by
--        GetTalentTabInfo(1..3). Keys are locale-independent; display names
--        live in the locale file as SPEC_<KEY>.
-- goals: options offered by the goal prompt (/pw spec). Classes without their
--        own list use GenericGoals.

Pathwise.Data.GenericGoals = { "LEVELING", "TANK", "HEALER", "DAMAGE" }

-- Used when no goal is chosen and the spec can't be inferred from talents.
Pathwise.Data.DefaultGoal = "LEVELING"

-- Shorthands accepted by /pw spec <goal>.
Pathwise.Data.GoalAliases = {
  BM = "BEAST_MASTERY",
  MM = "MARKSMANSHIP",
  SV = "SURVIVAL",
  LVL = "LEVELING",
  DPS = "DAMAGE",
}

-- Two trees whose point totals are this close (and both non-zero) count as a
-- hybrid; Pathwise then uses the player's chosen goal instead.
Pathwise.Data.HybridMargin = 3

Pathwise.Data.ClassSpecs = {
  HUNTER = {
    trees = { "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" }, -- TODO verify tab order
    goals = { "LEVELING", "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" },
  },
  WARRIOR = {
    trees = { "ARMS", "FURY", "PROTECTION" }, -- TODO verify tab order
  },
  PALADIN = {
    trees = { "HOLY", "PROTECTION", "RETRIBUTION" }, -- TODO verify tab order
  },
  ROGUE = {
    trees = { "ASSASSINATION", "COMBAT", "SUBTLETY" }, -- TODO verify tab order
  },
  PRIEST = {
    trees = { "DISCIPLINE", "HOLY", "SHADOW" }, -- TODO verify tab order
  },
  SHAMAN = {
    trees = { "ELEMENTAL", "ENHANCEMENT", "RESTORATION" }, -- TODO verify tab order
  },
  MAGE = {
    trees = { "ARCANE", "FIRE", "FROST" }, -- TODO verify tab order
  },
  WARLOCK = {
    trees = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" }, -- TODO verify tab order
  },
  DRUID = {
    trees = { "BALANCE", "FERAL", "RESTORATION" }, -- TODO verify tab order
  },
}
