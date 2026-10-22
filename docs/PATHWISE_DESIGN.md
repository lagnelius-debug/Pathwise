# Pathwise — Design Document

> A World of Warcraft addon that follows your character's progression and tells you what to do next: which gear is an upgrade, which quest reward to pick, where to spend talent points, when to visit your trainer.
>
> **Target:** WoW Classic Era (vanilla 1–60) first. Port to **World of Warcraft: Forever** after it launches (November 4, 2026).
> **Test character:** Night Elf Hunter, starting at level 1 in Shadowglen (Teldrassil).
> **Slash commands:** `/pathwise` and `/pw`

---

## 1. Goals

1. **Automatic.** The addon detects class, race, level, talents, gear and professions by itself. The player never has to configure who they are.
2. **Useful from level 1.** Every feature in the first version should be testable while leveling a fresh character.
3. **Portable.** One codebase for Classic Era now and WoW: Forever later. Only a thin platform layer differs between the two.
4. **Data-driven.** All game knowledge (stat weights, talent builds, spell levels, later quests) lives in data tables, separate from logic. Adding a class = adding data, not code.
5. **Quiet and lightweight.** Helpful nudges, not spam. No noticeable performance cost.

### Non-goals (for now)
- No full quest routing guide (that comes later — see §9).
- No automation of gameplay (no auto-equip, no auto-accept, no auto-rolling). Pathwise only *recommends*.
- No external libraries in the first version (plain Lua + WoW API). Ace3 or similar can be considered later if needed.

---

## 2. Architecture

The addon is split into three layers. **This split is the most important rule in the project.**

```
┌──────────────────────────────────────────────┐
│ UI          (tooltips, popups, next-steps    │
│              panel, settings, slash cmds)    │
├──────────────────────────────────────────────┤
│ Core logic  (gear scoring, talent advisor,   │
│              trainer check, hunter module)   │  ← never calls WoW API directly
├──────────────────────────────────────────────┤
│ Data        (stat weights, talent builds,    │  ← plain Lua tables, per game flavor
│              class spells by level, ...)     │
├──────────────────────────────────────────────┤
│ Platform    (Platform_Classic.lua,           │  ← the ONLY place that calls game-
│              later Platform_Forever.lua)     │     version-specific WoW API
└──────────────────────────────────────────────┘
```

- **Core logic** asks the platform layer questions like `Platform.GetEquippedItems()`, `Platform.GetTalentPoints()`, `Platform.GetUnspentTalentPoints()`, `Platform.GetAmmoCount()`. It never calls `GetTalentInfo`, `UnitCharacterPoints` etc. itself.
- **Platform files** wrap the WoW API and return data in Pathwise's own simple formats (plain tables).
- **TOC files per flavor** load the right platform + data files:
  - `Pathwise_Vanilla.toc` → Classic Era
  - `Pathwise_Forever.toc` (or `_Camelot.toc`) → WoW: Forever, added later. During the Forever beta the TOC suffix was `_Camelot` with `Forever` accepted as an alias and interface number 16001. **Verify all of this against the live client at launch.**

### Folder structure

```
Pathwise/
├── Pathwise_Vanilla.toc
├── Core/
│   ├── Init.lua            -- namespace, saved variables, event dispatcher, debug print
│   ├── Character.lua       -- character tracker (snapshot of the player)
│   ├── GearScore.lua       -- item scoring and upgrade comparison
│   ├── QuestRewards.lua    -- quest reward recommendation
│   ├── Trainer.lua         -- "new spells available" check
│   ├── Talents.lua         -- spec detection + next talent point advice
│   └── NextSteps.lua       -- collects recommendations from all modules
├── Classes/
│   └── Hunter.lua          -- hunter-only module (ammo, pet, taming quest)
├── Platform/
│   └── Platform_Classic.lua
├── Data/
│   └── Classic/
│       ├── StatWeights.lua
│       ├── TalentBuilds.lua
│       └── ClassSpells.lua
├── UI/
│   ├── Tooltip.lua
│   ├── QuestRewardUI.lua
│   ├── NextStepsFrame.lua
│   └── Settings.lua
└── Locales/
    └── enUS.lua
```

