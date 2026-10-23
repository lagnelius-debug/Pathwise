# Pathwise — Themes Update v3 (emblem creatures)

> Update on top of `PATHWISE_THEMES.md` (v1) and `PATHWISE_THEMES_V2.md` (v2). Everything in those still applies **except** what this file changes.
> Summary: the sculpted dragon and eagle heads from v2 are replaced by clean gold **emblem** heads, and **five new emblem themes** are added. Wildwood and Phoenix Ember stay as in v2.

---

## 1. Files

### Add / replace (in `Media/Themes/`, all 256×256 32-bit TGA with alpha, full color — never tint)

| File | Theme | Use |
|---|---|---|
| `dragon_emblem.tga` | Dragonflight | top corners |
| `eagle_emblem.tga` | Skyhawk | top corners |
| `bull_emblem.tga` | Ironhorn (new) | top corners |
| `wolf_emblem.tga` | Frostfang (new) | top corners |
| `lion_emblem.tga` | Lionheart (new) | top corners |
| `owl_emblem.tga` | Moonwatch (new) | top corners |
| `phoenix_emblem.tga` | Phoenix Crest (new) | top corners |
| `gem_emblem_ruby.tga` | Dragonflight | bottom corners |
| `gem_emblem_sapphire.tga` | Skyhawk | bottom corners |
| `gem_emblem_topaz.tga` | Ironhorn | bottom corners |
| `gem_emblem_ice.tga` | Frostfang | bottom corners |
| `gem_emblem_amethyst.tga` | Lionheart | bottom corners |
| `gem_emblem_moonstone.tga` | Moonwatch | bottom corners |
| `gem_emblem_ember.tga` | Phoenix Crest | bottom corners |

The kit also re-includes the v2 files that are still used (`wildwood_*` ×4 and `phoenix_feathers.tga`). Overwrite them; they are unchanged.
Previews: `Docs/theme-previews-v3/`.

### Delete (replaced, no longer used)

`dragon_head.tga`, `eagle_head.tga`, `gem_ruby.tga`, `gem_sapphire.tga`.

---

## 2. Placement

Use the v2 helper `PlaceCornerArt` unchanged. All emblem art shares the same anchors:

```lua
local EMBLEM = { w = 60, h = 60, ax = 20.4, ay = 24 }   -- head: frame corner sits at (20.4, 24) inside the texture
local GEM    = { w = 24, h = 24, ax = 12,   ay = 12 }   -- gem: centered on the corner

local function Emblem(file) return { file = file, w = EMBLEM.w, h = EMBLEM.h, ax = EMBLEM.ax, ay = EMBLEM.ay } end
local function Gem(file)    return { file = file, w = GEM.w,    h = GEM.h,    ax = GEM.ax,    ay = GEM.ay    } end
```

Heads are drawn facing **left** (outward on the top-left). The helper's horizontal flip makes the top-right head face right (outward). Gems are symmetric.

Emblem themes: header band **48 px** tall, title centered, 40 px side padding. `closeInset = 36`.

---

## 3. Theme data — `UI/ThemeData.lua`

### Theme order (replace)

```lua
Pathwise.ThemeOrder = {
  "gilded", "tooltip", "moonlit", "brackets",
  "dragonflight", "skyhawk", "ironhorn", "frostfang", "lionheart", "moonwatch", "phoenixcrest",
  "wildwood", "ember",
}
Pathwise.DefaultTheme = "dragonflight"
```

### Replace `dragonflight` and `skyhawk`, add five new entries

```lua
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
```

`wildwood` and `ember` stay exactly as in v2. The `Emblem()`/`Gem()` helpers must be defined above `Pathwise.Themes` in the same file.

---

## 4. Settings

- The Appearance section now has 13 theme buttons. Lay them out in a grid (e.g. 2 columns) instead of one long column so the panel doesn't overflow.
- `/pw theme` lists all 13 with numbers; `/pw theme <number|id>` and `/pw theme next` work for the new ids.
- If a saved theme id no longer exists, fall back to the default (already required by v1). No ids were removed in v3.

---

## 5. Done when

- [ ] All 14 new textures load after a **full WoW restart** (no green squares).
- [ ] On all 7 emblem themes, heads sit on the top corners facing outward on both sides; the head overlaps the corner, not floating away from it.
- [ ] Gems are centered on the bottom corners.
- [ ] Close button is not covered in any of the 13 themes.
- [ ] Old v2 files are deleted and nothing references `dragon_head`, `eagle_head`, `gem_ruby` or `gem_sapphire`.
- [ ] Cycling `/pw theme next` through all 13: no Lua errors, no leftover art, no memory growth.

## 6. Notes for Claude Code

- Don't edit or regenerate textures. If something sits slightly off in game, change only the `EMBLEM`/`GEM` numbers (or a theme's own `cornerArt` values).
- Keep everything in `UI/`.
- Remind the player to fully restart WoW so the new files are found.
