local _, Pathwise = ...

-- Window themes (docs/PATHWISE_THEMES.md §3, updated by
-- docs/PATHWISE_THEMES_V2.md, docs/PATHWISE_THEMES_V3.md and
-- docs/PATHWISE_THEMES_V4.md). Plain data, flavor-independent.
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

-- Azure first: it matches the Pathwise logo.
Pathwise.ThemeOrder = {
  "azure",
  "gilded", "tooltip", "moonlit", "brackets",
  "dragonflight", "skyhawk", "ironhorn", "frostfang", "lionheart", "moonwatch", "phoenixcrest",
  "wildwood", "ember",
}
Pathwise.DefaultTheme = "dragonflight"

-- Wildwood seasons: the saved setting ("auto" follows the month).
Pathwise.WildwoodSeasons = { "summer", "autumn", "auto" }
Pathwise.AutumnMonths = { [9] = true, [10] = true, [11] = true }

-- v3 emblem art: every emblem head and gem shares the same placement.
-- (Adjust these numbers if they sit off in game, never the textures.)
local EMBLEM = { w = 60, h = 60, ax = 20.4, ay = 24 } -- head: frame corner sits at (20.4, 24) inside the texture
local GEM    = { w = 24, h = 24, ax = 12,   ay = 12 } -- gem: centered on the corner

-- (emblem = true: UI/Theme.lua gives emblem themes a 48 px header.)
local function Emblem(file) return { file = file, w = EMBLEM.w, h = EMBLEM.h, ax = EMBLEM.ax, ay = EMBLEM.ay, emblem = true } end
local function Gem(file)    return { file = file, w = GEM.w,    h = GEM.h,    ax = GEM.ax,    ay = GEM.ay    } end

