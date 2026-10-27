local addonName, Pathwise = ...

-- Theme system (docs/PATHWISE_THEMES.md): a registry of window themes, a
-- skinning function, and live switching. Every Pathwise window made with
-- Theme.CreateWindow is re-skinned immediately when the theme changes.
--
-- Window anatomy: backdrop (background + outer border), inner trim line,
-- header band with a small "PATHWISE" label and the title, a divider, the
-- content area, a footer, and corner ornaments on a higher frame level so
-- they draw over the border (and partly outside the window).
-- Ornaments are either simple tinted shapes (diamonds, brackets) or, since
-- docs/PATHWISE_THEMES_V2.md, painted full-color corner art (cornerArt).
-- Since docs/PATHWISE_THEMES_V4.md a theme can instead have a "tiled frame"
-- (theme.tiled, Azure): a textured background with a shine, border bands
-- that repeat along the edges, corner plates and a crest on the top edge.
--
-- All ornament textures are created once per window in CreateWindow; Apply
-- only shows/hides, tints and re-anchors them.

local L = Pathwise.L

local Theme = {}
Pathwise.Theme = Theme

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\Themes\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"

local WIDTH = 340
Theme.DEFAULT_WIDTH = WIDTH
local HEADER_CREATURE = 52 -- title centered, corner art on the top corners
local HEADER_EMBLEM = 48   -- v3 emblem themes: same layout, smaller art
local HEADER_PLAIN = 44    -- title left-aligned
local HEADER_TILED = 60    -- v4 tiled frame: band, 22 px padding, label, title
local SIDE_PADDING = 14
local CREATURE_PADDING = 40 -- keeps the centered title clear of the corner art
local CONTENT_GAP = 8
local FOOTER_HEIGHT = 18
local BOTTOM_PADDING = 10

-- Close button distance from the right edge (its right side): themes with
-- corner art set closeInset to clear it (default 30); the other themes keep
-- the button near the edge.
local CLOSE_INSET_ART = 30
local CLOSE_INSET_PLAIN = 6

local CORNER_ORDER = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
-- Tiled frame corner plates: centered this far inside each window corner.
local TILED_CORNER_OFFSETS = {
  TOPLEFT = { 6, -6 }, TOPRIGHT = { -6, -6 }, BOTTOMLEFT = { 6, 6 }, BOTTOMRIGHT = { -6, 6 },
}
-- Divider with a gem (dividerGem): gem size, and how far the lines stay
-- from the border band.
local DIVIDER_GEM_SIZE = 14
local DIVIDER_GEM_INSET = 14

local windows = {}
local ReapplyAll -- defined below

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------

-- Resolves an id or a number (position in ThemeOrder) to a theme id, or nil.
local function ResolveId(id)
  if type(id) == "number" or tonumber(id) then
    id = Pathwise.ThemeOrder[tonumber(id)]
  end
  if id and Pathwise.Themes[id] then
    return id
  end
end

-- Theme table for id (or number), falling back to the default theme.
function Theme.Get(id)
  return Pathwise.Themes[ResolveId(id) or Pathwise.DefaultTheme]
end

-- The saved theme id; an unknown saved id falls back to the default.
function Theme.GetActiveId()
  return ResolveId(Pathwise.db and Pathwise.db.theme) or Pathwise.DefaultTheme
end

-- Saves the theme account-wide and re-skins every registered window.
-- Returns the id, or nil if it isn't a known theme.
function Theme.SetActive(id)
  id = ResolveId(id)
  if not id then
    return nil
  end
  Pathwise.db.theme = id
  ReapplyAll()
  Pathwise:FireCallback("THEME_CHANGED", id)
  return id
end