### Saved variables
- `PathwiseDB` — account-wide settings (enabled modules, UI position, etc.).
- `PathwiseCharDB` — per-character state (chosen goal/spec, dismissed reminders, last snapshot).

---

## 3. Character tracker (`Core/Character.lua`)

Builds and maintains a snapshot of the player:

| Field | Source (Classic Era) |
|---|---|
| class (token, e.g. `HUNTER`) | `UnitClass("player")` |
| race, faction | `UnitRace`, `UnitFactionGroup` |
| level, XP, rested XP | `UnitLevel`, `UnitXP`, `UnitXPMax`, `GetXPExhaustion` |
| equipped items | `GetInventoryItemLink("player", slot)` |
| talent points per tree | talent tab/talent info functions |
| unspent talent points | `UnitCharacterPoints("player")` (verify) |
| professions / weapon skills | skill line functions |
| current zone | `GetRealZoneText` / map API |

**Events to listen to:** `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`, `PLAYER_XP_UPDATE`, `PLAYER_EQUIPMENT_CHANGED`, `CHARACTER_POINTS_CHANGED`, `SKILL_LINES_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `BAG_UPDATE_DELAYED`.

After each update, modules are notified so they can refresh their recommendations (simple internal callback system in `Init.lua`).

`/pw status` prints the snapshot to chat — used for testing.

---

## 4. Spec detection (`Core/Talents.lua`)

Classic Era has no formal spec choice, so Pathwise infers it:

1. If the player has spent talent points: the tree with the most points is the spec. If two trees are close (e.g. within 3 points), treat it as a hybrid and use the player's chosen goal (below).
2. Below level 10, or when unclear: show a **one-time prompt** asking for a goal — *Leveling / Tank / Healer / Damage* — and store it in `PathwiseCharDB`. For a hunter, the options are the leveling build plus the three trees.
3. The player can change the goal anytime in settings or with `/pw spec`.

The detected spec selects which stat weights and talent build are used.

---

## 5. MVP features

### 5.1 Gear advisor (`Core/GearScore.lua`, `UI/Tooltip.lua`)
- Score = Σ (stat × weight) for the current class/spec, using `GetItemStats` (stat keys like `ITEM_MOD_AGILITY_SHORT` are locale-independent — use them, never parse tooltip text).
- Weapons additionally score on DPS. **For hunters, the ranged weapon slot is weighted heavily**; the melee weapon is mostly a stat stick.
- Usability check: armor type the class can wear (hunter: cloth/leather until 40, then mail), weapon types the class can use, level requirement.
- Compare against the currently equipped item in the same slot (for rings/trinkets/one-handers: compare to the weaker of the two).
- **Tooltip line:** e.g. `Pathwise: ▲ +12% upgrade` (green) / `▼ −5%` (red) / `Not usable` (grey). Item scores should be cached per item link.
- Tooltip hooking: use `TooltipDataProcessor.AddTooltipPostCall` if it exists in the client, otherwise `GameTooltip:HookScript("OnTooltipSetItem", ...)`. Check at runtime.

### 5.2 Quest reward picker (`Core/QuestRewards.lua`, `UI/QuestRewardUI.lua`)
- On `QUEST_COMPLETE`, read the reward choices (`GetNumQuestChoices`, `GetQuestItemLink("choice", i)`).
- Recommend the biggest upgrade. If none is an upgrade, recommend the one with the **highest vendor sell price** (from item info) and say so.
- Show it with a highlight/glow on the reward button plus a short text line (e.g. "Pathwise: Best upgrade" / "Pathwise: Best to sell"). Never auto-select.
- Item info may not be cached the first time — handle `GET_ITEM_INFO_RECEIVED` and re-evaluate.

### 5.3 Trainer reminder (`Core/Trainer.lua`)
- Data table of class spells and the level each rank becomes available (`Data/Classic/ClassSpells.lua`).
- On level up (and login), check which of those spells/ranks the player doesn't know yet (`IsSpellKnown` / `IsPlayerSpell` — verify which works best in Classic Era).
- If any are available: one chat message + entry in the Next Steps panel: "New spells available at your trainer: Serpent Sting (Rank 2), …". Don't repeat after it's been shown, until the next level.

### 5.4 Talent advisor (`Core/Talents.lua`)
- Talent builds are stored as ordered lists: point 1 → talent X, point 2 → talent Y, …
- When the player has unspent points: "Next talent point: Improved Aspect of the Hawk (2/5)".
- If the player's spent points deviate from the build, don't nag — find the next talent in the build that isn't maxed yet and suggest that.
- Hunter builds to provide first: **Beast Mastery (leveling, default)** and **Marksmanship**.

### 5.5 Hunter module (`Classes/Hunter.lua`) — loaded only when class is `HUNTER`
- **Ammo warning:** check ammo count (ammo slot is inventory slot 0 in Classic — verify) on `BAG_UPDATE_DELAYED` / `UNIT_INVENTORY_CHANGED`. Warn below a threshold (default 200, configurable) and again critically (default 50).
- **Pet happiness:** read pet happiness (`GetPetHappiness`). If the pet is content/unhappy, remind the player to feed it, and list what it eats (`GetPetFoodTypes`).
- **Taming quest reminder:** at level 10, remind the player to visit their hunter trainer for the pet-taming quest.

### 5.6 Next Steps panel (`Core/NextSteps.lua`, `UI/NextStepsFrame.lua`)
- A small movable window (toggle with `/pw`) listing current recommendations from all modules, highest priority first:
  - "Spend 1 talent point → Improved Aspect of the Hawk"
  - "Visit trainer: 2 new spells"
  - "Low ammo: 140 arrows left"
  - "Feed your pet"
- Each module registers items with a priority and an ID; items disappear when resolved.
- Position saved in `PathwiseDB`.

### 5.7 Settings & commands
- Settings panel: enable/disable each module, ammo thresholds, chat messages on/off. Use the modern `Settings` API if present in the client, otherwise the legacy interface options — check at runtime.
- Commands:
  - `/pw` — toggle Next Steps panel
  - `/pw status` — print character snapshot
  - `/pw spec` — change goal/spec
  - `/pw score` — print score of currently equipped items (debug)
  - `/pw debug` — toggle debug output
  - `/pw reset` — reset settings

---

## 6. Data files

All data is plain Lua tables. Every entry that hasn't been verified in game gets a `-- TODO verify` comment.

### `StatWeights.lua`
Per class → per spec → weights. **The values below are placeholder starting points, to be tuned during testing:**

```lua
Pathwise.Data.StatWeights = {
  HUNTER = {
    LEVELING = {
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.45,
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 0.25,
      ITEM_MOD_SPIRIT_SHORT = 0.1,
      ITEM_MOD_STRENGTH_SHORT = 0.05,
      RANGED_WEAPON_DPS = 3.0,   -- custom key, ranged weapon DPS weighted heavily
      MELEE_WEAPON_DPS = 0.2,    -- custom key, melee is mostly a stat stick
    },
    -- BEAST_MASTERY, MARKSMANSHIP, SURVIVAL to follow
  },
}
```

### `TalentBuilds.lua`
Per class → named builds → ordered list of `{ tree, talentName, rank }`. Fill in hunter BM leveling and MM from a trusted Classic Era source (e.g. Wowhead Classic or Icy Veins hunter guides) — talent names must match what the in-game API returns.

### `ClassSpells.lua`
Per class → list of `{ spellName, rank, level, spellID }`. Start with the hunter, levels 1–60. Source from Wowhead Classic; spell IDs are preferred over names for matching.

---

## 7. Development workflow

- **Install path (Classic Era):** `World of Warcraft/_classic_era_/Interface/AddOns/Pathwise/`
- **Interface number:** check in game with `/dump select(4, GetBuildInfo())` and put the result in the TOC. Don't guess.
- **Testing loop:** edit → `/reload` in game → test → report errors. Claude Code cannot run WoW; the player tests in game and reports back.
- **Errors:** enable Lua errors with `/console scriptErrors 1`, or install BugGrabber + BugSack for readable error logs. Paste full error text back to Claude Code.
- **Version control:** use git from the start. Commit after each milestone.
- **Code style:** one shared addon namespace (from `local addonName, Pathwise = ...`), no globals except saved variables, small files, comments where WoW API behavior is surprising.

---

## 8. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Skeleton: TOC, namespace, event dispatcher, saved variables, slash commands, debug print, Classic platform file | Addon loads without errors; `/pw debug` works |
| M1 | Character tracker + spec detection + goal prompt | `/pw status` shows correct class, level, gear, talents |
| M2 | Gear advisor + tooltip line | Hovering items shows sensible upgrade/downgrade for a hunter |
| M3 | Quest reward picker | Quest turn-ins highlight the best reward or best sell value |
| M4 | Trainer reminder | Leveling up announces new spells correctly |
| M5 | Talent advisor | From level 10, the next talent point is suggested correctly |
| M6 | Hunter module | Ammo, pet happiness and taming-quest reminders work |
| M7 | Next Steps panel + settings | All recommendations visible in one window; modules can be toggled |

Build in this order. Each milestone should be tested in game before starting the next.

---

## 9. Later (not in the first version)

1. **Quest advisor:** rank available quests by level fit, XP, reward value and distance. Needs a quest database — start with Teldrassil and Darkshore for the Night Elf hunter. Pathwise can also *record* quests it sees (giver, location, level, rewards) to help build its own data.
2. **Pet ability guide:** which beasts to tame to learn new ranks of pet abilities.
3. **Other classes:** stat weights, talent builds and spell lists for the remaining eight Classic classes. Framework already supports them.
4. **WoW: Forever port** (see §10).

---

## 10. WoW: Forever port notes

Known facts from the Forever beta (all must be re-verified at launch, Nov 4, 2026):

- Forever uses the **modern (Mainline / Midnight) UI architecture and API**, not the Classic API. Classic-era addon code does not load there.
- Midnight's addon restrictions ("secret" values, mostly combat-related) are active in Forever. Pathwise works out of combat, so it should be mostly unaffected — but verify every API it uses.
- The **old-style spec API globals are absent** in Forever. Spec/talent handling will need a new implementation in `Platform_Forever.lua`.
- Forever adds new quests, zones, gear, dungeons and revamped systems, so Classic data will be partly wrong. Use a separate `Data/Forever/` folder.
- Beta TOC suffix was `_Camelot` (with `Forever` accepted as alias), beta interface number 16001.

Port plan: write `Platform_Forever.lua` implementing the same functions as the Classic platform file, add `Pathwise_Forever.toc`, add `Data/Forever/`. Core logic and UI should need little or no change — if they do, that's a sign something leaked past the platform layer.

---

## 11. Notes for Claude Code

- Read this whole document before writing code. Start with **M0 + M1** only.
- Respect the layer split: any WoW API call outside `Platform/` or `UI/` is a bug (UI code may use frame/tooltip APIs).
- When unsure whether an API exists or behaves a certain way in Classic Era, check at runtime (`if C_Something and C_Something.Func then`) and say so in a comment, rather than assuming.
- Mark unverified data with `-- TODO verify`.
- Before publishing anywhere, confirm the name "Pathwise" is still free on CurseForge and Wago.
