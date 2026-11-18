-- Update reminder (Core/UpdateCheck.lua): copies of Pathwise in the group
-- and guild tell each other their version; a newer one is said in chat.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local UpdateCheck = Pathwise:GetModule("UpdateCheck")
local mine = Pathwise.Platform.GetAddOnMetadata("Version")
local minePlain = mine:match("^%d+%.%d+%.%d+")
local sent = {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, text, channel, target) sent[#sent + 1] = { prefix, text, channel, target } end,
}
local function Message(text, sender, prefix)
  WoW.FireEvent("CHAT_MSG_ADDON", prefix or UpdateCheck.PREFIX, text, "GUILD", sender)
end

---------------------------------------------------------------------------
section("Update reminder: versions")

check("a test build's suffix left out", UpdateCheck.IsNewer("0.2.0", "0.1.0-test") and not UpdateCheck.IsNewer("0.1.0", "0.1.0-test"))
check("newer: by any part", UpdateCheck.IsNewer("0.55.0", "0.54.12") and UpdateCheck.IsNewer("1.0.0", "0.99.99")
  and UpdateCheck.IsNewer("0.54.10", "0.54.9"))
check("not newer: the same, older, or unreadable", not UpdateCheck.IsNewer("0.54.5", "0.54.5")
  and not UpdateCheck.IsNewer("0.54.4", "0.54.5") and not UpdateCheck.IsNewer("x", "0.54.5")
  and not UpdateCheck.IsNewer("0.55", "0.54.5"))

---------------------------------------------------------------------------
section("Update reminder: hearing of others")

WoW.ClearChat()
Message("V:0.1.0", S.name or UnitName("player"))
Message("V:99.0.0", UnitName("player") .. "-SomeRealm")
check("our own message: nothing", not WoW.ChatContains("newer version"))
Message("V:99.0.0", "Someone", "PathwiseEnc")
check("another addon's prefix (the other Pathwise): nothing", not WoW.ChatContains("newer version"))
Message("hello 99.0.0", "Someone-Realm")
check("not a version message: nothing", not WoW.ChatContains("newer version"))
Message("V:99.0.0", "Someone-Realm")
check("a newer version: said in chat (" .. tostring(WoW.ChatContains("99.0.0")) .. ")",
  WoW.ChatContains("A newer version of Pathwise is out (99.0.0) - you have " .. mine))
check("... and remembered for the next login", Pathwise.db.newestVersionSeen == "99.0.0")
WoW.ClearChat()
Message("V:99.0.1", "Another-Realm")
check("said once per session", not WoW.ChatContains("newer version") and Pathwise.db.newestVersionSeen == "99.0.1")

sent = {}
Message("V:0.0.1", "Oldie-Realm")
check("an older version: told ours back, whispered", #sent == 1 and sent[1][1] == UpdateCheck.PREFIX
  and sent[1][2] == "V:" .. minePlain and sent[1][3] == "WHISPER" and sent[1][4] == "Oldie-Realm")
Message("V:0.0.1", "Oldie-Realm")
check("... once", #sent == 1)

---------------------------------------------------------------------------
section("Update reminder: telling the group")

sent = {}
IsInGroup = function() return true end
WoW.FireEvent("GROUP_ROSTER_UPDATE")
check("joined a group: our version to it", #sent == 1 and sent[1][3] == "PARTY" and sent[1][2] == "V:" .. minePlain)
WoW.FireEvent("GROUP_ROSTER_UPDATE")
check("not again right away", #sent == 1)
IsInRaid = function() return true end
WoW.FireEvent("GROUP_ROSTER_UPDATE")
check("a raid: to it", #sent == 2 and sent[2][3] == "RAID")
IsInGroup, IsInRaid = nil, nil
sent = {}
WoW.FireEvent("GROUP_ROSTER_UPDATE")
check("no group: nothing", #sent == 0)
Pathwise.db.updateReminder = false
IsInGroup = function() return true end
WoW.now = WoW.now + 120
WoW.FireEvent("GROUP_ROSTER_UPDATE")
check("switched off: nothing sent", #sent == 0)
IsInGroup = nil
Pathwise.db.updateReminder = true

-- Clean up
C_ChatInfo = nil
Pathwise.db.newestVersionSeen = nil
