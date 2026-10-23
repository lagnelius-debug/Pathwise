-- Window themes (docs/PATHWISE_THEMES.md), applied to the To-do window.
local WoW, Pathwise, check, section = ...

local Theme = Pathwise.Theme
local window = _G.PathwiseNextSteps

local function Near(a, b) return math.abs(a - b) < 1e-6 end

local function Point(texture)
  return texture._points and texture._points[1] or {}
end

local function Coords(texture)
  return table.concat(texture._texcoord or {}, ",")
end

local function Corner(name)
  return window.corners[name]
end

local function Tex(texture)
  return (texture._texture or ""):match("([^\\]+)$")
end

local function Color(texture, hex)
  local r, g, b = Pathwise.HexToRGB(hex)
  local c = texture._color or {}
  return c[1] and Near(c[1], r) and Near(c[2], g) and Near(c[3], b)
end

local function AnyCornerShown()
  for _, slots in pairs(window.corners) do
    for _, texture in pairs(slots) do
      if texture:IsShown() then return true end
    end
  end
  return false
end

---------------------------------------------------------------------------
section("Themes: data and registry")

check("8 themes in order", #Pathwise.ThemeOrder == 8 and Pathwise.ThemeOrder[5] == "dragonflight")
for _, id in ipairs(Pathwise.ThemeOrder) do
  check("theme has a name and colors: " .. id, Pathwise.Themes[id].name and Pathwise.Themes[id].bg and Pathwise.Themes[id].text)
end
local r, g, b, a = Pathwise.HexToRGB("#c9a24a", 0.3)
check("HexToRGB", Near(r, 0xc9 / 255) and Near(g, 0xa2 / 255) and Near(b, 0x4a / 255) and a == 0.3)
check("default theme", Pathwise.db.theme == "dragonflight" and Theme.GetActiveId() == "dragonflight")
Pathwise.db.theme = "nope"
check("unknown saved id falls back to the default", Theme.GetActiveId() == "dragonflight"
  and Theme.Get("nope") == Pathwise.Themes.dragonflight)
Pathwise.db.theme = "dragonflight"
check("Get by number", Theme.Get(7) == Pathwise.Themes.wildwood)

-------------------------------------------------------------------------------------------------------------------------------------------------
section("Themes: Dragonflight on the To-do window")

local function Art(texture, file, w, point, x, y, coords)
  local p = Point(texture)
  return texture:IsShown() and Tex(texture) == file and texture._width == w and texture._height == w
    and p[1] == point and p[2] == window and p[3] == point and p[4] == x and p[5] == y
    and Coords(texture) == coords and Color(texture, "#ffffff")
end

Theme.SetActive("dragonflight")
check("window skinned", window.themeId == "dragonflight")
check("label and title", window.label:GetText() == "PATHWISE" and window.title:GetText() == "To-do"
  and window.label:IsShown())
check("header 52 px with a band", window.headerHeight == 52 and window.header:IsShown())
check("outer border 3 px, frame color", window._backdrop.edgeSize == 3
  and Near(window._borderColor[1], 0x9b / 255))
check("trim line 5 px inside", window.trim:IsShown() and Point(window.trim)[4] == 5)
check("dragon head top-left: 110x110, anchor (35, 33), untinted",
  Art(Corner("TOPLEFT").art, "dragon_head", 110, "TOPLEFT", -35, 33, "0,1,0,1"))
check("dragon head top-right: mirrored, facing outward",
  Art(Corner("TOPRIGHT").art, "dragon_head", 110, "TOPRIGHT", 35, 33, "1,0,0,1"))
check("ruby bottom-left: centered on the corner, flipped V",
  Art(Corner("BOTTOMLEFT").art, "gem_ruby", 36, "BOTTOMLEFT", -18, -18, "0,1,1,0"))
check("ruby bottom-right: flipped both",
  Art(Corner("BOTTOMRIGHT").art, "gem_ruby", 36, "BOTTOMRIGHT", 18, -18, "1,0,1,0"))
check("close button 46 px from the right edge", Point(window.close)[1] == "RIGHT" and Point(window.close)[4] == -46)
check("close button above the corner art", window.close:GetFrameLevel() > window.ornaments:GetFrameLevel())
check("ornaments above the border", window.ornaments:GetFrameLevel() == window:GetFrameLevel() + 5)

---------------------------------------------------------------------------
section("Themes: /pw theme")

WoW.ClearChat()
WoW.Slash("theme")
check("list with numbers and the active one", WoW.ChatContains("Pathwise themes: 1 Gilded Hairline, 2 Classic Tooltip, "
  .. "3 Moonlit, 4 Corner Brackets, 5 Dragonflight (active), 6 Skyhawk, 7 Wildwood, 8 Phoenix Ember"))

WoW.Slash("theme skyhawk")
check("skyhawk: eagle heads, sapphires, close at 50",
  Art(Corner("TOPRIGHT").art, "eagle_head", 110, "TOPRIGHT", 40, 35, "1,0,0,1")
  and Art(Corner("BOTTOMLEFT").art, "gem_sapphire", 36, "BOTTOMLEFT", -18, -18, "0,1,1,0")
  and Point(window.close)[4] == -50)

WoW.ClearChat()
WoW.Slash("theme 7")
check("/pw theme 7", WoW.ChatContains("Theme: Wildwood") and Pathwise.db.theme == "wildwood" and window.themeId == "wildwood")
check("wildwood: summer branches by default",
  Art(Corner("TOPLEFT").art, "wildwood_top_summer", 110, "TOPLEFT", -27.5, 27.5, "0,1,0,1")
  and Art(Corner("BOTTOMRIGHT").art, "wildwood_bottom_summer", 110, "BOTTOMRIGHT", 27.5, -27.5, "1,0,1,0"))
check("wildwood: 5 px wood border, moss trim 7 px in", window._backdrop.edgeSize == 5 and Point(window.trim)[4] == 7)
check("close button 30 px in (default with corner art)", Point(window.close)[4] == -30)

WoW.Slash("theme next")
check("/pw theme next -> Phoenix Ember", Pathwise.db.theme == "ember")
local corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local expected = { "0,1,0,1", "1,0,0,1", "0,1,1,0", "1,0,1,0" }
local signs = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
for i, name in ipairs(corners) do
  check("feathers fan out from " .. name, Art(Corner(name).art, "phoenix_feathers", 90, name,
    signs[i][1] * 45, signs[i][2] * 45, expected[i]))
end

WoW.Slash("theme next")
check("cycles around to Gilded Hairline", Pathwise.db.theme == "gilded")
check("gilded: diamonds, divider diamond, no band", Tex(Corner("BOTTOMRIGHT").art) == "diamond"
  and Corner("BOTTOMRIGHT").art._width == 10 and window.dividerGem:IsShown() and not window.header:IsShown()
  and window.headerHeight == 44)
check("gilded: diamonds tinted again after the painted art", Color(Corner("TOPLEFT").art, "#c9a24a"))
check("plain themes: close button near the edge as before", Point(window.close)[4] == -6)

WoW.Slash("theme tooltip")
check("tooltip theme: Blizzard tooltip art", window._backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border"
  and window._backdrop.edgeSize == 16)
check("tooltip theme: single-line title", window.title:GetText() == "Pathwise · To-do" and not window.label:IsShown())
check("tooltip theme: no ornaments", not AnyCornerShown() and not window.trim:IsShown())

WoW.Slash("theme moonlit")
check("moonlit: crescent left of the title", window.headerIcon:IsShown() and Tex(window.headerIcon) == "crescent"
  and window.header:IsShown())

WoW.Slash("theme 4")
check("brackets: L-lines in the corners, no border", Corner("TOPLEFT").lineH:IsShown() and Corner("TOPLEFT").lineV:IsShown()
  and Corner("TOPLEFT").lineH._width == 16 and Corner("TOPLEFT").lineV._height == 16
  and window._backdrop.edgeFile == nil and not window.divider:IsShown() and not Corner("TOPLEFT").art:IsShown())

WoW.ClearChat()
WoW.Slash("theme banana")
check("unknown theme", WoW.ChatContains("Unknown theme 'banana'.") and Pathwise.db.theme == "brackets")

---------------------------------------------------------------------------
section("Themes: Wildwood seasons")

WoW.Slash("theme wildwood")
WoW.ClearChat()
WoW.Slash("season autumn")
check("/pw season autumn: saved, re-skinned, printed", Pathwise.db.wildwoodSeason == "autumn"
  and Tex(Corner("TOPLEFT").art) == "wildwood_top_autumn" and Tex(Corner("BOTTOMLEFT").art) == "wildwood_bottom_autumn"
  and WoW.ChatContains("Wildwood season: Autumn"))
local realDate = date
date = function() return { month = 10 } end
WoW.ClearChat()
WoW.Slash("season auto")
check("auto in October: autumn", Pathwise.db.wildwoodSeason == "auto" and Theme.GetSeason() == "autumn"
  and Tex(Corner("TOPRIGHT").art) == "wildwood_top_autumn" and WoW.ChatContains("Wildwood season: Auto (now Autumn)"))
date = function() return { month = 6 } end
Theme.Apply(window)
check("auto in June: summer (checked when applied)", Tex(Corner("TOPRIGHT").art) == "wildwood_top_summer")
date = function() return { month = 12 } end
check("auto in December: summer", Theme.GetSeason() == "summer")
date = realDate
Pathwise.db.wildwoodSeason = "winter"
check("unknown saved season -> summer", Theme.GetSeasonSetting() == "summer" and Theme.GetSeason() == "summer")
WoW.ClearChat()
WoW.Slash("season spring")
check("unknown season: usage", WoW.ChatContains("Usage: /pw season") and Pathwise.db.wildwoodSeason == "winter")
WoW.Slash("season summer")
check("/pw season summer", Pathwise.db.wildwoodSeason == "summer" and Tex(Corner("TOPLEFT").art) == "wildwood_top_summer")
WoW.Slash("theme 4") -- the highlight tests below use Corner Brackets

---------------------------------------------------------------------------
section("Themes: current step highlight")

-- (Window hidden, so a re-render doesn't replace this hand-set highlight.)
local NextStepsFrame = Pathwise:GetModule("NextStepsFrame")
NextStepsFrame:SetShown(false)
local rowA = CreateFrame("Frame", nil, window.content)
window:SetHighlightRow(rowA)
check("brackets: accent bar", window.highlightBar:IsShown() and not window.highlightFill:IsShown()
  and window.highlightBar._width == 3)
WoW.Slash("theme dragonflight")
check("fill themes: tinted row background", window.highlightFill:IsShown() and not window.highlightBar:IsShown())
window:SetHighlightRow(nil)
check("no current step: no highlight", not window.highlightFill:IsShown() and not window.highlightBar:IsShown())
NextStepsFrame:SetShown(true)

---------------------------------------------------------------------------
section("Themes: switching creates no textures")

local before = WoW.textureCount
for _ = 1, 24 do
  WoW.Slash("theme next")
end
check("cycling 24 times creates no new textures", WoW.textureCount == before)
check("back on the same theme after 3 full cycles", Pathwise.db.theme == "dragonflight")

---------------------------------------------------------------------------
section("Themes: quest colors")

check("Core fallback yellow is #ffd100", Theme.RecolorQuestNames("|cffffd100[5] Webwood Venom|r") == "|cffffd100[5] Webwood Venom|r")
GetQuestDifficultyColor = function(level) return { r = 1, g = 0.5, b = 0.25 } end
check("WoW's difficulty colors when available", Theme.RecolorQuestNames("Do: |cffffd100[5] Webwood Venom|r - 40 yd")
  == "Do: |cffff7f3f[5] Webwood Venom|r - 40 yd")
check("other colored text untouched", Theme.RecolorQuestNames("|cff99e6ffKill Timberling|r") == "|cff99e6ffKill Timberling|r")
GetQuestDifficultyColor = nil

---------------------------------------------------------------------------
section("Themes: settings panel")

local panel = _G.PathwiseSettingsPanel
local buttons = {}
for _, f in ipairs(WoW.frames) do
  if f.themeId and f._parent == panel then buttons[#buttons + 1] = f end
end
check("Appearance: 8 theme buttons", #buttons == 8 and buttons[1].themeId == "gilded" and buttons[8].themeId == "ember")
check("button shows number and name", buttons[3].name:GetText() == "3  Moonlit")
buttons[3]:Click()
check("clicking a button applies the theme", Pathwise.db.theme == "moonlit" and window.themeId == "moonlit")
local gold = { Pathwise.HexToRGB("#ffd100") }
check("active theme outlined in gold", Near(buttons[3]._borderColor[1], gold[1]) and Near(buttons[3]._borderColor[2], gold[2])
  and not Near(buttons[5]._borderColor[1], gold[1]))
WoW.Slash("theme 5")
check("outline follows /pw theme", Near(buttons[5]._borderColor[1], gold[1]) and not Near(buttons[3]._borderColor[1], gold[1]))

local seasonButtons = {}
for _, f in ipairs(WoW.frames) do
  if f.season and f._parent == panel then seasonButtons[#seasonButtons + 1] = f end
end
check("season choice: Summer / Autumn / Auto", #seasonButtons == 3 and seasonButtons[1].name:GetText() == "Summer"
  and seasonButtons[3].name:GetText() == "Auto")
check("season choice hidden for other themes", not seasonButtons[1]:IsShown() and not panel.seasonHeader:IsShown())
WoW.Slash("theme wildwood")
check("season choice shown while Wildwood is active", seasonButtons[1]:IsShown() and panel.seasonHeader:IsShown())
seasonButtons[2]:Click()
check("clicking Autumn applies it", Pathwise.db.wildwoodSeason == "autumn" and Tex(Corner("TOPLEFT").art) == "wildwood_top_autumn"
  and Near(seasonButtons[2]._borderColor[1], gold[1]) and not Near(seasonButtons[1]._borderColor[1], gold[1]))
WoW.Slash("season summer")
check("outline follows /pw season", Near(seasonButtons[1]._borderColor[1], gold[1]))

-- /pw reset brings back the default theme
WoW.Slash("theme 2")
WoW.Slash("reset")
check("/pw reset: default theme, window re-skinned", Pathwise.db.theme == "dragonflight" and window.themeId == "dragonflight")
