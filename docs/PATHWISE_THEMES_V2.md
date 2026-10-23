# Pathwise — Themes Update v2 (painted corner art)

> Update to `PATHWISE_THEMES.md`. Everything in that spec still applies **except** what this file changes.
> Four themes get new hand-painted, full-color corner art: **Dragonflight, Skyhawk, Wildwood, Phoenix Ember**.
> Gilded Hairline, Classic Tooltip, Moonlit and Corner Brackets are unchanged.

---

## 1. Files

### Add (in `Media/Themes/`, all 256×256, 32-bit TGA with alpha)

| File | Used by | What it is |
|---|---|---|
| `dragon_head.tga` | Dragonflight, top corners | Antique-gold dragon head, red eye |
| `eagle_head.tga` | Skyhawk, top corners | Gold eagle head, amber eye |
| `gem_ruby.tga` | Dragonflight, bottom corners | Faceted ruby in a gold mount |
| `gem_sapphire.tga` | Skyhawk, bottom corners | Faceted sapphire in a gold mount |
| `phoenix_feathers.tga` | Phoenix Ember, all 4 corners | Fan of fire feathers with glow |
| `wildwood_top_summer.tga` | Wildwood, top corners | Bark branch, green leaves |
| `wildwood_bottom_summer.tga` | Wildwood, bottom corners | Small branch, green leaves |
| `wildwood_top_autumn.tga` | Wildwood, top corners | Same branch, autumn leaves |
| `wildwood_bottom_autumn.tga` | Wildwood, bottom corners | Same, autumn leaves |

Previews of every texture are in `Docs/theme-previews-v2/`.

### Delete (no longer used)

`corner_dragon.tga`, `corner_eagle.tga`, `corner_antlers.tga`, `corner_feather_main.tga`, `corner_feather_side.tga`, `leaf.tga`.
**Keep** `diamond.tga` and `crescent.tga` (Gilded and Moonlit still use them).

---

## 2. How the new art works

- The new textures are **full color**. Never tint them: `tex:SetVertexColor(1, 1, 1)`.
- Every texture is drawn for the **top-left** corner. Other corners use the same file mirrored with `SetTexCoord`.
- Each art piece has an **anchor point**: the spot inside the texture that should sit exactly on the window's outer corner. It is given as `ax, ay` = UI units from the texture's top-left edge (for the top-left placement).
- Art overlaps the border and sticks out past the window. Don't clip it, and put it on the ornament child frame (frame level +5, layer `"OVERLAY"`, `EnableMouse(false)`) as in v1.

### Placement helper — add to `UI/Theme.lua`

```lua
local PATH = "Interface\\AddOns\\Pathwise\\Media\\Themes\\"

-- art = { file = "dragon_head", w = 110, h = 110, ax = 35, ay = 33 }
local function PlaceCornerArt(tex, win, corner, art)
  tex:SetTexture(PATH .. art.file)
  tex:SetSize(art.w, art.h)
  tex:SetVertexColor(1, 1, 1)
  tex:ClearAllPoints()
  if corner == "TOPLEFT" then
    tex:SetPoint("TOPLEFT", win, "TOPLEFT", -art.ax, art.ay)
    tex:SetTexCoord(0, 1, 0, 1)
  elseif corner == "TOPRIGHT" then
    tex:SetPoint("TOPRIGHT", win, "TOPRIGHT", art.ax, art.ay)
    tex:SetTexCoord(1, 0, 0, 1)          -- flip horizontal
  elseif corner == "BOTTOMLEFT" then
    tex:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", -art.ax, -art.ay)
    tex:SetTexCoord(0, 1, 1, 0)          -- flip vertical
  else -- BOTTOMRIGHT
    tex:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", art.ax, -art.ay)
    tex:SetTexCoord(1, 0, 1, 0)          -- flip both
  end
  tex:Show()
end
```

A theme with `cornerArt` uses this instead of the old `corners` layouts. `cornerArt.top` is placed on TOPLEFT + TOPRIGHT, `cornerArt.bottom` on BOTTOMLEFT + BOTTOMRIGHT. Either can be nil (no art there). Reuse the same 4 texture objects per window; just re-place them on theme switch, and hide them for themes without `cornerArt`.

