local addonName, Pathwise = ...

-- Core bootstrap: namespace, saved variables, event dispatcher, internal
-- callbacks, module registry, slash command registry and chat output.
--
-- Like all of Core, this file never calls WoW API directly; it goes through
-- Pathwise.Platform (loaded just before this file).

local L = Pathwise.L
local Platform = Pathwise.Platform

Pathwise.name = addonName
Pathwise.version = "dev"
Pathwise.Data = Pathwise.Data or {}

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

-- Account-wide settings.
local DB_DEFAULTS = {
  schema = 1,
  debug = false,
  chatMessages = true,
  trainerPanel = true, -- show the Training panel next to the spellbook
  nextSteps = { shown = true }, -- Next Steps window: visibility and position
  arrow = {},                   -- arrow position
  arrowAuto = true,             -- arrow follows the top Next Steps item
  questLocations = {},          -- learned quest locations (Core/QuestLocations.lua)
  targetMacro = true,           -- keep the "Pathwise" target macro up to date
  sellPrice = true,             -- show vendor sell prices in item tooltips
  ammoWarn = 200,               -- hunter: warn below this much ammo
  ammoCritical = 50,            -- hunter: urgent warning below this
  modules = {}, -- [moduleName] = false disables a module
}

-- Per-character state.
local CHAR_DEFAULTS = {
  schema = 1,
  goal = nil,           -- chosen goal/spec key, e.g. "LEVELING"
  goalPrompted = false, -- the one-time goal prompt has been shown
  dismissed = {},       -- dismissed reminders, by id
  trainerAnnouncedLevel = nil, -- level the trainer reminder was last shown for
  talentAnnouncedLevel = nil,  -- level the talent reminder was last shown for
  tamingReminded = false,      -- hunter: the taming quest reminder was shown
  lastSnapshot = nil,   -- last character snapshot (written by Character)
}

local function CopyDefaults(defaults, target)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      CopyDefaults(value, target[key])
    elseif target[key] == nil then
      target[key] = value
    end
  end
  return target
end

-- Clears a table in place and refills it with defaults, so modules holding a
-- reference to Pathwise.db / Pathwise.charDB keep a valid table.
local function ResetTable(target, defaults)
  for key in pairs(target) do
    target[key] = nil
  end
  CopyDefaults(defaults, target)
end

local function InitSavedVariables()
  -- PathwiseDB / PathwiseCharDB are the addon's SavedVariables (declared in
  -- the TOC); they are the only globals Pathwise owns.
  if type(PathwiseDB) ~= "table" then
    PathwiseDB = {}
  end
  if type(PathwiseCharDB) ~= "table" then
    PathwiseCharDB = {}
  end
  Pathwise.db = CopyDefaults(DB_DEFAULTS, PathwiseDB)
  Pathwise.charDB = CopyDefaults(CHAR_DEFAULTS, PathwiseCharDB)
end

function Pathwise:ResetSettings()
  ResetTable(self.db, DB_DEFAULTS)
  self:FireCallback("SETTINGS_RESET")
end

function Pathwise:ResetCharacter()
  ResetTable(self.charDB, CHAR_DEFAULTS)
  self:FireCallback("CHARACTER_RESET")
end

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------

local PREFIX = "|cff33ff99Pathwise|r: "
local DEBUG_PREFIX = "|cff33ff99Pathwise|r |cff888888[debug]|r "

