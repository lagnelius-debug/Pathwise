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
  -- Private mock fields ("_level") and lowercase fields addons set themselves
  -- ("label", "type") are plain nil when unset.
  if key:sub(1, 1) == "_" or key:sub(1, 1):match("%l") then
    return nil
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
function FrameMethods:SetRotation(radians) self._rotation = radians end
function FrameMethods:SetVertexColor(r, g, b) self._color = { r, g, b } end
function FrameMethods:GetID() return self._id or 0 end
function FrameMethods:SetID(id) self._id = id end
function FrameMethods:GetFrameLevel() return self._level or 1 end
function FrameMethods:SetFrameLevel(level) self._level = level end
function FrameMethods:SetParent(parent) self._parent = parent end

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
-- Tooltips: lines are stored as TextLeftN font strings like the real ones.
local function NewTooltip(name)
  local tooltip = NewObject("GameTooltip", name, UIParent)
  tooltip._lines = 0
  function tooltip:NumLines() return self._lines end
  function tooltip:AddLine(text)
    self._lines = self._lines + 1
    local fontString = _G[name .. "TextLeft" .. self._lines] or NewObject("FontString")
    fontString._text = text
    _G[name .. "TextLeft" .. self._lines] = fontString
  end
  function tooltip:ClearLines()
    for i = 1, self._lines do _G[name .. "TextLeft" .. i]._text = nil end
    self._lines = 0
    self._link = nil
  end
  function tooltip:GetItem() return self._link and "name", self._link end
  function tooltip:GetOwner() return self._owner end
  return tooltip
end
GameTooltip = NewTooltip("GameTooltip")
ItemRefTooltip = NewTooltip("ItemRefTooltip")

-- Shows an item in a tooltip like hovering it would, returns the Pathwise line.
function WoW.HoverItem(itemID, tooltip, owner)
  tooltip = tooltip or GameTooltip
  tooltip:ClearLines()
  tooltip._owner = owner
  tooltip._link = WoW.ItemLink(itemID)
  tooltip:AddLine(WoW.items[itemID].name)
  if tooltip._scripts.OnTooltipSetItem then
    tooltip._scripts.OnTooltipSetItem(tooltip)
  end
  for i = 1, tooltip._lines do
    local text = _G[tooltip:GetName() .. "TextLeft" .. i]._text
    if text and text:find("Pathwise: ", 1, true) then
      return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
  end
