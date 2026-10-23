# Pathwise — Window Themes Spec

> Add-on to `PATHWISE_DESIGN.md`. Adds a theme system so the player can choose between **8 window designs** for every Pathwise window (starting with the To-do / Next Steps window).
> The corner artwork is already made: white, tintable 128×128 32-bit TGA files in `Media/Themes/`. Previews of each texture are in `Docs/theme-previews/`.

---

## 1. What to build

1. A **theme registry** with the 8 themes in §3 (exact colors given).
2. A **skinning function** that applies a theme to a Pathwise window: background, frame border, inner trim line, header band, title colors, corner ornaments and the "current quest" highlight.
3. **Live switching:** changing theme re-skins every open Pathwise window immediately, no `/reload`.
4. **Player choice:**
   - Settings panel → "Appearance" section with one button per theme (name + two-color swatch). Clicking applies it immediately.
   - Slash commands: `/pw theme` (list themes with numbers and mark the active one), `/pw theme <number|id>` (set), `/pw theme next` (cycle).
   - Saved account-wide in `PathwiseDB.theme`. Default: `dragonflight`. Unknown saved id → fall back to default.

Layering (see main design doc): all of this is **UI code**. Theme data is flavor-independent and plain Lua, so it works unchanged on Classic Era and WoW: Forever.

### Files

```
Pathwise/
├── Media/Themes/                 -- provided textures (do not regenerate)
│   ├── corner_dragon.tga
│   ├── corner_eagle.tga
│   ├── corner_antlers.tga
│   ├── corner_feather_main.tga
│   ├── corner_feather_side.tga
│   ├── diamond.tga
│   ├── leaf.tga
│   └── crescent.tga
├── UI/ThemeData.lua              -- NEW: theme table (§3)
├── UI/Theme.lua                  -- NEW: registry, skinning, live switching
├── UI/NextStepsFrame.lua         -- use the theme system
└── UI/Settings.lua               -- add Appearance section
```

Load order in the TOC: `UI/ThemeData.lua`, then `UI/Theme.lua`, before any window file.

---

## 2. Window anatomy (all themes)

```
   ornament              ornament        ← corner textures, drawn OVER the border,
     ╲┌──────────────────────┐╱             partly outside the window
      │┌────────────────────┐│  ← outer frame border (frameWidth px, frame color)
      ││  PATHWISE          ││  ← inner trim line (1 px, trim color, trimInset px in)
      ││  To-do         [x] ││  ← header band (band color) with small label + title
      │├────────────────────┤│  ← 1 px divider (trim color)
      ││▌1 Webwood Venom [4]││  ← current quest: highlight (bg tint) or accent bar
      ││ 2 Fel Moss ...  [5]││
      ││ 4 quests  Teldrassil││  ← footer (muted color)
      │└────────────────────┘│
     ╱└──────────────────────┘╲
```

