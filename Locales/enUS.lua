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