end
time = os.time
WoW.now = 1000
function GetTime() return WoW.now end
WoW.errors = {}
function geterrorhandler()
  return function(err) WoW.errors[#WoW.errors + 1] = err end
end

-- All text lines of a tooltip (color codes stripped).
function WoW.TooltipLines(tooltip)
  local lines = {}
  for i = 1, tooltip._lines do
    local text = _G[tooltip:GetName() .. "TextLeft" .. i]._text
    lines[#lines + 1] = text and (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or ""
  end
  return lines
end

MerchantFrame = NewObject("Frame", "MerchantFrame", UIParent)
MerchantFrame._shown = false

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

function UnitName(unit)
  if unit == "npc" then return S.npcName end
  return S.name
end
function UnitExists(unit)
  if unit == "npc" then return S.npcName ~= nil end
  return true
end

-- Macros
WoW.macros = {} -- list of { name, icon, body, perCharacter }
WoW.cursor = nil
MAX_CHARACTER_MACROS = 18
function GetMacroIndexByName(name)
  for i, macro in ipairs(WoW.macros) do
    if macro.name == name then return i end
  end
  return 0
end
function GetNumMacros()
  local general, character = 0, 0
  for _, macro in ipairs(WoW.macros) do
    if macro.perCharacter then character = character + 1 else general = general + 1 end
  end
  return general, character
end
function CreateMacro(name, icon, body, perCharacter)
  if S.inCombat then error("CreateMacro in combat") end
  WoW.macros[#WoW.macros + 1] = { name = name, icon = icon, body = body, perCharacter = perCharacter }
  return #WoW.macros
end
function EditMacro(index, name, icon, body)
  if S.inCombat then error("EditMacro in combat") end
  local macro = WoW.macros[index]
  macro.name, macro.icon, macro.body = name, icon, body
end
function PickupMacro(index) WoW.cursor = WoW.macros[index] end
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
-- Item database for GetItemInfo / GetItemStats. Inventory entries refer to
-- these by id. Fields: name, quality, minLevel, equipLoc, classID, subclassID,
-- sell, stats.
WoW.items = {
  [2504] = { name = "Worn Shortbow", equipLoc = "INVTYPE_RANGED", classID = 2, subclassID = 2,
             stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.5 } },
  [2092] = { name = "Worn Dagger", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 15,
             stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 1.6 } },
  [2512] = { name = "Rough Arrow", equipLoc = "INVTYPE_AMMO", classID = 6, subclassID = 2, stats = {} },
  [6123] = { name = "Novice's Robe", equipLoc = "INVTYPE_ROBE", classID = 4, subclassID = 1, stats = {} },
  [12345] = { name = "Uncached Axe", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 0,
              stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.0 } },
  [148] = { name = "Rugged Trapper's Boots", equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 2, stats = {} },
  [2309] = { name = "Ragged Leather Boots", equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 2,
             stats = { RESISTANCE0_NAME = 16 } },
  [9001] = { name = "Agile Boots", equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 2,
             stats = { RESISTANCE0_NAME = 20, ITEM_MOD_AGILITY_SHORT = 2 } },
  [9002] = { name = "Flimsy Boots", equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 1,
             stats = { RESISTANCE0_NAME = 10, ITEM_MOD_AGILITY_SHORT = 2 } },
  [9003] = { name = "Chain Vest", equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3, minLevel = 15,
             stats = { RESISTANCE0_NAME = 80 } },
  [9004] = { name = "Plate Helm", equipLoc = "INVTYPE_HEAD", classID = 4, subclassID = 4, sell = 50,
             stats = { RESISTANCE0_NAME = 200 } },
  [9005] = { name = "Heavy Mace", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 4, sell = 120,
             stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 } },
  [9006] = { name = "Hunting Bow", equipLoc = "INVTYPE_RANGED", classID = 2, subclassID = 2, minLevel = 8,
             stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5.0, ITEM_MOD_AGILITY_SHORT = 1 } },
  [9007] = { name = "Ring of Agility", equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0,
             stats = { ITEM_MOD_AGILITY_SHORT = 3 } },
  [9008] = { name = "Ring of Stamina", equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0,
             stats = { ITEM_MOD_STAMINA_SHORT = 3 } },
  [9009] = { name = "Ring of Spirit", equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0,
             stats = { ITEM_MOD_SPIRIT_SHORT = 2 } },
  [9010] = { name = "Big Axe", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 1,
             stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, ITEM_MOD_AGILITY_SHORT = 4 } },
  [9012] = { name = "Quest Token", equipLoc = "", classID = 12, subclassID = 0, sell = 0, stats = {} },
  [9013] = { name = "Thistlewood Staff", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 10,
              stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4, ITEM_MOD_AGILITY_SHORT = 2 } },
  [9014] = { name = "Thistlewood Maul", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 5,
              stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4 } },
  [9015] = { name = "Thistlewood Dagger", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 15,
              stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.5 } },
  [9016] = { name = "Thistlewood Blade", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7,
              stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.6 } },
  [9011] = { name = "Sharp Dagger", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 15,
             stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 3, ITEM_MOD_AGILITY_SHORT = 1 } },
}

function WoW.ItemLink(itemID)
  local item = WoW.items[itemID]
  return string.format("|cffffffff|Hitem:%d::::::::1:::::::|h[%s]|h|r", itemID, item and item.name or "?")
end

WoW.uncachedItems = {} -- [itemID] = true: GetItemInfo returns nil

local function IsUncached(itemID)
  if WoW.uncachedItems[itemID] then return true end
  for _, item in pairs(S.inventory) do
    if item.id == itemID and item.uncached then return true end
  end
  return false
end

-- Like the real client, the ammo slot (0) never returns a link.
function GetInventoryItemLink(_, slot)
  local item = S.inventory[slot]
  if not item or item.uncached or slot == 0 then return nil end
  return WoW.ItemLink(item.id)
end

local function ItemIDOf(item)
  if type(item) == "number" then return item end
  return tonumber(tostring(item):match("item:(%d+)"))
end

function GetItemInfo(item)
  local itemID = ItemIDOf(item)
  local data = WoW.items[itemID]
  if not data or IsUncached(itemID) then return nil end
  return data.name, WoW.ItemLink(itemID), data.quality or 1, 5, data.minLevel or 0, "Type", "SubType", 1,
    data.equipLoc, "icon", data.sell or 1, data.classID, data.subclassID
end

function GetItemStats(link)
  local data = WoW.items[ItemIDOf(link)]
  if not data then return nil end
  local copy = {}
  for k, v in pairs(data.stats) do copy[k] = v end
  return copy
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
-- Maps: world rectangles in yards (top > bottom, left > right).
WoW.mapRects = {
  [1438] = { continent = 1, top = 10000, left = 12000, bottom = 7000, right = 9000 }, -- Teldrassil
  [1439] = { continent = 1, top = 7000, left = 12000, bottom = 3000, right = 8000 },  -- Darkshore
  [1429] = { continent = 0, top = 1000, left = 1000, bottom = 0, right = 0 },          -- Elwynn
}
S.mapX, S.mapY, S.facing = 0.5, 0.5, 0