function Theme.Register(window)
  windows[#windows + 1] = window
end

-- Re-skins every registered window with the active theme.
function ReapplyAll()
  for _, window in ipairs(windows) do
    Theme.Apply(window)
  end
end

---------------------------------------------------------------------------
-- Wildwood seasons
---------------------------------------------------------------------------

-- The saved season setting: "summer", "autumn" or "auto" (unknown -> summer).
function Theme.GetSeasonSetting()
  local saved = Pathwise.db and Pathwise.db.wildwoodSeason
  for _, season in ipairs(Pathwise.WildwoodSeasons) do
    if saved == season then
      return season
    end
  end
  return "summer"
end

-- The season to draw: "auto" is autumn in September-November, else summer.
function Theme.GetSeason()
  local setting = Theme.GetSeasonSetting()
  if setting ~= "auto" then
    return setting
  end
  local now = date and date("*t")
  return now and Pathwise.AutumnMonths[now.month] and "autumn" or "summer"
end

-- Saves the season setting and re-skins. Returns it, or nil if unknown.
function Theme.SetSeason(season)
  for _, known in ipairs(Pathwise.WildwoodSeasons) do
    if season == known then
      Pathwise.db.wildwoodSeason = season
      ReapplyAll()
      Pathwise:FireCallback("THEME_SEASON_CHANGED", season)
      return season
    end
  end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function RGB(hex, alpha)
  return Pathwise.HexToRGB(hex, alpha)
end

-- Solid color on a texture. SetColorTexture exists in Classic Era; older
-- clients get WHITE8X8 tinted with SetVertexColor.
local function SetSolid(texture, hex, alpha)
  if texture.SetColorTexture then
    texture:SetColorTexture(RGB(hex, alpha))
  else
    texture:SetTexture(WHITE)
    texture:SetVertexColor(RGB(hex, alpha))
  end
end

-- 1 px lines blur at odd UI scales; PixelUtil snaps them when it exists.
local function SetPixelHeight(texture, height)
  if PixelUtil and PixelUtil.SetHeight then
    PixelUtil.SetHeight(texture, height)
  else
    texture:SetHeight(height)
  end
end

local function SetFlip(texture, flipH, flipV)
  texture:SetTexCoord(flipH and 1 or 0, flipH and 0 or 1, flipV and 1 or 0, flipV and 0 or 1)
end

-- Places painted corner art (docs/PATHWISE_THEMES_V2.md §2). Every file is
-- drawn for the top-left corner; the others mirror it. art.ax, art.ay is the
-- spot in the art that sits on the window's outer corner. Full color: never
-- tinted. file: the texture name (seasonal suffix already added).
-- art = { file = "dragon_emblem", w = 60, h = 60, ax = 20.4, ay = 24 }
local function PlaceCornerArt(texture, window, corner, art, file)
  texture:SetTexture(MEDIA .. file)
  texture:SetSize(art.w, art.h)
  texture:SetVertexColor(1, 1, 1)
  texture:ClearAllPoints()
  if corner == "TOPLEFT" then
    texture:SetPoint("TOPLEFT", window, "TOPLEFT", -art.ax, art.ay)
    texture:SetTexCoord(0, 1, 0, 1)
  elseif corner == "TOPRIGHT" then
    texture:SetPoint("TOPRIGHT", window, "TOPRIGHT", art.ax, art.ay)
    texture:SetTexCoord(1, 0, 0, 1) -- flip horizontal
  elseif corner == "BOTTOMLEFT" then
    texture:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", -art.ax, -art.ay)
    texture:SetTexCoord(0, 1, 1, 0) -- flip vertical
  else -- BOTTOMRIGHT
    texture:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", art.ax, -art.ay)
    texture:SetTexCoord(1, 0, 1, 0) -- flip both
  end
  texture:Show()
end

-- Places an ornament texture: art file (nil = solid WHITE8X8), size, color.
local function Ornament(texture, art, width, height, hex, alpha)
  texture:SetTexture(art and (MEDIA .. art) or WHITE)
  texture:SetSize(width, height)
  texture:SetVertexColor(RGB(hex, alpha))
  texture:ClearAllPoints()
  texture:Show()
end

-- Quest names come from Core in "|cffRRGGBB[level] Title|r" form, colored
-- with Core's fallback palette (grey 808080, green 40c040, yellow ffd100,
-- orange ff8040, red ff2020). When the client has GetQuestDifficultyColor
-- (checked at runtime), recolor them with WoW's own difficulty colors.
function Theme.RecolorQuestNames(text)
  if not GetQuestDifficultyColor then
    return text
  end
  return (text:gsub("|cff%x%x%x%x%x%x(%[(%d+)%] )", function(prefix, level)
    local color = GetQuestDifficultyColor(tonumber(level))
    if not color then
      return nil
    end
    return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) .. prefix
  end))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local WindowMixin = {}

