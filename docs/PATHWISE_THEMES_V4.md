# Pathwise — Themes Update v4 (Azure theme)

> Update on top of `PATHWISE_THEMES.md` (v1), `_V2.md` and `_V3.md`. Everything there still applies.
> Adds one new theme, **Azure**, that matches the Pathwise logo: deep blue enamel window, antique-gold border band engraved with runes, gold corner plates with blue gems, a gold compass crest on the top edge, and a soft shine across the top.
> Unlike the other themes, Azure's border is built from **tiled textures**, so it needs a small new code path ("tiled frame").

---

## 1. Files — add to `Media/Themes/` (32-bit TGA with alpha, full color, never tint)

| File | Size | Use |
|---|---|---|
| `azure_edge_h.tga` | 1024×32 | top + bottom border band (tiles horizontally) |
| `azure_edge_v.tga` | 32×1024 | left + right border band (tiles vertically) |
| `azure_corner.tga` | 128×128 | the 4 corner plates |
| `azure_crest.tga` | 128×128 | compass crest, top-center on the border |
| `azure_gem.tga` | 64×64 | small diamond gem in the header divider |
| `azure_bg.tga` | 512×512 | window background (stretched) |
| `azure_gloss.tga` | 512×128 | white shine overlay, top of window |

Previews: `Docs/theme-previews-v4/`.

---

## 2. Layout (UI units, window 340 wide as before)

```
 [corner]════ rune band (12 high) ═══[crest]═══ rune band ════[corner]
 ║                     shine (84 high, under text)                    ║
 ║                          PATHWISE                                  ║
 ║                           To-do                                    ║
 ║            ────────────────◆────────────────   (divider)            ║
 ║  ▌1 Webwood Venom ...                       [4]                    ║
 ║   2 ...                                                            ║
 ║   4 quests                                  Teldrassil             ║
 [corner]═══════════════════ rune band ═══════════════════════[corner]
```

| Piece | Layer | Placement |
|---|---|---|
| Background | `BACKGROUND` | `SetAllPoints(window)`, texture `azure_bg`, stretched |
| Shine | `BORDER` | TOPLEFT (12, -12) → TOPRIGHT (-12, -12), height 84, `azure_gloss` |
| Top band | ornament frame, `ARTWORK` | TOPLEFT (0,0) → TOPRIGHT (0,0), height 12, `azure_edge_h`, tiled (§3) |
| Bottom band | same | BOTTOMLEFT (0,0) → BOTTOMRIGHT (0,0), height 12, `azure_edge_h`, tiled |
| Left band | same | TOPLEFT (0,0) → BOTTOMLEFT (0,0), width 12, `azure_edge_v`, tiled |
| Right band | same | TOPRIGHT (0,0) → BOTTOMRIGHT (0,0), width 12, `azure_edge_v`, tiled |
| Corners ×4 | ornament frame, `OVERLAY` | 30×30, `SetPoint("CENTER", window, "TOPLEFT", 6, -6)` / `("TOPRIGHT", -6, -6)` / `("BOTTOMLEFT", 6, 6)` / `("BOTTOMRIGHT", -6, 6)` — same texture, no mirroring |
| Crest | ornament frame, `OVERLAY` (sublevel above corners) | 36×36, `SetPoint("CENTER", window, "TOP", 0, -3)` |
| Divider | content | 1 px lines in `#a37a38` left and right of a 14×14 `azure_gem` centered under the title, 14 px inset from the band |

Content padding: 12 px band + the usual inner padding. Header: 22 px top padding, text centered.

---

## 3. Tiling the rune bands

Tile by setting texture coordinates from the window size, and update them in the window's `OnSizeChanged`:

