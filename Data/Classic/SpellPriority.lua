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
  WARRIOR = {
    common = {
      ["Mocking Blow"] = true,
      ["Challenging Shout"] = true,
    },
    -- Two-hander or two weapons: the shield abilities can wait.
    LEVELING = {
      ["Shield Bash"] = true,
      ["Shield Block"] = true,
      ["Shield Wall"] = true,
      ["Revenge"] = true,
      ["Disarm"] = true,
    },
    FURY = {
      ["Shield Bash"] = true,
      ["Shield Block"] = true,
      ["Shield Wall"] = true,
      ["Revenge"] = true,
      ["Disarm"] = true,
    },
    PROTECTION = {},
  },
  PALADIN = {
    common = {
      ["Turn Undead"] = true,
    },
  },
  ROGUE = {
    common = {
      ["Distract"] = true,
      ["Detect Traps"] = true,
      ["Disarm Trap"] = true,
    },
  },
  PRIEST = {
    common = {
      ["Mind Vision"] = true,
      ["Mind Soothe"] = true,
    },
    -- Shadow: Mind Blast and Shadow Word: Pain do the damage.
    LEVELING = {
      ["Smite"] = true,
      ["Holy Fire"] = true,
    },
  },
  SHAMAN = {
    common = {
      ["Far Sight"] = true,
      ["Sentry Totem"] = true,
      ["Water Breathing"] = true,
    },
  },
  MAGE = {
    common = {
      ["Slow Fall"] = true,
      ["Detect Magic"] = true,
      ["Amplify Magic"] = true,
      ["Dampen Magic"] = true,
    },
    -- Frost: Frostbolt does the damage, Fire Blast stays for finishing.
    LEVELING = {
      ["Fireball"] = true,
      ["Scorch"] = true,
      ["Flamestrike"] = true,
    },
  },
  WARLOCK = {
    common = {
      ["Eye of Kilrogg"] = true,
      ["Sense Demons"] = true,
      ["Detect Lesser Invisibility"] = true,
      ["Detect Invisibility"] = true,
      ["Detect Greater Invisibility"] = true,
      ["Unending Breath"] = true,
    },
    LEVELING = {
      ["Searing Pain"] = true,
    },
  },
  DRUID = {
    common = {
      ["Soothe Animal"] = true,
      ["Hibernate"] = true,
    },
    -- Feral: the caster spells beyond healing and roots can wait.
    LEVELING = {
      ["Hurricane"] = true,
      ["Starfire"] = true,
    },
  },
}

-- Specs that skip the same spells as their class's leveling path.
local priority = Pathwise.Data.SpellPriority
priority.WARRIOR.ARMS = priority.WARRIOR.LEVELING
priority.PRIEST.SHADOW = priority.PRIEST.LEVELING
priority.MAGE.FROST = priority.MAGE.LEVELING
priority.WARLOCK.AFFLICTION = priority.WARLOCK.LEVELING
priority.DRUID.FERAL = priority.DRUID.LEVELING
