-- Minimal mock of the WoW Classic Era API, enough to load Pathwise outside the
-- game and exercise Core logic. This is NOT a faithful emulation: it only
-- catches Lua errors, load-order mistakes and logic bugs. Real behaviour must
-- still be verified in game.
--
-- Not loaded by the TOC; run with:  lua5.1 tests/run.lua

local WoW = {}
_G.WoW = WoW

WoW.chat = {}
WoW.timers = {}
WoW.frames = {}
WoW.unknownEvents = { PLAYER_TALENT_UPDATE = true } -- pretend these don't exist

-- Character state the API functions read from. Tests mutate this.
WoW.state = {
  name = "Testhunter",
  realm = "Mockrealm",
  class = { "Hunter", "HUNTER", 3 },
  race = { "Night Elf", "NightElf", 4 },
  faction = { "Alliance", "Alliance" },
  level = 1,
  xp = 0,
  xpMax = 400,
  rested = nil,
  inCombat = false,
  zone = "Teldrassil",
  subZone = "Shadowglen",
  mapID = 1438,
  inventory = {}, -- [slot] = { id, name }
  talentTabs = {
    { name = "Beast Mastery", talents = {
      { "Improved Aspect of the Hawk", 1, 2, 0, 5 },
      { "Endurance Training", 1, 3, 0, 5 },
      { "Improved Eyes of the Beast", 2, 1, 0, 2 },
    } },
    { name = "Marksmanship", talents = {
      { "Improved Concussive Shot", 1, 1, 0, 5 },
      { "Efficiency", 1, 2, 0, 5 },
    } },
    { name = "Survival", talents = {
      { "Monster Slaying", 1, 1, 0, 3 },
      { "Humanoid Slaying", 1, 2, 0, 3 },
    } },
  },
  skills = {
    { "Professions", true, true },
    { "Skinning", false, false, 1, 75 },
    { "Weapon Skills", true, true },
    { "Bows", false, false, 5, 5 },
    { "Daggers", false, false, 1, 5 },
  },
}

