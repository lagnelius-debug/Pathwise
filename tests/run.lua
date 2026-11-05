-- Offline smoke tests. Run from the repository root:  lua5.1 tests/run.lua
-- Set PATHWISE_ECHO=1 to also print the addon's chat output.

package.path = "./tests/?.lua;" .. package.path
local WoW = require("mock_wow")
WoW.echo = os.getenv("PATHWISE_ECHO") == "1"

local passed, failed = 0, 0
local function check(description, condition)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. description)
  end
end

local function section(name)
  if WoW.echo then print("\n== " .. name .. " ==") end
end

---------------------------------------------------------------------------
section("M0: load and login")

local Pathwise = WoW.LoadAddon("./Pathwise_Vanilla.toc", "Pathwise")

-- A module that fails must not stop the login message or other modules.
local broken = Pathwise:NewModule("BrokenTestModule")
function broken:OnEnable() error("boom") end
local function ReadFile(path) local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s end
check("Pathwise.toc matches Pathwise_Vanilla.toc", ReadFile("./Pathwise.toc") == ReadFile("./Pathwise_Vanilla.toc"))
-- WoW Forever: Pathwise_Camelot.toc is a copy of Pathwise_Forever.toc,
-- which is the Vanilla TOC with its interface, its own comments and
-- Platform_Forever.lua after Platform_Classic.lua.
check("Pathwise_Camelot.toc matches Pathwise_Forever.toc", ReadFile("./Pathwise_Camelot.toc") == ReadFile("./Pathwise_Forever.toc"))
local function TocLines(path)
  local lines = {}
  for line in io.lines(path) do
    if line ~= "" and not line:match("^# ") and line ~= "#" and not line:match("^## Interface:")
      and line ~= "Platform\\Platform_Forever.lua" then
      lines[#lines + 1] = line
    end
  end
  return table.concat(lines, "\n")
end
check("Pathwise_Forever.toc lists what Pathwise_Vanilla.toc does", TocLines("./Pathwise_Forever.toc") == TocLines("./Pathwise_Vanilla.toc")
  and ReadFile("./Pathwise_Forever.toc"):find("Platform\\Platform_Classic.lua\r?\nPlatform\\Platform_Forever.lua") ~= nil
  and ReadFile("./Pathwise_Forever.toc"):find("## Interface: 16001", 1, true) == 1)
check("Classic Era: the Classic platform", Pathwise.Platform.flavor == "Classic"
  and select(1, Pathwise.Platform.MapPoint(1453, 0.75, 0.28)) == 0.75)
check("namespace has Platform", Pathwise.Platform ~= nil)
check("slash command bound", SlashCmdList.PATHWISE ~= nil and SLASH_PATHWISE2 == "/pw")

WoW.FireEvent("ADDON_LOADED", "SomeOtherAddon")
check("ignores other addons' ADDON_LOADED", Pathwise.db == nil)
WoW.FireEvent("ADDON_LOADED", "Pathwise")
check("saved variables created", type(PathwiseDB) == "table" and type(PathwiseCharDB) == "table")
check("db defaults applied", Pathwise.db.debug == false and type(Pathwise.db.modules) == "table")

WoW.FireEvent("PLAYER_LOGIN")
WoW.FireEvent("PLAYER_ENTERING_WORLD", true, false)
check("login message printed", WoW.ChatContains("v0.1.0-test loaded"))
check("module error reported", #WoW.errors == 1 and WoW.ChatContains("Error in module BrokenTestModule (OnEnable)"))
check("other modules still enabled", Pathwise:GetModule("Character").enabled == true)

---------------------------------------------------------------------------
section("M0: commands")

WoW.ClearChat()
WoW.Slash("debug")
check("/pw debug enables", Pathwise.db.debug == true and WoW.ChatContains("Debug output enabled"))
WoW.Slash("DEBUG")
check("/pw debug toggles back off", Pathwise.db.debug == false)
WoW.Slash("debug on")
check("/pw debug on", Pathwise.db.debug == true)

WoW.ClearChat()
Pathwise:Debug("hello", 42)
check("debug print visible when on", WoW.ChatContains("[debug] hello 42"))
WoW.Slash("debug off")
WoW.ClearChat()
Pathwise:Debug("hidden")
check("debug print hidden when off", #WoW.chat == 0)

WoW.ClearChat()
WoW.Slash("nonsense")
check("unknown command reported", WoW.ChatContains("Unknown command 'nonsense'"))
check("help listed after unknown command", WoW.ChatContains("/pw debug"))

local nextSteps = _G.PathwiseNextSteps
local wasShown = nextSteps:IsShown()
WoW.Slash("")
check("/pw without args toggles the Next Steps window", nextSteps:IsShown() ~= wasShown)
WoW.Slash("")
check("/pw toggles back", nextSteps:IsShown() == wasShown)

Pathwise.db.debug = true
local dbRef = Pathwise.db
WoW.Slash("reset")
check("/pw reset restores defaults", Pathwise.db.debug == false)
check("/pw reset keeps the same table", Pathwise.db == dbRef and PathwiseDB == dbRef)

---------------------------------------------------------------------------
section("M0: events and callbacks")

local probe = { count = 0 }
function probe:TEST_EVENT(event, a) self.count = self.count + 1; self.last = a end
Pathwise:RegisterEvent("TEST_EVENT", probe)
WoW.FireEvent("TEST_EVENT", "x")
check("event handler called with args", probe.count == 1 and probe.last == "x")
Pathwise:UnregisterEvent("TEST_EVENT", probe)
WoW.FireEvent("TEST_EVENT", "y")
check("unregistered handler not called", probe.count == 1)

Pathwise:RegisterEvent("PLAYER_TALENT_UPDATE", probe, function() end)
check("unknown event does not error", true)
Pathwise:UnregisterEvent("PLAYER_TALENT_UPDATE", probe)

local order = {}
local a, b = {}, {}
Pathwise:RegisterCallback("TEST_CB", a, function(_, name, v) order[#order + 1] = "a" .. v; Pathwise:UnregisterCallback("TEST_CB", b) end)
Pathwise:RegisterCallback("TEST_CB", b, function(_, name, v) order[#order + 1] = "b" .. v end)
Pathwise:FireCallback("TEST_CB", 1)
Pathwise:FireCallback("TEST_CB", 2)
check("callbacks: in order, safe unregister during dispatch", table.concat(order, ",") == "a1,a2")

local reached = false
local bad, good = {}, {}
Pathwise:RegisterCallback("TEST_CB2", bad, function() error("boom") end)
Pathwise:RegisterCallback("TEST_CB2", good, function() reached = true end)
local errorsBefore = #WoW.errors
Pathwise:FireCallback("TEST_CB2")
check("callbacks: a failing handler doesn't stop the others", reached and #WoW.errors == errorsBefore + 1)
table.remove(WoW.errors)
Pathwise:UnregisterCallback("TEST_CB2", bad)
Pathwise:UnregisterCallback("TEST_CB2", good)

---------------------------------------------------------------------------
-- Milestone-specific tests are appended below.
for _, file in ipairs({ "./tests/run_m1.lua", "./tests/run_m2.lua", "./tests/run_m3.lua", "./tests/run_m4.lua", "./tests/run_quests.lua", "./tests/run_arrow.lua", "./tests/run_questie.lua", "./tests/run_macro.lua", "./tests/run_m5_m6.lua", "./tests/run_theme.lua", "./tests/run_window.lua", "./tests/run_target_button.lua", "./tests/run_professions.lua", "./tests/run_pickups.lua", "./tests/run_travel.lua", "./tests/run_flights.lua", "./tests/run_hearth.lua", "./tests/run_features.lua", "./tests/run_pets.lua", "./tests/run_classes.lua", "./tests/run_boats.lua", "./tests/run_classquests.lua", "./tests/run_autoaccept.lua", "./tests/run_dungeons.lua", "./tests/run_ontheway.lua" }) do
  local chunk = assert(loadfile(file))
  chunk(WoW, Pathwise, check, section)
end

section("No unexpected errors")
check("only the intentional BrokenTestModule error was reported", #WoW.errors == 1)
for i = 2, #WoW.errors do
  print("  error: " .. tostring(WoW.errors[i]))
end

-- WoW Forever runs in its own Lua process (fresh globals).
section("WoW Forever")
local interpreter = arg and arg[-1] or "lua5.1"
local forever = io.popen(interpreter .. " tests/run_forever.lua 2>&1")
local foreverOutput = forever:read("*a")
forever:close()
local foreverPassed, foreverFailed = foreverOutput:match("(%d+) passed, (%d+) failed%s*$")
for line in foreverOutput:gmatch("[^\n]+") do
  if not line:match("^%d+ passed, %d+ failed$") then
    print(line)
  end
end
if foreverPassed then
  passed, failed = passed + tonumber(foreverPassed), failed + tonumber(foreverFailed)
else
  check("tests/run_forever.lua ran to the end", false)
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