---

## 3. Theme data changes — `UI/ThemeData.lua`

Replace these four entries completely. Fields not shown keep their v1 meaning.

```lua
dragonflight = {
  name = "Dragonflight",
  bg = "#1a0d0d", bgAlpha = 0.95,
  frame = "#9b2020", frameWidth = 3,
  trim = "#e0b04a", trimAlpha = 1, trimInset = 5,
  band = "#2a1010",
  divider = "#e0b04a", dividerAlpha = 1,
  title = "#ecc56a", muted = "#b59a7a", text = "#d6c6ba",
  ornament = "#e0b04a",
  highlight = "fill", highlightColor = "#e0b04a", highlightAlpha = 0.12,
  closeInset = 46,   -- close button this far from the right edge so the head doesn't cover it
  cornerArt = {
    top    = { file = "dragon_head", w = 110, h = 110, ax = 35, ay = 33 },
    bottom = { file = "gem_ruby",    w = 36,  h = 36,  ax = 18, ay = 18 },
  },
},

skyhawk = {
  name = "Skyhawk",
  bg = "#0d1426", bgAlpha = 0.95,
  frame = "#2f5fb3", frameWidth = 3,
  trim = "#d9b45a", trimAlpha = 1, trimInset = 5,
  band = "#15224a",
  divider = "#d9b45a", dividerAlpha = 1,
  title = "#f0d58a", muted = "#a9b4d6", text = "#c3cbe0",
  ornament = "#e3c06a",
  highlight = "fill", highlightColor = "#2f5fb3", highlightAlpha = 0.25,
  closeInset = 50,
  cornerArt = {
    top    = { file = "eagle_head",   w = 110, h = 110, ax = 40, ay = 35 },
    bottom = { file = "gem_sapphire", w = 36,  h = 36,  ax = 18, ay = 18 },
  },
},

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
  seasonal = true,   -- art file names get "_summer" / "_autumn" appended (see §4)
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
```

Other v1 rules that still apply to these themes: header band 52 px tall with the title centered and 40 px side padding, quest names in difficulty colors, swatch = `frame` + `ornament`.

**Close button:** use `theme.closeInset` (default 30 when missing) as its distance from the window's right edge.

---

## 4. Wildwood seasons

- New setting `PathwiseDB.wildwoodSeason`: `"summer"`, `"autumn"` or `"auto"`. Default `"summer"`. Unknown value → `"summer"`.
- `"auto"` picks autumn in September, October and November (`date("*t").month`), otherwise summer. Check it on login and when the theme is applied.
- For themes with `seasonal = true`, the texture file is `art.file .. "_" .. season`, e.g. `wildwood_top_autumn`.
- Settings panel: under the Appearance theme buttons, show a "Wildwood season" choice (Summer / Autumn / Auto) only while Wildwood is the active theme.
- Command: `/pw season summer|autumn|auto` → saves and re-skins immediately, prints `Wildwood season: Autumn`.

---

## 5. Done when

- [ ] All 9 new textures load (no green squares) after a **full WoW restart**.
- [ ] Dragon and eagle heads sit on the top corners, facing **outward** on both sides; their eyes sit near the window corner.
- [ ] Ruby/sapphire gems are centered on the bottom corners.
- [ ] Phoenix feathers fan outward from all four corners.
- [ ] Wildwood branches lie along the top and side edges at all four corners; the bottom ones point down/outward.
- [ ] `/pw season autumn` swaps Wildwood's leaves instantly; Auto follows the month.
- [ ] The close button is not covered by art in any theme.
- [ ] Old texture files are deleted and nothing references them (search the code for `corner_dragon`, `corner_eagle`, `corner_antlers`, `corner_feather`, `leaf`).
- [ ] Cycling `/pw theme next` many times: no Lua errors, no leftover art from the previous theme, no growing memory.

## 6. Notes for Claude Code

- Don't edit or regenerate the textures. If a placement looks off in game, adjust `ax`, `ay`, `w`, `h` in ThemeData only.
- Keep everything in `UI/`.
- Tell the player to fully restart WoW (not just `/reload`) so the new texture files are found.
