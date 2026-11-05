-- Bug report (/pw bug): Core/BugReport.lua and UI/BugReportFrame.lua.
local WoW, Pathwise, check, section = ...
local S = WoW.state

section("Bug report")

-- An error caught by Pathwise is kept for the report (and still goes on to
-- WoW's error handler).
local errorsBefore = #WoW.errors
Pathwise.Platform.SafeCall(function() error("test failure in a module") end)
check("a caught error still reaches WoW's handler", #WoW.errors == errorsBefore + 1)
table.remove(WoW.errors)

WoW.Slash("bug")
local frame = _G.PathwiseBugReport
local report = Pathwise:GetModule("BugReportFrame"):GetReportText()
check("/pw bug opens the window", frame ~= nil and frame:IsShown())
check("the GitHub link in its box", _G.PathwiseBugReportLink:GetText()
  == "https://github.com/lagnelius-debug/Pathwise/issues/new?template=bug_report.yml")
check("the report in its box", _G.PathwiseBugReportText:GetText() == report)
check("versions and game", report:find("^Pathwise 0%.1%.0%-test on Classic\n") ~= nil
  and report:find("Client 1.15.9 (build 99999, interface 11509", 1, true) ~= nil)
check("character and place", report:find("Character: level " .. S.level, 1, true) ~= nil
  and report:find("Where: ", 1, true) ~= nil and report:find("Mode: normal", 1, true) ~= nil)
check("the To-do steps, without color codes", report:find("To-do (", 1, true) ~= nil and not report:find("|c", 1, true))
check("the last error, with its message", report:find("Recent errors (", 1, true) ~= nil
  and report:find("test failure in a module", 1, true) ~= nil)

-- Typing can't change it; clicking selects it again.
local box = _G.PathwiseBugReportText
box._text = "something else"
box._scripts.OnTextChanged(box, true)
check("read-only: typing puts the report back", box:GetText() == report)
box._scripts.OnEscapePressed(box)
check("Escape closes the window", not frame:IsShown())

-- Also from the settings window and the minimap button (Shift-click).
_G.PathwiseSettingsBugReport:Click()
check("the settings window's \"Report a problem\" button opens it", frame:IsShown())
frame:Hide()
local minimapButton = _G.PathwiseMinimapButton
IsShiftKeyDown = function() return true end
minimapButton._scripts.OnClick(minimapButton, "LeftButton")
check("Shift-click on the minimap button opens it", frame:IsShown())
frame:Hide()
IsShiftKeyDown = function() return false end
minimapButton._scripts.OnClick(minimapButton, "LeftButton")
check("a plain click still toggles the To-do window, not the report", not frame:IsShown())
minimapButton._scripts.OnClick(minimapButton, "LeftButton")
IsShiftKeyDown = nil

-- Only the last 5 errors are kept.
for i = 1, 7 do
  Pathwise.Platform.SafeCall(function() error("error " .. i) end)
  table.remove(WoW.errors)
end
local kept = Pathwise.Platform.GetRecentErrors()
check("the last 5 errors kept", #kept == 5 and kept[5].message:find("error 7", 1, true) ~= nil
  and kept[1].message:find("error 3", 1, true) ~= nil)
