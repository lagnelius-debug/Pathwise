local addonName, Pathwise = ...

-- Which trainer spells are optional (safe to skip to save gold) for each
-- class and spec/goal. Everything not listed is recommended. Keys are the
-- English names from ClassSpells.lua (not the client's names), so this works
-- in every locale.
--
-- common:    optional for every spec/goal of the class
-- [specKey]: additionally optional for that spec/goal
--
-- These are judgment calls for leveling, to be tuned while playing.

Pathwise.Data.SpellPriority = {
  HUNTER = {
    common = {
      ["Track Undead"] = true,
      ["Track Hidden"] = true,
      ["Track Elementals"] = true,
      ["Track Demons"] = true,
      ["Track Giants"] = true,
      ["Track Dragonkin"] = true,
      ["Eagle Eye"] = true,
      ["Eyes of the Beast"] = true,
      ["Beast Lore"] = true,
      ["Scare Beast"] = true,
      ["Flare"] = true,
      ["Aspect of the Beast"] = true,
      ["Aspect of the Wild"] = true,
      ["Distracting Shot"] = true,
    },
    LEVELING = {
      ["Dual Wield"] = true,
    },
    BEAST_MASTERY = {
      ["Dual Wield"] = true,
    },
    -- Ranged only: melee attacks and melee defense can be skipped. Wing Clip
    -- stays recommended for kiting.
    MARKSMANSHIP = {
      ["Raptor Strike"] = true,
      ["Mongoose Bite"] = true,
      ["Parry"] = true,
      ["Dual Wield"] = true,
    },
    -- Survival uses its melee abilities, so nothing extra is optional.
    SURVIVAL = {},
  },
}