-- Marks the current step's rows (first..last) with the theme's highlight.
function WindowMixin:SetHighlightRow(first, last)
  self.highlightFirst, self.highlightLast = first, last or first
  self:UpdateHighlight()
end

function WindowMixin:UpdateHighlight()
  local theme, first, last = self.theme, self.highlightFirst, self.highlightLast
  self.highlightFill:Hide()
  self.highlightBar:Hide()
  if not theme or not first then
    return
  end
  if theme.highlight == "fillbar" then
    -- v4: the row fill, plus a 2 px bar on its left edge.
    local fill, bar = self.highlightFill, self.highlightBar
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", first, "TOPLEFT", -6, 1)
    fill:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 6, -1)
    SetSolid(fill, theme.highlightColor, theme.highlightAlpha)
    fill:Show()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
    bar:SetWidth(2)
    SetSolid(bar, theme.highlightBar or theme.ornament, 1)
    bar:Show()
  elseif theme.highlight == "bar" then
    local bar = self.highlightBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", first, "TOPLEFT", -8, 0)
    bar:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", -8, 0)
    bar:SetWidth(3)
    SetSolid(bar, theme.ornament, 1)
    bar:Show()
  else
    local fill = self.highlightFill
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", first, "TOPLEFT", -6, 1)
    fill:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 6, -1)
    SetSolid(fill, theme.highlightColor, theme.highlightAlpha)
    fill:Show()
  end
end

-- Content height in px; the window grows to fit header, content and footer.
function WindowMixin:SetContentHeight(height)
  self.contentHeight = height
  self:Layout()
end

-- Height of everything except the content (header, gaps, footer).
function WindowMixin:ChromeHeight()
  return (self.headerHeight or HEADER_PLAIN) + CONTENT_GAP + 4 + FOOTER_HEIGHT + BOTTOM_PADDING
    + (self.bottomBand or 0)
end

-- With a player-chosen height (see EnableResizing) the window keeps that
-- height and the content gets what's left; otherwise the window grows to fit
-- the content.
function WindowMixin:Layout()
  if self.fixedHeight then
    self.content:SetHeight(math.max(self.fixedHeight - self:ChromeHeight(), 1))
    self:SetHeight(self.fixedHeight)
  else
    self.content:SetHeight(math.max(self.contentHeight or 1, 1))
    self:SetHeight(self:ChromeHeight() + (self.contentHeight or 0))
  end
  self:UpdateTiling()
end

-- Tiled frame: one texture repeat along a band is the texture's length at
-- the band's thickness (1024 x 32 -> 384 at 12). The repeat count follows
-- the window size, so this runs after every layout and on resize.
-- (Repeating uses the texture's wrap modes, SetTexture(file, "REPEAT",
-- "CLAMP"), with texture coordinates past 1; Classic Era has them.)
function WindowMixin:UpdateTiling()
  local theme = self.theme
  if not (theme and theme.tiled and self.tiledPieces) then
    return
  end
  local art, pieces = theme.azure, self.tiledPieces
  local tile = 1024 * (art.band / 32)
  local width, height = self:GetWidth(), self:GetHeight()
  pieces.top:SetTexCoord(0, width / tile, 0, 1)
  pieces.bottom:SetTexCoord(0, width / tile, 0, 1)
  pieces.left:SetTexCoord(0, 1, 0, height / tile)
  pieces.right:SetTexCoord(0, 1, 0, height / tile)
end

-- Content height available with a player-chosen height, or nil (auto).
function WindowMixin:GetContentCapacity()
  if self.fixedHeight then
    return math.max(self.fixedHeight - self:ChromeHeight(), 0)
  end
end

local MAX_WIDTH, MAX_HEIGHT = 700, 900
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

