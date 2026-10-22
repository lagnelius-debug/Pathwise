local addonName, Pathwise = ...

-- English strings. enUS is the base locale: a missing key returns the key
-- itself, so a forgotten translation shows up as e.g. "SLOT_HEAD" instead of
-- causing an error.
local L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})
Pathwise.L = L

-- General
L.LOADED = "v%s loaded. Type /pw help for commands."
L.MODULE_ERROR = "|cffff4040Error in module %s (%s).|r Type /console scriptErrors 1 and /reload to see it."
L.UNKNOWN_COMMAND = "Unknown command '%s'."
L.HELP_HEADER = "Commands (/pathwise or /pw):"
L.NEXT_STEPS_NOT_READY = "The Next Steps panel is not built yet (milestone M7)."

-- Built-in commands
L.CMD_HELP = "show this list"
L.CMD_DEBUG = "toggle debug output"
L.CMD_RESET = "reset settings ('/pw reset char' resets this character)"
L.DEBUG_ON = "Debug output enabled."
L.DEBUG_OFF = "Debug output disabled."
L.RESET_DONE = "Settings reset to defaults."
L.RESET_CHAR_DONE = "Character data reset. Type /reload to start fresh."

-- /pw status
L.CMD_STATUS = "print the character snapshot"
L.STATUS_HEADER = "Character status"
L.STATUS_IDENTITY = "%s-%s: level %d %s %s (%s)"
L.STATUS_XP = "XP: %s / %s (%.0f%%)"
L.STATUS_XP_RESTED = "XP: %s / %s (%.0f%%), rested %s"
L.STATUS_XP_MAX = "XP: max level"
L.STATUS_ZONE = "Zone: %s"
L.STATUS_SPEC = "Spec: %s"
L.STATUS_TALENTS = "Talents: %s - unspent %d"
L.STATUS_TALENTS_NONE = "Talents: no talent data from the client"
L.STATUS_GEAR = "Gear (%d/%d slots):"
L.STATUS_ITEM_PENDING = "item %d (not cached yet)"
L.STATUS_EMPTY_SLOTS = "Empty: %s"
L.STATUS_SKILLS_COLLAPSED = "Collapsed in the skill window (not listed): %s"
L.STATUS_CLIENT = "Client %s (interface %s), Pathwise %s"

-- Equipment slots
L.SLOT_HEAD = "Head"
L.SLOT_NECK = "Neck"
L.SLOT_SHOULDER = "Shoulder"
L.SLOT_BACK = "Back"
L.SLOT_CHEST = "Chest"
L.SLOT_SHIRT = "Shirt"
L.SLOT_TABARD = "Tabard"
L.SLOT_WRIST = "Wrist"
L.SLOT_HANDS = "Hands"
L.SLOT_WAIST = "Waist"
L.SLOT_LEGS = "Legs"
L.SLOT_FEET = "Feet"
L.SLOT_FINGER1 = "Ring 1"
L.SLOT_FINGER2 = "Ring 2"
L.SLOT_TRINKET1 = "Trinket 1"
L.SLOT_TRINKET2 = "Trinket 2"
L.SLOT_MAINHAND = "Main hand"
L.SLOT_OFFHAND = "Off hand"
L.SLOT_RANGED = "Ranged"
L.SLOT_AMMO = "Ammo"

-- Spec description (/pw status)
L.SPEC_FROM_TALENTS = "%s (from talents %s) - goal: %s"
L.SPEC_HYBRID = "hybrid talents %s"
L.SPEC_NO_POINTS = "no talent points spent"
L.SPEC_USING_GOAL = "%s, using goal: %s"
L.SPEC_USING_DEFAULT = "%s, using default: %s (choose a goal with /pw spec)"
L.GOAL_NOT_SET = "not set"

