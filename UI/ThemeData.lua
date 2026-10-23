local _, Pathwise = ...

-- Window themes (docs/PATHWISE_THEMES.md §3). Plain data, flavor-independent.
-- Colors are hex strings; UI/Theme.lua turns them into r, g, b with
-- Pathwise.HexToRGB.

-- "#c9a24a" -> 0.788, 0.635, 0.290 (0-1), plus alpha (default 1).
function Pathwise.HexToRGB(hex, alpha)
  hex = hex:gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  return r, g, b, alpha or 1
end

Pathwise.ThemeOrder = { "gilded", "tooltip", "moonlit", "brackets", "dragonflight", "skyhawk", "wildwood", "ember" }
Pathwise.DefaultTheme = "dragonflight"

Pathwise.Themes = {
  gilded = {
    name = "Gilded Hairline",
    bg = "#120f0b", bgAlpha = 0.95,
    frame = "#c9a24a", frameWidth = 1,
    trim = "#c9a24a", trimAlpha = 0.30, trimInset = 4,
    band = nil,                     -- no separate band, header sits on bg
    divider = "#c9a24a", dividerAlpha = 0.35, dividerStyle = "diamond",
    title = "#e3bd62", muted = "#9a8f78", text = "#c9c0ae",
    ornament = "#c9a24a", corners = "diamonds",
    highlight = "fill", highlightColor = "#c9a24a", highlightAlpha = 0.10,
  },
  tooltip = {
    name = "Classic Tooltip",
    useTooltipArt = true,           -- bgFile "Interface\\Tooltips\\UI-Tooltip-Background",
                                    -- edgeFile "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize 16, insets 4
    bg = "#0b0d1a", bgAlpha = 0.92,
    frame = "#9a9aa3", frameWidth = 16,
    trim = nil,
    band = nil,
    divider = "#2c2e3a", dividerAlpha = 1,
    title = "#ffd100", muted = "#a3a3ad", text = "#c9c9d1",
    ornament = "#9a9aa3", corners = "none",
    highlight = "fill", highlightColor = "#ffd100", highlightAlpha = 0.08,
    titleText = "Pathwise · To-do", -- single-line header in this theme
  },
  moonlit = {
    name = "Moonlit",
    bg = "#12111c", bgAlpha = 0.95,
    frame = "#6f6aa8", frameWidth = 1,
    trim = nil,
    band = "#171528",
    divider = "#6f6aa8", dividerAlpha = 1,
    title = "#e4e2f7", muted = "#9c98c2", text = "#b9b6d3",
    ornament = "#c9c6ea", corners = "none", headerIcon = "crescent",
    highlight = "fill", highlightColor = "#1e1c30", highlightAlpha = 1,
  },
  brackets = {
    name = "Corner Brackets",
    bg = "#0a0a0a", bgAlpha = 0.86,
    frame = nil, frameWidth = 0,    -- no border at all
    trim = nil,
    band = nil,
    divider = nil,
    title = "#c9a24a", muted = "#9a9a9a", text = "#bdbdbd",
    ornament = "#c9a24a", corners = "brackets",
    highlight = "bar",
  },
  dragonflight = {
    name = "Dragonflight",
    bg = "#1a0d0d", bgAlpha = 0.95,
    frame = "#9b2020", frameWidth = 3,
    trim = "#e0b04a", trimAlpha = 1, trimInset = 5,
    band = "#2a1010",
    divider = "#e0b04a", dividerAlpha = 1,
    title = "#ecc56a", muted = "#b59a7a", text = "#d6c6ba",
    ornament = "#e0b04a", corners = "dragon",
    highlight = "fill", highlightColor = "#e0b04a", highlightAlpha = 0.12,
  },
  skyhawk = {
    name = "Skyhawk",
    bg = "#0d1426", bgAlpha = 0.95,
    frame = "#2f5fb3", frameWidth = 3,
    trim = "#d9b45a", trimAlpha = 1, trimInset = 5,
    band = "#15224a",
    divider = "#d9b45a", dividerAlpha = 1,
    title = "#f0d58a", muted = "#a9b4d6", text = "#c3cbe0",
    ornament = "#e3c06a", corners = "eagle",
    highlight = "fill", highlightColor = "#2f5fb3", highlightAlpha = 0.25,
  },
  wildwood = {
    name = "Wildwood",
    bg = "#0d1a14", bgAlpha = 0.95,
    frame = "#2f8a5f", frameWidth = 3,
    trim = "#a8d8b9", trimAlpha = 1, trimInset = 5,
    band = "#13281e",
    divider = "#a8d8b9", dividerAlpha = 1,
    title = "#c9f0d6", muted = "#9cc2aa", text = "#bcd6c6",
    ornament = "#b8e6c8", corners = "antlers",
    highlight = "fill", highlightColor = "#2f8a5f", highlightAlpha = 0.22,
  },
  ember = {
    name = "Phoenix Ember",
    bg = "#1c0f08", bgAlpha = 0.95,
    frame = "#d9622b", frameWidth = 3,
    trim = "#ffcf6b", trimAlpha = 1, trimInset = 5,
    band = "#2c160a",
    divider = "#ffcf6b", dividerAlpha = 1,
    title = "#ffcf6b", muted = "#c9a585", text = "#e0cbb8",
    ornament = "#ffcf6b", corners = "feathers",
    highlight = "fill", highlightColor = "#d9622b", highlightAlpha = 0.18,
  },
}