-- Resize bounds: the minimum height depends on the theme's header height,
-- so it's recomputed whenever a theme is applied.
function WindowMixin:UpdateResizeBounds()
  if not self.resizeMinWidth then
    return
  end
  local minHeight = self:ChromeHeight() + self.resizeMinContent
  -- SetResizeBounds replaced SetMinResize/SetMaxResize in newer clients;
  -- use whichever this client has.
  if self.SetResizeBounds then
    self:SetResizeBounds(self.resizeMinWidth, minHeight, MAX_WIDTH, MAX_HEIGHT)
  else
    if self.SetMinResize then
      self:SetMinResize(self.resizeMinWidth, minHeight)
    end
    if self.SetMaxResize then
      self:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
    end
  end
end

-- Ends a resize drag (mouse released, or the window hidden mid-drag).
local function FinishSizing(self)
  if not self.sizing then
    return
  end
  self:StopMovingOrSizing()
  self.sizing = false
  self.fixedHeight = self:GetHeight()
  self.onResized(self:GetWidth(), self.fixedHeight, false)
end

-- Adds a size grip in the bottom-right corner. Dragging it resizes the
-- window; right-clicking it goes back to the automatic height.
-- onResized(width, height, live) is called while dragging (live = true) and
-- once at the end; height is nil for automatic.
-- minContentHeight: smallest content area the grip allows.
function WindowMixin:EnableResizing(minWidth, minContentHeight, onResized)
  self:SetResizable(true)
  self.resizeMinWidth, self.resizeMinContent, self.onResized = minWidth, minContentHeight, onResized
  self:UpdateResizeBounds()

  local grip = CreateFrame("Button", nil, self)
  grip:SetSize(16, 16)
  -- (Placed by PlaceGrip: some themes move it off their corner art.)
  grip:SetNormalTexture(GRIP .. "Up")
  grip:SetHighlightTexture(GRIP .. "Highlight")
  grip:SetPushedTexture(GRIP .. "Down")
  -- Above the ornaments so corner art can't cover it.
  grip:SetFrameLevel(self.ornaments:GetFrameLevel() + 1)
  grip:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      self.sizing = true
      self:StartSizing("BOTTOMRIGHT")
    end
  end)
  grip:SetScript("OnMouseUp", function(_, button)
    if self.sizing then
      FinishSizing(self)
    elseif button == "RightButton" then
      self.fixedHeight = nil
      onResized(self:GetWidth(), nil, false)
    end
  end)
  grip:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.WINDOW_RESIZE_TOOLTIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  self:HookScript("OnSizeChanged", function()
    if self.sizing then
      self.fixedHeight = self:GetHeight()
      onResized(self:GetWidth(), self.fixedHeight, true)
    end
  end)
  -- Hidden mid-drag (close button, key binding): the grip never gets its
  -- mouse-up, so finish the resize here.
  self:HookScript("OnHide", FinishSizing)
  self.grip = grip
  self:PlaceGrip()
end

-- The size grip sits in the bottom-right corner, or where the theme says
-- (gripOffset: Azure moves it above its corner gem so it doesn't darken it).
local GRIP_OFFSET = { -5, 5 }

function WindowMixin:PlaceGrip()
  if not self.grip then
    return
  end
  local offset = self.theme and self.theme.gripOffset or GRIP_OFFSET
  self.grip:ClearAllPoints()
  self.grip:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset[1], offset[2])
end

function WindowMixin:SetTitleText(text)
  self.titleText = text
  if self.theme then
    Theme.Apply(self, self.themeId)
  end
end