local function Strip(message)
  return (message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

function WoW.ClearChat()
  WoW.chat = {}
end

function WoW.ChatContains(text)
  for _, line in ipairs(WoW.chat) do
    if line:find(text, 1, true) then
      return true
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local FrameMethods = {}
FrameMethods.__index = function(self, key)
  local method = rawget(FrameMethods, key)
  if method then
    return method
  end
  -- Any unknown method is a no-op returning nil.
  return function() end
end

function FrameMethods:RegisterEvent(event)
  if WoW.unknownEvents[event] then
    error("Attempt to register unknown event \"" .. event .. "\"")
  end
  self._events[event] = true
end
function FrameMethods:UnregisterEvent(event) self._events[event] = nil end
function FrameMethods:SetScript(name, fn) self._scripts[name] = fn end
function FrameMethods:GetScript(name) return self._scripts[name] end
function FrameMethods:HookScript(name, fn)
  local old = self._scripts[name]
  self._scripts[name] = function(...) if old then old(...) end fn(...) end
end
function FrameMethods:Show()
  local was = self._shown
  self._shown = true
  if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function FrameMethods:Hide()
  local was = self._shown
  self._shown = false
  if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function FrameMethods:IsShown() return self._shown end
function FrameMethods:IsVisible() return self._shown end
function FrameMethods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function FrameMethods:SetText(text) self._text = text end
function FrameMethods:GetText() return self._text end
function FrameMethods:Click() if self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end end
function FrameMethods:GetName() return self._name end
function FrameMethods:GetParent() return self._parent end
function FrameMethods:GetWidth() return self._width or 100 end
function FrameMethods:GetHeight() return self._height or 20 end
function FrameMethods:SetWidth(w) self._width = w end
function FrameMethods:SetHeight(h) self._height = h end
function FrameMethods:SetSize(w, h) self._width, self._height = w, h end
function FrameMethods:GetStringWidth() return #(self._text or "") * 6 end
function FrameMethods:SetBackdrop() end

local function NewObject(kind, name, parent)
  local object = setmetatable({
    _kind = kind, _name = name, _parent = parent,
    _events = {}, _scripts = {}, _shown = true,
  }, FrameMethods)
  return object
end

function FrameMethods:CreateFontString(name)
  return NewObject("FontString", name, self)
end
function FrameMethods:CreateTexture(name)
  return NewObject("Texture", name, self)
end

function CreateFrame(kind, name, parent, template)
  local frame = NewObject(kind, name, parent)
  frame._template = template
  if template and template:find("UIPanelCloseButton") then
    frame._scripts.OnClick = function(self) self:GetParent():Hide() end
  end
  WoW.frames[#WoW.frames + 1] = frame
  if name then _G[name] = frame end
  return frame
end

function WoW.FireEvent(event, ...)
  for _, frame in ipairs(WoW.frames) do
    if frame._events[event] and frame._scripts.OnEvent then
      frame._scripts.OnEvent(frame, event, ...)
    end
  end
end

UIParent = NewObject("Frame", "UIParent")
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, message)
    WoW.chat[#WoW.chat + 1] = Strip(message)
    if WoW.echo then print(Strip(message)) end
  end,
}
BackdropTemplateMixin = {}
GameTooltip = NewObject("GameTooltip", "GameTooltip", UIParent)
time = os.time
WoW.errors = {}
function geterrorhandler()
  return function(err) WoW.errors[#WoW.errors + 1] = err end
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------

C_Timer = {
  After = function(seconds, fn)
    WoW.timers[#WoW.timers + 1] = fn
  end,
}

function WoW.RunTimers()
  while #WoW.timers > 0 do
    local fn = table.remove(WoW.timers, 1)
    fn()
  end
end

---------------------------------------------------------------------------
-- Game API (reads WoW.state)
---------------------------------------------------------------------------

local S = WoW.state

function GetBuildInfo() return "1.15.9", "99999", "Jan 1 2026", 11509 end
C_AddOns = {
  GetAddOnMetadata = function(_, field)
    if field == "Version" then return "0.1.0-test" end
  end,
}
function InCombatLockdown() return S.inCombat end
function UnitAffectingCombat() return S.inCombat end

function UnitName() return S.name end
function GetRealmName() return S.realm end
function UnitClass() return S.class[1], S.class[2], S.class[3] end
function UnitRace() return S.race[1], S.race[2], S.race[3] end
function UnitFactionGroup() return S.faction[1], S.faction[2] end
function UnitLevel() return S.level end
function UnitXP() return S.xp end
function UnitXPMax() return S.xpMax end
function GetXPExhaustion() return S.rested end
function GetMaxPlayerLevel() return 60 end

INVSLOT_AMMO = 0
function GetInventoryItemID(_, slot)
  local item = S.inventory[slot]
  return item and item.id
end
function GetInventoryItemLink(_, slot)
  local item = S.inventory[slot]
  if not item or item.uncached then return nil end
  return string.format("|cffffffff|Hitem:%d::::::::1:::::::|h[%s]|h|r", item.id, item.name)
end

function GetNumTalentTabs() return #S.talentTabs end
function GetTalentTabInfo(tab)
  local t = S.talentTabs[tab]
  local spent = 0
  for _, talent in ipairs(t.talents) do spent = spent + talent[4] end
  return t.name, "icon", spent, "file"
end
function GetNumTalents(tab) return #S.talentTabs[tab].talents end
function GetTalentInfo(tab, index)
  local talent = S.talentTabs[tab].talents[index]
  return talent[1], "icon", talent[2], talent[3], talent[4], talent[5], false, true
end
function UnitCharacterPoints()
  local spent = 0
  for _, tab in ipairs(S.talentTabs) do
    for _, talent in ipairs(tab.talents) do spent = spent + talent[4] end
  end
  return math.max(0, S.level - 9 - spent), 0
end

function WoW.SetTalentRank(tab, index, rank)
  S.talentTabs[tab].talents[index][4] = rank
end

function GetNumSkillLines() return #S.skills end
function GetSkillLineInfo(i)
  local s = S.skills[i]
  -- name, isHeader, isExpanded, rank, tempPoints, modifier, maxRank, isAbandonable
  return s[1], s[2], s[3], s[4] or 0, 0, 0, s[5] or 0, s[1] == "Skinning"
end

function GetRealZoneText() return S.zone end
function GetSubZoneText() return S.subZone end
C_Map = { GetBestMapForUnit = function() return S.mapID end }

---------------------------------------------------------------------------
-- Addon loading
---------------------------------------------------------------------------

SlashCmdList = {}

function WoW.LoadAddon(tocPath, addonName)
  local namespace = {}
  local dir = tocPath:match("^(.*)/[^/]*$") or "."
  for line in io.lines(tocPath) do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
      local path = dir .. "/" .. line:gsub("\\", "/")
      local chunk = assert(loadfile(path))
      chunk(addonName, namespace)
    end
  end
  return namespace
end

function WoW.Slash(message)
  SlashCmdList.PATHWISE(message)
end

return WoW
