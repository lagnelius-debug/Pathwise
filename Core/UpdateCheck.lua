local addonName, Pathwise = ...

-- Update reminder: addons can't go online, so - like Questie - each copy of
-- Pathwise tells the others in its group and guild which version it is (a
-- hidden addon message). Hearing of a newer one, it says so in chat, once
-- per session, and again at each login until it's updated. Hearing of an
-- older one, it tells that player back (a whisper, once), so the news
-- spreads both ways. Off on the Features page.

local L = Pathwise.L
local Platform = Pathwise.Platform

local UpdateCheck = Pathwise:NewModule("UpdateCheck")

-- Our own prefix (at most 16 characters): another addon named Pathwise
-- uses "PathwiseEnc" for its messages.
UpdateCheck.PREFIX = "PathwiseGuide"
-- The same channel is told at most this often (seconds).
UpdateCheck.ANNOUNCE_EVERY = 60
-- Seconds after logging in before telling the guild (the game is busy then).
UpdateCheck.LOGIN_DELAY = 15

local lastAnnounce = {} -- [channel] = time
local toldBack = {}     -- [sender] = true: told our newer version this session
local warned = false

-- "0.54.5" -> { 0, 54, 5 }, or nil. (Anything after the third number - a
-- test build's "-test" - is left out.)
function UpdateCheck.Parse(version)
  local a, b, c = tostring(version or ""):match("^(%d+)%.(%d+)%.(%d+)")
  if not a then
    return nil
  end
  return { tonumber(a), tonumber(b), tonumber(c) }
end

-- Whether version a is newer than b ("0.55.0" > "0.54.12"); false when
-- either can't be read.
function UpdateCheck.IsNewer(a, b)
  local pa, pb = UpdateCheck.Parse(a), UpdateCheck.Parse(b)
  if not pa or not pb then
    return false
  end
  for i = 1, 3 do
    if pa[i] ~= pb[i] then
      return pa[i] > pb[i]
    end
  end
  return false
end

local function MyVersion()
  return Platform.GetAddOnMetadata("Version")
end

-- "0.54.5" of "0.54.5-test", or nil.
local function Plain(version)
  local parts = UpdateCheck.Parse(version)
  return parts and table.concat(parts, ".") or nil
end

local function Announce(channel, target)
  local version = Plain(MyVersion())
  if not (Pathwise.db.updateReminder and channel and version) then
    return
  end
  local key = channel .. (target or "")
  local now = Platform.GetTime()
  if lastAnnounce[key] and now - lastAnnounce[key] < UpdateCheck.ANNOUNCE_EVERY then
    return
  end
  lastAnnounce[key] = now
  Platform.SendAddonMessage(UpdateCheck.PREFIX, "V:" .. version, channel, target)
end

local function Remind(newer)
  if warned or not Pathwise.db.updateReminder then
    return
  end
  warned = true
  Pathwise:Printf(L.UPDATE_AVAILABLE, newer, MyVersion() or "?")
end

function UpdateCheck:OnAddonMessage(_, prefix, message, channel, sender)
  if prefix ~= UpdateCheck.PREFIX or Platform.IsPlayerSender(sender) then
    return
  end
  local version = tostring(message or ""):match("^V:(%d+%.%d+%.%d+)$")
  local mine = MyVersion()
  if not version or not mine then
    return
  end
  if UpdateCheck.IsNewer(version, mine) then
    -- (Remembered: said again at the next login, until it's updated.)
    if UpdateCheck.IsNewer(version, Pathwise.db.newestVersionSeen or mine) then
      Pathwise.db.newestVersionSeen = version
    end
    Remind(version)
  elseif UpdateCheck.IsNewer(mine, version) and sender and not toldBack[sender] then
    toldBack[sender] = true
    Announce("WHISPER", sender)
  end
end

-- Joined a group (or it changed): tell it.
function UpdateCheck:OnGroupChanged()
  Announce(Platform.GroupChannel())
end

function UpdateCheck:OnEnable()
  Platform.RegisterAddonPrefix(UpdateCheck.PREFIX)
  self:RegisterEvent("CHAT_MSG_ADDON", "OnAddonMessage")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupChanged")
  -- A newer version heard of before (and still not installed).
  local seen = Pathwise.db.newestVersionSeen
  if seen and UpdateCheck.IsNewer(seen, MyVersion()) then
    Platform.After(UpdateCheck.LOGIN_DELAY, function()
      Remind(seen)
    end)
  else
    Pathwise.db.newestVersionSeen = nil
  end
  Platform.After(UpdateCheck.LOGIN_DELAY, function()
    if Platform.IsInGuild() then
      Announce("GUILD")
    end
    Announce(Platform.GroupChannel())
  end)
end