local function Vector(x, y)
  return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
CreateVector2D = Vector
C_Map = {
  GetBestMapForUnit = function() return S.mapID end,
  GetPlayerMapPosition = function(mapID)
    if S.mapX == nil then return nil end
    return Vector(S.mapX, S.mapY)
  end,
  GetWorldPosFromMapPos = function(mapID, pos)
    local r = WoW.mapRects[mapID]
    if not r then return nil end
    return r.continent, Vector(r.top - pos.y * (r.top - r.bottom), r.left - pos.x * (r.left - r.right))
  end,
  GetMapInfo = function(mapID) return { name = "Map " .. mapID } end,
}
function GetPlayerFacing() return S.facing end

---------------------------------------------------------------------------
-- Quest turn-in
---------------------------------------------------------------------------

WoW.questChoices = {} -- item IDs offered as reward choices

function GetNumQuestChoices() return #WoW.questChoices end
function GetQuestItemLink(kind, index)
  local itemID = WoW.questChoices[index]
  if kind ~= "choice" or not itemID or WoW.uncachedItems[itemID] then return nil end
  return WoW.ItemLink(itemID)
end
function GetQuestItemInfo(kind, index)
  local itemID = WoW.questChoices[index]
  local item = itemID and WoW.items[itemID]
  return item and item.name, "icon", 1, 1, true
end

-- Reward buttons as the QuestInfo system builds them.
function WoW.SetupRewardButtons(count)
  QuestInfoRewardsFrame = NewObject("Frame", "QuestInfoRewardsFrame", UIParent)
  QuestInfoRewardsFrame.RewardButtons = {}
  for i = 1, count do
    local button = NewObject("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i, QuestInfoRewardsFrame)
    button.type = "choice"
    button:SetID(i)
    QuestInfoRewardsFrame.RewardButtons[i] = button
  end
end

---------------------------------------------------------------------------
-- Quest log
---------------------------------------------------------------------------

-- Entries: { header = true, title, collapsed } or
-- { title, level, group, complete (1 / -1 / nil), questID, objectives = { { text, finished } } }
WoW.questLog = {}

function GetNumQuestLogEntries() return #WoW.questLog end
function GetQuestLogTitle(i)
  local e = WoW.questLog[i]
  if not e then return nil end
  if e.header then return e.title, 0, 0, true, e.collapsed or false end
  return e.title, e.level, e.group or 0, false, false, e.complete, 0, e.questID
end
function GetNumQuestLeaderBoards(i)
  local e = WoW.questLog[i]
  return e and e.objectives and #e.objectives or 0
end
function GetQuestLogLeaderBoard(j, i)
  local o = WoW.questLog[i].objectives[j]
  return o.text, "monster", o.finished
end

---------------------------------------------------------------------------
-- Spells and spellbook
---------------------------------------------------------------------------

WoW.knownSpells = {} -- [spellID] = true
WoW.spellNames = {}  -- [spellID] = name; filled from the addon's data after loading

-- Weapon/armor skills the test hunter has learned (kept separate so tests
-- can reset WoW.knownSpells without losing them).
WoW.skills = {
  [264] = true,  -- Bows
  [1180] = true, -- Daggers
  [196] = true,  -- One-Handed Axes
  [197] = true,  -- Two-Handed Axes
  [9078] = true, -- Cloth
  [9077] = true, -- Leather
}
function IsSpellKnown(id) return WoW.knownSpells[id] == true or WoW.skills[id] == true end
function IsPlayerSpell(id) return IsSpellKnown(id) end
WoW.spellNames[227] = "Staves"
WoW.spellNames[201] = "One-Handed Swords"
WoW.spellNames[8737] = "Mail"
function GetSpellInfo(id)
  local name = WoW.spellNames[id]
  if not name then return nil end
  return name, nil, "icon" .. id
end
function GetSpellSubtext() return nil end

function hooksecurefunc(a, b, c)
  local tbl, name, fn = a, b, c
  if type(a) == "string" then tbl, name, fn = _G, a, b end
  local original = tbl[name]
  tbl[name] = function(...)
    local results = { original(...) }
    fn(...)
    return unpack(results)
  end
end

SpellBookFrame = CreateFrame("Frame", "SpellBookFrame", UIParent)
SpellBookFrame._shown = false
function SpellBookFrame:UpdateSkillLineTabs() end
for i = 1, 4 do
  CreateFrame("CheckButton", "SpellBookSkillLineTab" .. i, SpellBookFrame)
end

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