-- Builds a themed window. Returns it with .header (band area), .title,
-- .label, .content, .footer (with .footer.text), .close; registers it so
-- theme changes re-skin it.
function Theme.CreateWindow(name, parent, titleText)
  -- BackdropTemplate is needed for SetBackdrop since 1.13.6 (it exists in
  -- Classic Era); without it the window simply has no backdrop.
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local window = CreateFrame("Frame", name, parent or UIParent, template)
  for key, fn in pairs(WindowMixin) do
    window[key] = fn
  end
  window:SetWidth(WIDTH)
  window.titleText = titleText or ""

  window.trim = CreateFrame("Frame", nil, window, template)
  window.header = window:CreateTexture(nil, "BACKGROUND", nil, 1) -- header band
  window.divider = window:CreateTexture(nil, "ARTWORK")
  window.dividerRight = window:CreateTexture(nil, "ARTWORK") -- right half when there's a gem
  window.dividerGem = window:CreateTexture(nil, "OVERLAY")
  window.label = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  window.headerIcon = window:CreateTexture(nil, "OVERLAY")
  window.close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  window.close:SetSize(24, 24)
  -- (Raised above the ornaments once they exist, below.)

  window.content = CreateFrame("Frame", nil, window)
  window.content:SetPoint("RIGHT", window, "RIGHT", -SIDE_PADDING, 0)
  window.highlightFill = window.content:CreateTexture(nil, "BACKGROUND")
  window.highlightBar = window.content:CreateTexture(nil, "ARTWORK")

  window.footer = CreateFrame("Frame", nil, window)
  window.footer:SetHeight(FOOTER_HEIGHT)
  window.footer:SetPoint("TOPLEFT", window.content, "BOTTOMLEFT", 0, -4)
  window.footer:SetPoint("TOPRIGHT", window.content, "BOTTOMRIGHT", 0, -4)
  window.footer.text = window.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  window.footer.text:SetPoint("LEFT", window.footer, "LEFT", 0, 0)

  -- Ornaments: above the border, never clipped.
  window.ornaments = CreateFrame("Frame", nil, window)
  window.ornaments:SetAllPoints(window)
  window.ornaments:SetFrameLevel(window:GetFrameLevel() + 5)
  window.ornaments:EnableMouse(false)
  -- Never covered by corner art.
  window.close:SetFrameLevel(window.ornaments:GetFrameLevel() + 1)
  -- Per corner: art (corner art or a diamond) and the two bracket lines.
  window.corners = {}
  for _, corner in ipairs(CORNER_ORDER) do
    window.corners[corner] = {
      art = window.ornaments:CreateTexture(nil, "OVERLAY"),
      lineH = window.ornaments:CreateTexture(nil, "OVERLAY"),
      lineV = window.ornaments:CreateTexture(nil, "OVERLAY"),
    }
  end

  -- Tiled frame pieces (v4): made once, shown only for tiled themes.
  local ornaments = window.ornaments
  window.tiledPieces = {
    bg = window:CreateTexture(nil, "BACKGROUND", nil, -8),
    gloss = window:CreateTexture(nil, "BORDER"),
    top = ornaments:CreateTexture(nil, "ARTWORK"),
    bottom = ornaments:CreateTexture(nil, "ARTWORK"),
    left = ornaments:CreateTexture(nil, "ARTWORK"),
    right = ornaments:CreateTexture(nil, "ARTWORK"),
    crest = ornaments:CreateTexture(nil, "OVERLAY", nil, 2), -- above the corners
    corners = {},
  }
  for _, corner in ipairs(CORNER_ORDER) do
    window.tiledPieces.corners[corner] = ornaments:CreateTexture(nil, "OVERLAY", nil, 1)
  end
  window:HookScript("OnSizeChanged", function()
    window:UpdateTiling()
  end)

  Theme.Register(window)
  Theme.Apply(window)
  return window
end

---------------------------------------------------------------------------
-- Skinning
---------------------------------------------------------------------------

local function HideCorners(window)
  for _, slots in pairs(window.corners) do
    for _, texture in pairs(slots) do
      texture:Hide()
    end
  end
end

local function ApplyCorners(window, theme)
  HideCorners(window)
  local style = theme.corners
  for _, name in ipairs(CORNER_ORDER) do
    local slots = window.corners[name]
    local art = theme.cornerArt and theme.cornerArt[name:find("^TOP") and "top" or "bottom"]

    if art then
      local file = art.file
      if theme.seasonal then
        file = file .. "_" .. Theme.GetSeason()
      end
      PlaceCornerArt(slots.art, window, name, art, file)

    elseif style == "diamonds" then
      Ornament(slots.art, "diamond", 10, 10, theme.ornament)
      slots.art:SetPoint("CENTER", window, name, 0, 0)
      SetFlip(slots.art, false, false)

    elseif style == "brackets" then
      -- An L inside the corner: 16x2 along the edge, 2x16 down the side.
      Ornament(slots.lineH, nil, 16, 2, theme.ornament)
      slots.lineH:SetPoint(name, window, name, 0, 0)
      Ornament(slots.lineV, nil, 2, 16, theme.ornament)
      slots.lineV:SetPoint(name, window, name, 0, 0)
    end
  end
