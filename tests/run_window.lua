-- Resizable To-do window, minimap button, toggle key binding.
local WoW, Pathwise, check, section = ...

local window = _G.PathwiseNextSteps
local NextStepsFrame = Pathwise:GetModule("NextStepsFrame")
local saved = Pathwise.db.nextSteps

local function Near(a, b) return math.abs(a - b) < 1e-6 end

local function VisibleRows()
  local rows = {}
  for _, f in ipairs(WoW.frames) do
    if f.text and f._parent == window.content and f._shown then rows[#rows + 1] = f end
  end
  return rows
end

-- Enough steps to overflow a small window
local quests = { { header = true, title = "Teldrassil" } }
for i = 1, 10 do
  quests[#quests + 1] = { title = "Quest number " .. i .. " with a fairly long title to test the dots",
    level = 5, questID = 7000 + i, objectives = { { text = "Thing: 0/5" } } }
end
WoW.questLog = quests
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
NextStepsFrame:SetShown(true)

---------------------------------------------------------------------------
section("Window: one line per row")

local rows = VisibleRows()
check("rows don't wrap (text ends in dots instead)", rows[1].text._wordWrap == false and rows[1].text._height == 16)

---------------------------------------------------------------------------
section("Window: resizing")

check("size grip exists", window.grip ~= nil)
window.grip._scripts.OnMouseDown(window.grip, "LeftButton")
window:SetSize(260, window:ChromeHeight() + 5 * 16)
window._scripts.OnSizeChanged(window)
check("live: rows fit the new height", #VisibleRows() == 5)
check("overflow summarised", VisibleRows()[5].text:GetText():find("... and", 1, true) ~= nil)
window.grip._scripts.OnMouseUp(window.grip, "LeftButton")
check("size saved", saved.width == 260 and saved.height == window:ChromeHeight() + 5 * 16)
check("height stays fixed when steps change", (function()
  WoW.FireEvent("QUEST_LOG_UPDATE")
  WoW.RunTimers()
  return window:GetHeight() == saved.height and #VisibleRows() == 5
end)())

window.grip._scripts.OnMouseUp(window.grip, "RightButton")
check("right-click: automatic height again", saved.height == nil and window.fixedHeight == nil
  and #VisibleRows() > 5)
check("width kept", saved.width == 260)
check("footer text stops at the path button", window.footer.text._wordWrap == false)

-- Only the current step's detail lines cut off: "..." instead of "and 0 more"
local GetItems = Pathwise:GetModule("NextSteps").GetItems
Pathwise:GetModule("NextSteps").GetItems = function()
  return { { id = "x", text = "Do: Only step", subLines = {
    { text = "a", level = 1 }, { text = "b", level = 1 }, { text = "c", level = 1 },
    { text = "d", level = 1 }, { text = "e", level = 1 }, { text = "f", level = 1 } } } }
end
window.fixedHeight = window:ChromeHeight() + 4 * 16
NextStepsFrame:Render()
local visible = VisibleRows()
check("only details cut: last row is '...'", #visible == 4 and visible[4].text:GetText() == "...")
Pathwise:GetModule("NextSteps").GetItems = GetItems
window.fixedHeight = nil
NextStepsFrame:Render()

---------------------------------------------------------------------------
section("Window: minimap button")

local button = _G.PathwiseMinimapButton
check("minimap button created and shown", button ~= nil and button:IsShown())
local p = button._points[1]
check("placed on the minimap edge at 225 degrees", p[1] == "CENTER" and Near(p[4], math.cos(math.rad(225)) * 80)
  and Near(p[5], math.sin(math.rad(225)) * 80))

local wasShown = window:IsShown()
button._scripts.OnClick(button, "LeftButton")
check("left-click toggles the To-do window", window:IsShown() ~= wasShown)
button._scripts.OnClick(button, "LeftButton")
check("left-click again toggles back", window:IsShown() == wasShown)

-- Drag to the top of the minimap
button._scripts.OnDragStart(button)
WoW.mouse = { 1000, 900 }
button._scripts.OnUpdate(button, 0.1)
button._scripts.OnDragStop(button)
check("drag moves it around the edge", Near(Pathwise.db.minimap.angle, 90) and button._scripts.OnUpdate == nil)

WoW.ClearChat()
WoW.Slash("minimap")
check("/pw minimap hides it", not button:IsShown() and Pathwise.db.minimap.hide == true
  and WoW.ChatContains("Type /pw minimap to show it again"))
local checkbox = _G.PathwiseSettingsMinimap
check("settings checkbox follows", checkbox:GetChecked() == false)
checkbox:SetChecked(true)
checkbox._scripts.OnClick(checkbox)
check("settings checkbox shows it", button:IsShown() and Pathwise.db.minimap.hide == false)

WoW.Slash("minimap")
check("hidden again", not button:IsShown())
WoW.Slash("reset")
check("/pw reset shows it and the checkbox follows", button:IsShown() and checkbox:GetChecked() == true)
check("/pw reset: default window width", window:GetWidth() == Pathwise.Theme.DEFAULT_WIDTH)

---------------------------------------------------------------------------
section("Window: key binding")

wasShown = window:IsShown()
PathwiseBinding_Toggle()
check("toggle binding", window:IsShown() ~= wasShown)
PathwiseBinding_Toggle()

WoW.questLog = {}
WoW.FireEvent("QUEST_LOG_UPDATE")
WoW.RunTimers()