local function Join(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring((select(i, ...)))
  end
  return table.concat(parts, " ")
end

function Pathwise:Print(...)
  Platform.Print(PREFIX .. Join(...))
end

function Pathwise:Printf(fmt, ...)
  Platform.Print(PREFIX .. string.format(fmt, ...))
end

-- Prints a line without the prefix (for multi-line output like /pw status).
function Pathwise:PrintLine(...)
  Platform.Print(Join(...))
end

function Pathwise:Debug(...)
  if self.db and self.db.debug then
    Platform.Print(DEBUG_PREFIX .. Join(...))
  end
end

function Pathwise:Debugf(fmt, ...)
  if self.db and self.db.debug then
    Platform.Print(DEBUG_PREFIX .. string.format(fmt, ...))
  end
end

-- Formats copper as "1g 2s 3c" (plain text; the UI may use coin icons).
function Pathwise.FormatMoney(copper)
  copper = copper or 0
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper / 100) % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = gold .. "g"
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. "s"
  end
  if copper % 100 > 0 or #parts == 0 then
    parts[#parts + 1] = (copper % 100) .. "c"
  end
  return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- Handler registries (shared by WoW events and internal callbacks)
---------------------------------------------------------------------------

-- A registry maps a name to a list of { owner, handler } entries. Handlers are
-- called as handler(owner, name, ...); a string handler is a method name on
-- owner. Lists are copy-on-write so handlers may (un)register while a
-- dispatch is running.
local function CreateRegistry(onFirst, onLast)
  local registry = { lists = {} }

  function registry:Register(name, owner, handler)
    local old = self.lists[name] or {}
    local list = {}
    for i, entry in ipairs(old) do
      if entry.owner ~= owner then
        list[#list + 1] = entry
      end
    end
    list[#list + 1] = { owner = owner, handler = handler }
    self.lists[name] = list
    if #old == 0 and onFirst then
      onFirst(name)
    end
  end

  function registry:Unregister(name, owner)
    local old = self.lists[name]
    if not old then
      return
    end
    local list = {}
    for _, entry in ipairs(old) do
      if entry.owner == owner then
        entry.removed = true
      else
        list[#list + 1] = entry
      end
    end
    self.lists[name] = (#list > 0) and list or nil
    if #list == 0 and onLast then
      onLast(name)
    end
  end

  function registry:Fire(name, ...)
    local list = self.lists[name]
    if not list then
      return
    end
    for _, entry in ipairs(list) do
      if not entry.removed then
        local handler = entry.handler
        if type(handler) == "string" then
          handler = entry.owner[handler]
        end
        handler(entry.owner, name, ...)
      end
    end
  end

  return registry
end

local events = CreateRegistry(
  function(event)
    if not Platform.RegisterEvent(event) then
      Pathwise:Debugf("Event %s does not exist in this client; ignored.", event)
    end
  end,
  function(event)
    Platform.UnregisterEvent(event)
  end
)

local callbacks = CreateRegistry()

-- WoW events. handler(owner, event, ...) or a method name on owner.
function Pathwise:RegisterEvent(event, owner, handler)
  events:Register(event, owner, handler or event)
end

function Pathwise:UnregisterEvent(event, owner)
  events:Unregister(event, owner)
end

-- Called by the platform layer for every registered event.
function Pathwise:DispatchEvent(event, ...)
  events:Fire(event, ...)
end

-- Internal callbacks between modules, e.g. "CHARACTER_UPDATED".
function Pathwise:RegisterCallback(name, owner, handler)
  callbacks:Register(name, owner, handler or name)
end

function Pathwise:UnregisterCallback(name, owner)
  callbacks:Unregister(name, owner)
end

function Pathwise:FireCallback(name, ...)
  self:Debugf("callback %s", name)
  callbacks:Fire(name, ...)
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

-- A module is a table with optional OnInitialize (saved variables ready) and
-- OnEnable (player logged in) methods, plus the helpers below.
Pathwise.modules = {}
local moduleOrder = {}

local ModuleMixin = {}

function ModuleMixin:RegisterEvent(event, handler)
  Pathwise:RegisterEvent(event, self, handler)
end

function ModuleMixin:UnregisterEvent(event)
  Pathwise:UnregisterEvent(event, self)
end

function ModuleMixin:RegisterCallback(name, handler)
  Pathwise:RegisterCallback(name, self, handler)
end

function ModuleMixin:UnregisterCallback(name)
  Pathwise:UnregisterCallback(name, self)
end

function ModuleMixin:Debug(...)
  Pathwise:Debug("[" .. self.name .. "]", ...)
end

function ModuleMixin:Debugf(fmt, ...)
  Pathwise:Debug("[" .. self.name .. "]", string.format(fmt, ...))
end

function Pathwise:NewModule(name)
  assert(not self.modules[name], "Module already exists: " .. name)
  local module = setmetatable({ name = name }, { __index = ModuleMixin })
  self.modules[name] = module
  moduleOrder[#moduleOrder + 1] = module
  return module
end

function Pathwise:GetModule(name)
  return self.modules[name]
end

function Pathwise:IsModuleEnabled(name)
  return not (self.db and self.db.modules[name] == false)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

-- The UI layer binds /pathwise and /pw to Pathwise:HandleSlashCommand.
local commands = {}
local commandOrder = {}

-- handler(args) receives the rest of the line after the command word.
-- help is shown by /pw help; pass nil to hide a command from the list.
function Pathwise:RegisterCommand(name, handler, help)
  if not commands[name] then
    commandOrder[#commandOrder + 1] = name
  end
  commands[name] = { handler = handler, help = help }
end

function Pathwise:PrintHelp()
  self:Print(L.HELP_HEADER)
  for _, name in ipairs(commandOrder) do
    local command = commands[name]
    if command.help then
      self:PrintLine(string.format("  |cffffd200/pw %s|r - %s", name, command.help))
    end
  end
end

function Pathwise:HandleSlashCommand(message)
  message = (message or ""):match("^%s*(.-)%s*$")
  local name, args = message:match("^(%S*)%s*(.-)$")
  name = name:lower()
  local command = commands[name]
  if command then
    command.handler(args)
  else
    self:Printf(L.UNKNOWN_COMMAND, name)
    self:PrintHelp()
  end
end

-- "/pw" with no arguments toggles the Next Steps panel (built in M7).
Pathwise:RegisterCommand("", function()
  Pathwise:Print(L.NEXT_STEPS_NOT_READY)
  Pathwise:PrintHelp()
end)

Pathwise:RegisterCommand("help", function()
  Pathwise:PrintHelp()
end, L.CMD_HELP)

Pathwise:RegisterCommand("debug", function(args)
  args = args:lower()
  if args == "on" then
    Pathwise.db.debug = true
  elseif args == "off" then
    Pathwise.db.debug = false
  else
    Pathwise.db.debug = not Pathwise.db.debug
  end
  Pathwise:Print(Pathwise.db.debug and L.DEBUG_ON or L.DEBUG_OFF)
end, L.CMD_DEBUG)

Pathwise:RegisterCommand("reset", function(args)
  if args:lower() == "char" then
    Pathwise:ResetCharacter()
    Pathwise:Print(L.RESET_CHAR_DONE)
  else
    Pathwise:ResetSettings()
    Pathwise:Print(L.RESET_DONE)
  end
end, L.CMD_RESET)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local lifecycle = {}

-- Runs a module's lifecycle method so that an error in one module is
-- reported (and shown by BugSack / scriptErrors) without stopping the others.
local function CallModule(module, method)
  if module[method] then
    local ok = Platform.SafeCall(module[method], module)
    if not ok then
      Pathwise:Printf(L.MODULE_ERROR, module.name, method)
    end
  end
end

function lifecycle:ADDON_LOADED(_, loadedName)
  if loadedName ~= addonName then
    return
  end
  Pathwise:UnregisterEvent("ADDON_LOADED", lifecycle)

  InitSavedVariables()
  Pathwise.version = Platform.GetAddOnMetadata("Version") or Pathwise.version

  for _, module in ipairs(moduleOrder) do
    CallModule(module, "OnInitialize")
  end
  Pathwise:Debug("Initialized.")
end

function lifecycle:PLAYER_LOGIN()
  Pathwise:UnregisterEvent("PLAYER_LOGIN", lifecycle)
  Pathwise:Printf(L.LOADED, Pathwise.version)

  for _, module in ipairs(moduleOrder) do
    if Pathwise:IsModuleEnabled(module.name) then
      module.enabled = true
      CallModule(module, "OnEnable")
    else
      Pathwise:Debugf("Module %s is disabled.", module.name)
    end
  end

  Pathwise:FireCallback("LOGIN")
end

Pathwise:RegisterEvent("ADDON_LOADED", lifecycle)
Pathwise:RegisterEvent("PLAYER_LOGIN", lifecycle)
