local addonName, Pathwise = ...

-- Binds /pathwise and /pw to the command registry in Core/Init.lua.
-- SLASH_PATHWISE1/2 and SlashCmdList are globals by WoW's design: this is
-- how the client discovers slash commands.
SLASH_PATHWISE1 = "/pathwise"
SLASH_PATHWISE2 = "/pw"
SlashCmdList.PATHWISE = function(message)
  Pathwise:HandleSlashCommand(message)
end