```lua
local PATH = "Interface\\AddOns\\Pathwise\\Media\\Themes\\"
local BAND = 12                     -- band thickness in UI units
local TILE = 1024 * (BAND / 32)     -- one texture repeat = 384 UI units long

local function SetupBand(tex, horizontal)
  if horizontal then
    tex:SetTexture(PATH .. "azure_edge_h", "REPEAT", "CLAMP")
  else
    tex:SetTexture(PATH .. "azure_edge_v", "CLAMP", "REPEAT")
  end
  tex:SetVertexColor(1, 1, 1)
end

local function UpdateBandTiling(win)
  local w, h = win:GetSize()
  win.azTop:SetTexCoord(0, w / TILE, 0, 1)
  win.azBottom:SetTexCoord(0, w / TILE, 0, 1)
  win.azLeft:SetTexCoord(0, 1, 0, h / TILE)
  win.azRight:SetTexCoord(0, 1, 0, h / TILE)
end
```

If wrap modes are not honored in the client (check at runtime: the band shows one stretched copy instead of repeating), fall back to `tex:SetHorizTile(true)` / `SetVertTile(true)` where available, or to several band textures placed side by side. Add a comment saying which path was used.

---

## 4. Theme data — add to `UI/ThemeData.lua`

```lua
azure = {
  name = "Azure",
  tiled = true,                 -- use the tiled frame path (§2–3) instead of backdrop border + cornerArt
  bg = "#0a2a56", bgAlpha = 1,  -- only used for the settings swatch; the window uses azure_bg
  frame = "#a37a38", frameWidth = 0,
  trim = nil, band = nil,
  divider = "#a37a38", dividerAlpha = 1, dividerGem = "azure_gem",
  label = "#9cc4ee",            -- small "PATHWISE" text
  title = "#e0bf74", muted = "#9cb4d4", text = "#c6d6ea",
  ornament = "#2a6cc0",
  highlight = "fillbar",        -- NEW style: fill + 2 px bar on the left
  highlightColor = "#6eaaf0", highlightAlpha = 0.14, highlightBar = "#a37a38",
  closeInset = 30,
  azure = {
    edgeH = "azure_edge_h", edgeV = "azure_edge_v", band = 12,
    corner = "azure_corner", cornerSize = 30,
    crest = "azure_crest", crestSize = 36, crestOffsetY = -3,
    bgTex = "azure_bg",
    gloss = "azure_gloss", glossHeight = 84, glossInset = 12,
  },
},
```

Add `"azure"` to `Pathwise.ThemeOrder` as the **first** entry (it's the theme that matches the logo). Keep `Pathwise.DefaultTheme` unchanged.

### Code changes in `UI/Theme.lua`

- Create the Azure pieces once per window (4 bands, 4 corners, crest, background texture, shine texture, divider gem) and keep them hidden by default.
- `Apply(window, id)`: when `theme.tiled` is true → hide the backdrop border/inner trim and any `cornerArt` textures, show and place the Azure pieces, call `UpdateBandTiling`. For every other theme → hide all Azure pieces. No leftovers either way.
- New highlight style `"fillbar"`: the usual row fill plus a 2 px wide bar on the row's left edge in `highlightBar`.
- New optional field `label`: color of the small "PATHWISE" text (default `muted`).
- If `dividerGem` is set, show that texture (14×14) centered on the divider line; otherwise a plain line as before.
- Hook `OnSizeChanged` (if not already) so the bands re-tile when the window grows with more quests.

---

## 5. Done when

- [ ] All 7 textures load after a **full WoW restart**.
- [ ] Azure shows: blue background with shine at the top, rune bands on all four sides **repeating** (not stretched), gem corners centered on the corners, crest centered on the top band.
- [ ] Adding/removing quests (window height changes) keeps the side bands tiled correctly.
- [ ] Switching Azure → any other theme → Azure leaves no leftover pieces; `/pw theme next` through all themes has no Lua errors and no memory growth.
- [ ] Close button not covered.
- [ ] Settings shows Azure first in the theme grid.

## 6. Notes for Claude Code

- Don't edit or regenerate the textures; adjust only the numbers in the `azure` table if something sits off.
- Keep everything in `UI/`.
- Remind the player to fully restart WoW so the new texture files load.
