# Kharis Design System

> This file documents the tokens the app actually ships. The source of truth is
> `app/lib/core/theme/` (`AppColors`, `KharisColors` via `context.kc`,
> `AppTypography`, `AppSpacing`, `AppRadius`, `AppShadows`, `kharisTheme`).
> If this file and the code disagree, the code wins and this file is wrong.
> Import everything through `package:kharis_app/core/theme/theme.dart`.

## Rules for screens

- Colours that change with light/dark mode come from `context.kc`, never from
  `AppColors.lightBg`, `AppColors.surfaceDark` or a hex literal.
- Text styles come from `AppTypography`. Never call `GoogleFonts.*` in a
  screen.
- One CTA style: solid gold (`kc.accent`) with gold ink (`kc.onAccent`). No
  gradients on buttons, no white text on gold.
- No em dashes in user-facing copy. UK spelling.

## Colour

### Brand (same in both themes, `AppColors`)

| Token | Hex | Role |
|-------|-----|------|
| `primary` | #5D3FD3 | Brand purple: logo, identity, avatar gradient start |
| `primaryDeep` | #451EBB | Deep purple: brand ink cards (Giving scripture card) |
| `secondary` / `gold` | #F8B537 | Gold: the CTA colour, active chips, progress |
| `onSecondary` / `goldInk` | #1A1205 | Ink on gold |
| `ink` | #0B0A10 | Dark base (splash, player, dark-mode background) |
| `danger` | #E11D48 | Destructive actions, form errors on light surfaces |
| `accentPink` | #F531B3 | Live badge, notification dot |
| `errorContainer` | #93000A | Error snackbar fill |

`AppColors.error` (#FFB4AB) is a dark-surface error tint; it is unreadable on
light backgrounds, so forms use `danger`.

### Theme-aware (`context.kc`, `KharisColors`)

| Token | Light | Dark | Role |
|-------|-------|------|------|
| `bg` | #FAF7F2 | #0B0A10 | Screen background |
| `surface` | #FFFFFF | #241F30 | Cards, sheets, dialogs |
| `surfaceAlt` | #F2EEE8 | #1E1E1E | Inset fills: inputs, search |
| `surfaceMuted` | #F0ECFF | #1C1826 | Inactive chips |
| `onBg` | #171717 | #F2EEF4 | Primary text and icons |
| `muted` | #8A8580 | #9B93B5 | Secondary text |
| `faint` | #A8A29B | #6E6A70 | Tertiary text |
| `divider` | 8% ink | 8% white | Hairlines |
| `outline` | 12% ink | #4A4451 | Borders on interactive elements |
| `chipBg` | #F0ECFF | #1C1826 | Icon-tile background |
| `onChip` | #5D3FD3 | #C6B4FF | Icon or link on `chipBg`, in-text links |
| `accent` | #F8B537 | #E0A32B | Gold CTA fill |
| `onAccent` | #1A1205 | #1A1205 | Text and icons on `accent` |
| `accentInk` | #8A5A06 | #F8B537 | Gold used as text or icon on `bg` |
| `scrim` | 55% ink | 70% ink | Modal and image overlays |

Snackbars are a fixed dark plate in both themes (`KharisColors.dark.surface`).

### Colour strategy

Warm neutral surfaces, brand purple for identity and links, gold only where a
member acts. Warmth comes from photography and sermon artwork, not surface
effects. No teal or green surfaces, no glows, no gradient buttons.

## Typography (`AppTypography`)

| Family | Builder | Use |
|--------|---------|-----|
| Bricolage Grotesque 700, tracking -0.015em | `display(size:)` | Screen titles, wordmark, sheet titles |
| Hanken Grotesk 400 to 800 | `ui(size:, weight:)` | Body, labels, buttons, list rows, navigation |
| Newsreader, often italic | `serif(size:, italic:)` | Scripture, taglines, devotional reading |

Named scale:

| Getter | Spec | Use |
|--------|------|-----|
| `displayLg` | Bricolage 48/56 | Hero display |
| `headlineLg` | Bricolage 32/40 | Large screen title |
| `headlineLgMobile` | Bricolage 28/36 | Screen title (Giving, sign in) |
| `titleMd` | Hanken 600 20/28 | Card title |
| `bodyLg` | Hanken 400 16/24 | Body |
| `bodySm` | Hanken 400 14/20 | Small body |
| `labelMd` | Hanken 600 12/16, +0.05em | Eyebrow labels |

Section eyebrows ("GIVING TO", "APP") are `ui(size: 11, weight: w700,
letterSpacing: 1.1)` in `kc.muted`.

## Buttons

- **Primary**: `ElevatedButton` with the theme defaults: `kc.accent` fill,
  `kc.onAccent` text, `AppRadius.button` (15), no elevation, Hanken 700.
  Pill-shaped variants use `AppRadius.pillBorder`.
- **Secondary**: `OutlinedButton`, transparent, `kc.outline` border,
  `kc.onBg` text.
- **Text link**: `TextButton` with `kc.accentInk` (gold) or `kc.onChip`
  (purple) text.
- **Destructive**: text in `AppColors.danger`.

## Radius (`AppRadius`)

| Token | Value | Use |
|-------|-------|-----|
| `card` / `cardBorder` | 18 | Cards, menu groups, dialogs |
| `button` / `buttonBorder` | 15 | CTAs |
| `input` / `inputBorder` | 15 | Text fields, search |
| `tile` / `tileBorder` | 13 | 40 to 44 px icon tiles, mini player |
| `lg` | 16 | Bottom sheets (inset, all corners) |
| `md` | 12 | Thumbnails |
| `pill` / `pillBorder` | 9999 | Chips, pill buttons |

## Spacing (`AppSpacing`)

`xs` 4, `sm` 12, `gutter` 16, `marginMobile` 20 (screen side margin), `md` 24,
`lg` 40, `xl` 64. Cards use 14 to 20 internal padding; groups are separated by
22.

## Elevation (`AppShadows`)

- `card`: `0 2px 12px rgba(30,20,60,.05)`, the only shadow on light cards.
- `miniPlayer`: `0 12px 30px rgba(0,0,0,.4)`.
- Buttons never have shadows.

## Components

- **Menu card** (More): `kc.surface`, `cardBorder`, `AppShadows.card`; rows are
  a 40 px tinted icon tile, Hanken 600 15 label, optional muted value, chevron
  (or an external-link glyph when the row leaves the app).
- **Bottom sheet**: inset 8 px from the screen edges, `kc.surface`,
  `AppRadius.lg`, 36x4 drag handle in `kc.outline`, Bricolage 18 title. See
  `add_to_playlist_sheet.dart` and `branch_picker_sheet.dart`.
- **Campus picker**: always `pickActiveBranch` (the shared sheet in
  `app/lib/shared/widgets/branch_picker_sheet.dart`), which persists via
  `setActiveBranch`.

## Motion

- 120 to 200 ms ease-out; press feedback scales to 0.97.
- No bounce, no elastic. Honour reduced motion.

## Icons

Material rounded/outlined icons. Inactive navigation uses `kc.muted`, active
uses `kc.accentInk`.

## Bans

- No gradient text or gradient buttons
- No glassmorphism or glows
- No em dashes in copy
- No side-stripe borders
- No teal or green surfaces
- No raw `GoogleFonts` calls or hex colours in screens
- No fake data (progress bars, history, counts) that is not backed by a source