- **Width:** 340 px (UI units at scale 1). Height follows content.
- **Background + outer border:** `CreateFrame("Frame", name, parent, "BackdropTemplate")` (check `BackdropTemplateMixin` exists; it does in current Classic Era). `bgFile = "Interface\\Buttons\\WHITE8X8"`, `edgeFile = "Interface\\Buttons\\WHITE8X8"`, `edgeSize = theme.frameWidth`. Tint with `SetBackdropColor` / `SetBackdropBorderColor`. Exception: the `tooltip` theme uses Blizzard's tooltip art (see §3).
- **Inner trim line:** a child frame with the same backdrop approach (edge only, `edgeSize = 1`), inset `theme.trimInset` px from the outer edge on all sides. Skip when `trim` is nil.
- **Header band:** a texture across the top inside the border, `theme.band` color, height 52 px for themes with creature corners (title centered, 40 px side padding so ornaments don't cover text), 44 px otherwise (title left-aligned). A 1 px divider in `theme.divider` color under it.
- **Text:** use built-in fonts so it looks native: small uppercase label "PATHWISE" (`GameFontNormalSmall`, `theme.muted`), title "To-do" (`GameFontNormalLarge`, `theme.title`), objectives (`GameFontHighlightSmall`, `theme.text`), footer (`GameFontNormalSmall`, `theme.muted`).
- **Quest names and levels** keep WoW's difficulty colors. Use `GetQuestDifficultyColor(level)` when it exists (check at runtime), else fall back to: grey `#808080`, green `#40c040`, yellow `#ffd100`, orange `#ff8040`, red `#ff2020`.
- **Current quest row:** `theme.highlight = "fill"` → row background texture in `theme.highlightColor`; `theme.highlight = "bar"` → a 3 px vertical bar in `theme.ornament` color at the row's left edge.
- **Ornaments** live on a child frame with a higher frame level (parent level + 5), layer `"OVERLAY"`, so they draw over the border. Textures may extend outside the window; do not enable clipping.

### Textures

- Path: `"Interface\\AddOns\\Pathwise\\Media\\Themes\\<file>"` (no extension needed).
- All art is **pure white with alpha**: tint with `tex:SetVertexColor(r, g, b)`. Eyes on the dragon and eagle are transparent holes on purpose.
- Mirroring with `tex:SetTexCoord(left, right, top, bottom)`:
  - normal `(0, 1, 0, 1)` · flip horizontal `(1, 0, 0, 1)` · flip vertical `(0, 1, 1, 0)` · both `(1, 0, 1, 0)`.
- The creature art (dragon, eagle, antlers) is drawn for the **top-left** corner. Top-right = flipped horizontally.
- Feathers: the **center** of the texture is the window corner; the art fans up and to the left. Mirror for the other three corners.
- WoW only picks up **new** texture files after a full client restart (not `/reload`). A green square means a wrong path or unreadable file.
- Thin 1 px lines can blur at odd UI scales. Use `PixelUtil` helpers if they exist in the client (check at runtime); otherwise accept it.

### Ornament layouts

Offsets are `SetPoint` x/y (WoW: +y is up). Sizes in UI units.

| `corners` value | Top-left / top-right | Bottom-left / bottom-right |
|---|---|---|
| `"diamonds"` | `diamond`, 10×10, `CENTER` on the corner (0, 0) | same |
| `"none"` | — | — |
| `"brackets"` | two `WHITE8X8` lines per corner, 16×2 and 2×16, inside the corner (L-shape) | same, mirrored |
| `"dragon"` | `corner_dragon`, 50×50, `TOPLEFT` at (−20, 20); top-right: `TOPRIGHT` at (20, 20), flipped H | `diamond` 15×15 tinted **frame**, plus `diamond` 11×11 tinted **ornament** on top, both `CENTER` on the corner |
| `"eagle"` | `corner_eagle`, same placement as dragon | same gems as dragon |
| `"antlers"` | `corner_antlers`, same placement as dragon | `leaf`, 22×22, `CENTER` on the corner at (1, 1) / (−1, 1) |
| `"feathers"` | two layers, both 48×48, `CENTER` on the corner: `corner_feather_main` tinted **frame**, `corner_feather_side` tinted **ornament** | same, flipped V (bottom-left) and both (bottom-right) |

Extras:
- `gilded`: under the header, a horizontal rule (1 px, ornament color at 35% alpha) with a 6×6 `diamond` in the middle.
- `moonlit`: an 18×18 `crescent` in the header, left of the title, tinted `theme.ornament`.

Create every ornament texture **once** per window and just show/hide, tint and re-anchor them in `ApplyTheme`. No new textures on each switch.

---

## 3. Theme data — `UI/ThemeData.lua`

Use these exact values. Colors are hex strings; add a small `HexToRGB(hex)` helper (returns r, g, b in 0–1, plus optional alpha from a 4th argument).

```lua
local _, Pathwise = ...

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
```

Swatch colors for the settings buttons: `frame` (or `bg` when there is no frame) + `ornament`.

---

## 4. API — `UI/Theme.lua`

```lua
Pathwise.Theme.Get(id)                 -- theme table, falls back to default
Pathwise.Theme.GetActiveId()           -- from PathwiseDB.theme
Pathwise.Theme.SetActive(id)           -- save + re-skin all registered windows
Pathwise.Theme.CreateWindow(name, parent)  -- returns a skinned window with
                                           -- .header, .title, .label, .content, .footer
Pathwise.Theme.Apply(window, id)       -- (re)apply a theme to one window
Pathwise.Theme.Register(window)        -- CreateWindow does this automatically
```

The window exposes a function the content code calls to mark the current quest row (`window:SetHighlightRow(rowFrame)`), so highlight style stays a theme concern.

Window position and shown/hidden state are independent of the theme and stay in `PathwiseDB` as before.

---

## 5. Settings & commands

- **Appearance** section in the settings panel: 8 buttons in `Pathwise.ThemeOrder`, each showing the two-color swatch and the theme name; the active one has a gold (`#ffd100`) outline. Click → `SetActive`.
- `/pw theme` → prints e.g. `Pathwise themes: 1 Gilded Hairline, 2 Classic Tooltip, … 5 Dragonflight (active), …`
- `/pw theme 7` or `/pw theme wildwood` → sets it and prints `Theme: Wildwood`.
- `/pw theme next` → cycles.

---

## 6. Done when

- [ ] All 8 themes render on the To-do window and match the mockups (colors, border thickness, corners).
- [ ] Creature corners sit on the corners, overlapping the border, mirrored correctly on the right side; dragon/eagle eyes show as holes.
- [ ] Switching via settings and via `/pw theme` re-skins instantly with no Lua errors and no leftover ornaments from the previous theme.
- [ ] Choice survives `/reload` and relog, and applies to every character.
- [ ] No textures created on each switch (check memory doesn't grow when cycling `/pw theme next` many times).
- [ ] Quest names still use difficulty colors in every theme.

## 7. Notes for Claude Code

- Don't redraw or regenerate the textures; use the files in `Media/Themes/`.
- Remind the player to **fully restart WoW** the first time, so the new texture files load.
- Keep everything in `UI/`. No WoW API calls added to Core or Platform files for this feature.
- If an API used here is missing in Classic Era (`BackdropTemplate`, `PixelUtil`, `GetQuestDifficultyColor`), check at runtime and fall back, with a comment.