-- Goals and specs
L.SPEC_LEVELING = "Leveling"
L.SPEC_TANK = "Tank"
L.SPEC_HEALER = "Healer"
L.SPEC_DAMAGE = "Damage"
L.SPEC_BEAST_MASTERY = "Beast Mastery"
L.SPEC_MARKSMANSHIP = "Marksmanship"
L.SPEC_SURVIVAL = "Survival"
L.SPEC_ARMS = "Arms"
L.SPEC_FURY = "Fury"
L.SPEC_PROTECTION = "Protection"
L.SPEC_HOLY = "Holy"
L.SPEC_RETRIBUTION = "Retribution"
L.SPEC_ASSASSINATION = "Assassination"
L.SPEC_COMBAT = "Combat"
L.SPEC_SUBTLETY = "Subtlety"
L.SPEC_DISCIPLINE = "Discipline"
L.SPEC_SHADOW = "Shadow"
L.SPEC_ELEMENTAL = "Elemental"
L.SPEC_ENHANCEMENT = "Enhancement"
L.SPEC_RESTORATION = "Restoration"
L.SPEC_ARCANE = "Arcane"
L.SPEC_FIRE = "Fire"
L.SPEC_FROST = "Frost"
L.SPEC_AFFLICTION = "Affliction"
L.SPEC_DEMONOLOGY = "Demonology"
L.SPEC_DESTRUCTION = "Destruction"
L.SPEC_BALANCE = "Balance"
L.SPEC_FERAL = "Feral Combat"

-- Goal prompt tooltips (optional per goal)
L.SPEC_DESC_LEVELING = "Fastest way to 60. For a hunter this is the Beast Mastery leveling build."
L.SPEC_DESC_TANK = "Prioritize survivability and threat."
L.SPEC_DESC_HEALER = "Prioritize healing gear and talents."
L.SPEC_DESC_DAMAGE = "Prioritize damage gear and talents."
L.SPEC_DESC_BEAST_MASTERY = "Strong pet, great for solo play and leveling."
L.SPEC_DESC_MARKSMANSHIP = "Ranged damage focus, the classic raid build."
L.SPEC_DESC_SURVIVAL = "Agility and utility focus."

-- Goal prompt and /pw spec
L.CMD_SPEC = "choose your goal ('/pw spec mm', '/pw spec clear')"
L.GOAL_PROMPT_QUESTION = "What is your goal for this character?"
L.GOAL_PROMPT_HINT = "Used to pick stat weights and talent builds. Change it any time with /pw spec."
L.GOAL_CURRENT = "%s (current)"
L.GOAL_SET = "Goal set to %s."
L.GOAL_CLEARED = "Goal cleared. Pathwise will follow your talents."
L.GOAL_DISMISSED = "No goal chosen, using %s. Change it any time with /pw spec."
L.GOAL_UNKNOWN = "Unknown goal '%s'. Options: %s."

-- Gear advisor (tooltip line and /pw score)
L.TOOLTIP_UPGRADE_PERCENT = "+%.0f%% upgrade"
L.TOOLTIP_UPGRADE = "upgrade"
L.TOOLTIP_UPGRADE_EMPTY = "upgrade (empty slot)"
L.TOOLTIP_DOWNGRADE_PERCENT = "-%.0f%% downgrade"
L.TOOLTIP_DOWNGRADE = "downgrade"
L.TOOLTIP_SAME = "about the same"
L.TOOLTIP_UNUSABLE = "not usable by your class"
L.TOOLTIP_AT_LEVEL = "at level %d"
L.CMD_SCORE = "print scores of your equipped items"
L.SCORE_HEADER = "Gear scores (%s, %s weights):"
L.SCORE_TOTAL = "Total: %.1f"
L.SCORE_NO_WEIGHTS = "No stat weights for %s yet."
L.CMD_STATS = "show an item's raw stats (shift-click the item after typing it)"
L.STATS_USAGE = "Usage: /pw stats [item] (shift-click an item into the chat box)"
L.STATS_HEADER = "%s: %s, class %s/%s, min level %d, score %s"
