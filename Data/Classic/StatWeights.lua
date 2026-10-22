local addonName, Pathwise = ...

-- Stat weights per class -> per spec/goal key. An item's score is the sum of
-- stat * weight. Keys are the locale-independent stat keys returned by
-- GetItemStats, plus two custom keys for weapon DPS.
--
-- All values are placeholder starting points, to be tuned while testing.
-- A spec without its own table falls back to LEVELING.
-- TODO verify: crit/hit ("Equip: Improves your chance...") are not scored
-- yet; check how Classic Era's GetItemStats reports them.

Pathwise.Data.StatWeights = {
  HUNTER = {
    LEVELING = {
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.45,
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 0.25,
      ITEM_MOD_SPIRIT_SHORT = 0.1,
      ITEM_MOD_STRENGTH_SHORT = 0.05,
      RESISTANCE0_NAME = 0.04, -- armor; matters most at low level where gear has no stats
      RANGED_WEAPON_DPS = 3.0, -- custom key: ranged weapon DPS is weighted heavily
      MELEE_WEAPON_DPS = 0.2,  -- custom key: melee weapon is mostly a stat stick
    },
    -- BEAST_MASTERY, MARKSMANSHIP, SURVIVAL to follow (use LEVELING until then)
  },
}