Pathwise.Themes = {
  -- v4: deep blue enamel, rune bands of antique gold, gem corners and a
  -- compass crest. tiled = true: the border is built from tiled textures
  -- (UI/Theme.lua, "tiled frame") instead of a backdrop and corner art.
  -- (Adjust the numbers in azure if something sits off, never the textures.)
  azure = {
    name = "Azure",
    tiled = true,
    bg = "#0a2a56", bgAlpha = 1,    -- only the settings swatch; the window uses azure_bg
    frame = "#a37a38", frameWidth = 0,
    trim = nil, band = nil,
    divider = "#a37a38", dividerAlpha = 1, dividerGem = "azure_gem",
    label = "#9cc4ee",              -- the small "PATHWISE" text
    title = "#e0bf74", muted = "#9cb4d4", text = "#c6d6ea",
    ornament = "#2a6cc0",
    highlight = "fillbar",          -- fill plus a 2 px bar on the left
    highlightColor = "#6eaaf0", highlightAlpha = 0.14, highlightBar = "#a37a38",
    closeInset = 30,
    gripOffset = { -12, 22 },       -- resize grip inside the window, above the corner gem
    azure = {
      edgeH = "azure_edge_h", edgeV = "azure_edge_v", band = 12,
      corner = "azure_corner", cornerSize = 30,
      crest = "azure_crest", crestSize = 36, crestOffsetY = -3,
      bgTex = "azure_bg",
      gloss = "azure_gloss", glossHeight = 84, glossInset = 12,
    },
  },
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
  -- v2/v3: painted, full-color corner art. cornerArt.top goes on the top
  -- corners, .bottom on the bottom ones; ax, ay = the spot in the art (UI
  -- units from its top-left edge) that sits on the window's outer corner.
  -- v3 emblem themes (docs/PATHWISE_THEMES_V3.md):
  dragonflight = {
    name = "Dragonflight",
    bg = "#1a0d0d", bgAlpha = 0.95, frame = "#9b2020", frameWidth = 3,
    trim = "#e0b04a", trimAlpha = 1, trimInset = 5, band = "#2a1010", divider = "#e0b04a", dividerAlpha = 1,
    title = "#ecc56a", muted = "#b59a7a", text = "#d6c6ba", ornament = "#e0b04a",
    highlight = "fill", highlightColor = "#e0b04a", highlightAlpha = 0.12,
    closeInset = 36,
    cornerArt = { top = Emblem("dragon_emblem"), bottom = Gem("gem_emblem_ruby") },
  },
  skyhawk = {
    name = "Skyhawk",
    bg = "#0d1426", bgAlpha = 0.95, frame = "#2f5fb3", frameWidth = 3,
    trim = "#d9b45a", trimAlpha = 1, trimInset = 5, band = "#15224a", divider = "#d9b45a", dividerAlpha = 1,
    title = "#f0d58a", muted = "#a9b4d6", text = "#c3cbe0", ornament = "#e3c06a",
    highlight = "fill", highlightColor = "#2f5fb3", highlightAlpha = 0.25,
    closeInset = 36,
    cornerArt = { top = Emblem("eagle_emblem"), bottom = Gem("gem_emblem_sapphire") },
  },
  ironhorn = {
    name = "Ironhorn",
    bg = "#1a120c", bgAlpha = 0.95, frame = "#7a4420", frameWidth = 3,
    trim = "#e0b04a", trimAlpha = 1, trimInset = 5, band = "#2a1a10", divider = "#e0b04a", dividerAlpha = 1,
    title = "#f0c878", muted = "#b89a7c", text = "#dccab6", ornament = "#e0b04a",
    highlight = "fill", highlightColor = "#e08c3c", highlightAlpha = 0.14,
    closeInset = 36,
    cornerArt = { top = Emblem("bull_emblem"), bottom = Gem("gem_emblem_topaz") },
  },
  frostfang = {
    name = "Frostfang",
    bg = "#0e141a", bgAlpha = 0.95, frame = "#4a5e72", frameWidth = 3,
    trim = "#b8c6d4", trimAlpha = 1, trimInset = 5, band = "#18222c", divider = "#b8c6d4", dividerAlpha = 1,
    title = "#e2ecf4", muted = "#9aaabb", text = "#c4d0dc", ornament = "#c8d0da",
    highlight = "fill", highlightColor = "#8cc8f0", highlightAlpha = 0.14,
    closeInset = 36,
    cornerArt = { top = Emblem("wolf_emblem"), bottom = Gem("gem_emblem_ice") },
  },
  lionheart = {
    name = "Lionheart",
    bg = "#160e1e", bgAlpha = 0.95, frame = "#5a2e7a", frameWidth = 3,
    trim = "#e0b04a", trimAlpha = 1, trimInset = 5, band = "#24162e", divider = "#e0b04a", dividerAlpha = 1,
    title = "#f0d58a", muted = "#b4a2c4", text = "#d2c8dc", ornament = "#e0b04a",
    highlight = "fill", highlightColor = "#a064dc", highlightAlpha = 0.18,
    closeInset = 36,
    cornerArt = { top = Emblem("lion_emblem"), bottom = Gem("gem_emblem_amethyst") },
  },
  moonwatch = {
    name = "Moonwatch",
    bg = "#0c1618", bgAlpha = 0.95, frame = "#2c6266", frameWidth = 3,
    trim = "#b8c6d4", trimAlpha = 1, trimInset = 5, band = "#142426", divider = "#b8c6d4", dividerAlpha = 1,
    title = "#dff2f0", muted = "#96b4b2", text = "#c2d6d4", ornament = "#c8d0da",
    highlight = "fill", highlightColor = "#50aaaa", highlightAlpha = 0.18,
    closeInset = 36,
    cornerArt = { top = Emblem("owl_emblem"), bottom = Gem("gem_emblem_moonstone") },
  },
  phoenixcrest = {
    name = "Phoenix Crest",
    bg = "#1c0f08", bgAlpha = 0.95, frame = "#d9622b", frameWidth = 3,
    trim = "#ffcf6b", trimAlpha = 1, trimInset = 5, band = "#2c160a", divider = "#ffcf6b", dividerAlpha = 1,
    title = "#ffcf6b", muted = "#c9a585", text = "#e0cbb8", ornament = "#f8a23e",
    highlight = "fill", highlightColor = "#d9622b", highlightAlpha = 0.18,
    closeInset = 36,
    cornerArt = { top = Emblem("phoenix_emblem"), bottom = Gem("gem_emblem_ember") },
  },
  -- v2 themes, unchanged in v3:
  wildwood = {
    name = "Wildwood",
    bg = "#0d1a14", bgAlpha = 0.95,
    frame = "#4a3220", frameWidth = 5,              -- dark wood
    trim = "#6f8f3a", trimAlpha = 0.6, trimInset = 7, -- moss line
    band = "#13281e",
    divider = "#6f8f3a", dividerAlpha = 1,
    title = "#eadfc4", muted = "#a9bf9c", text = "#c6d3bd",
    ornament = "#6f8f3a",
    highlight = "fill", highlightColor = "#6f8f3a", highlightAlpha = 0.18,
    seasonal = true,   -- art file names get "_summer" / "_autumn" appended
    cornerArt = {
      top    = { file = "wildwood_top",    w = 110, h = 110, ax = 27.5, ay = 27.5 },
      bottom = { file = "wildwood_bottom", w = 110, h = 110, ax = 27.5, ay = 27.5 },
    },
  },
  ember = {
    name = "Phoenix Ember",
    bg = "#1c0f08", bgAlpha = 0.95,
    frame = "#d9622b", frameWidth = 3,
    trim = "#ffcf6b", trimAlpha = 1, trimInset = 5,
    band = "#2c160a",
    divider = "#ffcf6b", dividerAlpha = 1,
    title = "#ffcf6b", muted = "#c9a585", text = "#e0cbb8",
    ornament = "#ffcf6b",
    highlight = "fill", highlightColor = "#d9622b", highlightAlpha = 0.18,
    cornerArt = {
      top    = { file = "phoenix_feathers", w = 90, h = 90, ax = 45, ay = 45 },
      bottom = { file = "phoenix_feathers", w = 90, h = 90, ax = 45, ay = 45 },
    },
  },
}