end

local function ApplyBackdrop(window, theme)
  if theme.tiled then
    -- The tiled frame draws its own background and border.
    if window.SetBackdrop then
      window:SetBackdrop(nil)
    end
    window.trim:Hide()
    return
  end
  if not window.SetBackdrop then
    return
  end
  if theme.useTooltipArt then
    window:SetBackdrop({
      bgFile = TOOLTIP_BG,
      edgeFile = TOOLTIP_EDGE,
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
  else
    local width = theme.frame and theme.frameWidth or 0
    window:SetBackdrop({
      bgFile = WHITE,
      edgeFile = width > 0 and WHITE or nil,
      edgeSize = width > 0 and width or nil,
      insets = { left = width, right = width, top = width, bottom = width },
    })
  end
  window:SetBackdropColor(RGB(theme.bg, theme.bgAlpha))
  if theme.frame then
    window:SetBackdropBorderColor(RGB(theme.frame, 1))
  end

  local trim = window.trim
  if theme.trim and trim.SetBackdrop then
    trim:ClearAllPoints()
    trim:SetPoint("TOPLEFT", window, "TOPLEFT", theme.trimInset, -theme.trimInset)
    trim:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -theme.trimInset, theme.trimInset)
    trim:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    trim:SetBackdropBorderColor(RGB(theme.trim, theme.trimAlpha))
    trim:Show()
  else
    trim:Hide()
  end
end

-- Shows and places the tiled frame (docs/PATHWISE_THEMES_V4.md §2), or
-- hides every piece of it for the other themes. Full color: never tinted.
local function ApplyTiled(window, theme)
  local pieces = window.tiledPieces
  local art = theme.tiled and theme.azure
  for _, texture in pairs(pieces) do
    if type(texture) == "table" and texture.Hide then
      texture:Hide()
    end
  end
  for _, texture in pairs(pieces.corners) do
    texture:Hide()
  end
  if not art then
    return
  end
  local function Art(texture, file, wrapH, wrapV)
    texture:SetTexture(MEDIA .. file, wrapH, wrapV)
    texture:SetVertexColor(1, 1, 1)
    texture:ClearAllPoints()
    texture:Show()
  end

  Art(pieces.bg, art.bgTex)
  pieces.bg:SetTexCoord(0, 1, 0, 1)
  pieces.bg:SetAllPoints(window)

  Art(pieces.gloss, art.gloss)
  pieces.gloss:SetTexCoord(0, 1, 0, 1)
  pieces.gloss:SetPoint("TOPLEFT", window, "TOPLEFT", art.glossInset, -art.glossInset)
  pieces.gloss:SetPoint("TOPRIGHT", window, "TOPRIGHT", -art.glossInset, -art.glossInset)
  pieces.gloss:SetHeight(art.glossHeight)

  Art(pieces.top, art.edgeH, "REPEAT", "CLAMP")
  pieces.top:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
  pieces.top:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
  pieces.top:SetHeight(art.band)
  Art(pieces.bottom, art.edgeH, "REPEAT", "CLAMP")
  pieces.bottom:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
  pieces.bottom:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
  pieces.bottom:SetHeight(art.band)
  Art(pieces.left, art.edgeV, "CLAMP", "REPEAT")
  pieces.left:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
  pieces.left:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
  pieces.left:SetWidth(art.band)
  Art(pieces.right, art.edgeV, "CLAMP", "REPEAT")
  pieces.right:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
  pieces.right:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
  pieces.right:SetWidth(art.band)

  -- Corner plates: the same texture on every corner, no mirroring.
  for corner, texture in pairs(pieces.corners) do
    Art(texture, art.corner)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetSize(art.cornerSize, art.cornerSize)
    local offset = TILED_CORNER_OFFSETS[corner]
    texture:SetPoint("CENTER", window, corner, offset[1], offset[2])
  end

  Art(pieces.crest, art.crest)
  pieces.crest:SetTexCoord(0, 1, 0, 1)
  pieces.crest:SetSize(art.crestSize, art.crestSize)
  pieces.crest:SetPoint("CENTER", window, "TOP", 0, art.crestOffsetY)
  window:UpdateTiling()
end

local function ApplyHeader(window, theme)
  local creature = theme.cornerArt ~= nil
  local tiled = theme.tiled and theme.azure
  local emblem = creature and theme.cornerArt.top and theme.cornerArt.top.emblem
  local headerHeight = tiled and HEADER_TILED or emblem and HEADER_EMBLEM or creature and HEADER_CREATURE
    or HEADER_PLAIN
  local inset = tiled and tiled.band or theme.useTooltipArt and 4 or (theme.frame and theme.frameWidth or 0)
  local sidePadding = SIDE_PADDING + (tiled and tiled.band or 0)
  window.headerHeight = headerHeight
  window.bottomBand = tiled and tiled.band or 0

  -- Header band
  local band = window.header
  band:ClearAllPoints()
  band:SetPoint("TOPLEFT", window, "TOPLEFT", inset, -inset)
  band:SetPoint("TOPRIGHT", window, "TOPRIGHT", -inset, -inset)
  band:SetHeight(headerHeight - inset)
  if theme.band then
    SetSolid(band, theme.band, 1)
    band:Show()
  else
    band:Hide()
  end

  -- Divider under the header (gilded: with a small diamond in the middle)
  local divider = window.divider
  divider:ClearAllPoints()
  divider:SetPoint("TOPLEFT", window, "TOPLEFT", inset, -headerHeight)
  divider:SetPoint("TOPRIGHT", window, "TOPRIGHT", -inset, -headerHeight)
  SetPixelHeight(divider, 1)
  if theme.divider then
    SetSolid(divider, theme.divider, theme.dividerAlpha)
    divider:Show()
  else
    divider:Hide()
  end
  local gem, right = window.dividerGem, window.dividerRight
  right:Hide()
  if theme.dividerGem then
    -- v4: a full-color gem centered under the title, a line on each side.
    gem:SetTexture(MEDIA .. theme.dividerGem)
    gem:SetVertexColor(1, 1, 1)
    gem:SetTexCoord(0, 1, 0, 1)
    gem:SetSize(DIVIDER_GEM_SIZE, DIVIDER_GEM_SIZE)
    gem:ClearAllPoints()
    gem:SetPoint("CENTER", window, "TOP", 0, -headerHeight)
    gem:Show()
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", window, "TOPLEFT", inset + DIVIDER_GEM_INSET, -headerHeight)
    divider:SetPoint("TOPRIGHT", gem, "LEFT", -2, 0)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", gem, "RIGHT", 2, 0)
    right:SetPoint("TOPRIGHT", window, "TOPRIGHT", -(inset + DIVIDER_GEM_INSET), -headerHeight)
    SetPixelHeight(right, 1)
    SetSolid(right, theme.divider, theme.dividerAlpha)
    right:Show()
  elseif theme.dividerStyle == "diamond" then
    Ornament(gem, "diamond", 6, 6, theme.ornament)
    gem:SetPoint("CENTER", divider, "CENTER", 0, 0)
  else
    gem:Hide()
  end

  -- Label ("PATHWISE") and title
  local label, title, icon = window.label, window.title, window.headerIcon
  label:ClearAllPoints()
  title:ClearAllPoints()
  icon:Hide()
  label:SetText(L.WINDOW_LABEL)
  label:SetTextColor(RGB(theme.label or theme.muted))
  title:SetTextColor(RGB(theme.title))
  -- Left-aligned by default; the centered layout below overrides this.
  -- (Width 0 = size to the text, so no leftover width from a centered theme.)
  title:SetWidth(0)
  title:SetJustifyH("LEFT")
  label:SetJustifyH("LEFT")

  if theme.titleText then
    -- Single-line header ("Pathwise · To-do").
    label:Hide()
    title:SetText(string.format(L.WINDOW_SINGLE_TITLE, window.titleText))
    title:SetPoint("LEFT", window, "TOPLEFT", SIDE_PADDING, -headerHeight / 2)
  elseif creature or tiled then
    label:Show()
    title:SetText(window.titleText)
    -- (Tiled frame: 22 px from the top, under the crest and the band.)
    local top = tiled and 22 or 12
    label:SetPoint("TOP", window, "TOP", 0, -top)
    -- Between the ornaments; follows the window width when resized.
    title:SetPoint("TOPLEFT", window, "TOPLEFT", CREATURE_PADDING, -(top + 12))
    title:SetPoint("TOPRIGHT", window, "TOPRIGHT", -CREATURE_PADDING, -(top + 12))
    title:SetJustifyH("CENTER")
    label:SetJustifyH("CENTER")
  else
    label:Show()
    title:SetText(window.titleText)
    local x = SIDE_PADDING
    if theme.headerIcon then
      -- Moonlit: a crescent left of the title.
      Ornament(icon, theme.headerIcon, 18, 18, theme.ornament)
      icon:SetPoint("TOPLEFT", window, "TOPLEFT", SIDE_PADDING, -20)
      SetFlip(icon, false, false)
      x = SIDE_PADDING + 24
    end
    label:SetPoint("TOPLEFT", window, "TOPLEFT", x, -8)
    title:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
  end

  -- Close button: right side of the header, clear of the corner art.
  local close = window.close
  local closeInset = theme.closeInset or (creature and CLOSE_INSET_ART or CLOSE_INSET_PLAIN)
  close:ClearAllPoints()
  close:SetPoint("RIGHT", window, "TOPRIGHT", -closeInset, -headerHeight / 2)

  -- Content below the header
  window.content:ClearAllPoints()
  window.content:SetPoint("TOPLEFT", window, "TOPLEFT", sidePadding, -(headerHeight + CONTENT_GAP))
  window.content:SetPoint("RIGHT", window, "RIGHT", -sidePadding, 0)
end

-- (Re)applies a theme to one window. Called on creation and on every switch.
function Theme.Apply(window, id)
  id = ResolveId(id) or Theme.GetActiveId()
  local theme = Theme.Get(id)
  window.theme, window.themeId = theme, id

  ApplyBackdrop(window, theme)
  ApplyHeader(window, theme)
  ApplyCorners(window, theme)
  ApplyTiled(window, theme)
  window.footer.text:SetTextColor(RGB(theme.muted))
  window.textColor = { RGB(theme.text) }
  window.mutedColor = { RGB(theme.muted) }
  window:UpdateHighlight()
  window:UpdateResizeBounds()
  window:PlaceGrip()
  window:Layout()
  if window.OnThemeApplied then
    window:OnThemeApplied(theme)
  end
end

---------------------------------------------------------------------------
-- /pw theme
---------------------------------------------------------------------------

local function ListThemes()
  local parts = {}
  local active = Theme.GetActiveId()
  for index, id in ipairs(Pathwise.ThemeOrder) do
    local text = index .. " " .. Pathwise.Themes[id].name
    if id == active then
      text = text .. " " .. L.THEME_ACTIVE
    end
    parts[#parts + 1] = text
  end
  Pathwise:PrintLine(string.format(L.THEME_LIST, table.concat(parts, ", ")))
end

-- /pw theme            list (numbered, active marked)
-- /pw theme <n|id>     set
-- /pw theme next       cycle
Pathwise:RegisterCommand("theme", function(args)
  args = args:lower()
  if args == "" then
    ListThemes()
    return
  end
  local id
  if args == "next" then
    local current = Theme.GetActiveId()
    for index, themeId in ipairs(Pathwise.ThemeOrder) do
      if themeId == current then
        id = Pathwise.ThemeOrder[index % #Pathwise.ThemeOrder + 1]
      end
    end
  else
    id = args
  end
  id = Theme.SetActive(id)
  if id then
    Pathwise:Printf(L.THEME_SET, Pathwise.Themes[id].name)
  else
    Pathwise:Printf(L.THEME_UNKNOWN, args)
    ListThemes()
  end
end, L.CMD_THEME)

-- /pw season summer|autumn|auto   Wildwood's leaves
Pathwise:RegisterCommand("season", function(args)
  local season = Theme.SetSeason(args:lower())
  if not season then
    Pathwise:Print(L.SEASON_USAGE)
    return
  end
  if season == "auto" then
    Pathwise:Printf(L.SEASON_SET_AUTO, L["SEASON_" .. Theme.GetSeason():upper()])
  else
    Pathwise:Printf(L.SEASON_SET, L["SEASON_" .. season:upper()])
  end
end, L.CMD_SEASON)
