# Design Language: Kharis Church – Kharis Church official website

> Extracted from `https://kharis.org` on June 7, 2026
> 832 elements analyzed

This document describes the complete design language of the website. It is structured for AI/LLM consumption — use it to faithfully recreate the visual design in any framework.

## Color Palette

### Primary Colors

| Role | Hex | RGB | HSL | Usage Count |
|------|-----|-----|-----|-------------|
| Primary | `#fd7f20` | rgb(253, 127, 32) | hsl(26, 98%, 56%) | 14 |
| Secondary | `#6b34fa` | rgb(107, 52, 250) | hsl(257, 95%, 59%) | 52 |
| Accent | `#800654` | rgb(128, 6, 84) | hsl(322, 91%, 26%) | 21 |

### Neutral Colors

| Hex | HSL | Usage Count |
|-----|-----|-------------|
| `#7a7a7a` | hsl(0, 0%, 48%) | 855 |
| `#000000` | hsl(0, 0%, 0%) | 451 |
| `#ffffff` | hsl(0, 0%, 100%) | 149 |
| `#5f626a` | hsl(224, 5%, 39%) | 109 |
| `#32363d` | hsl(218, 10%, 22%) | 30 |
| `#8d8f93` | hsl(220, 3%, 56%) | 12 |
| `#babbc0` | hsl(230, 5%, 74%) | 2 |
| `#999999` | hsl(0, 0%, 60%) | 2 |
| `#3a4652` | hsl(210, 17%, 27%) | 1 |
| `#d2d2d2` | hsl(0, 0%, 82%) | 1 |
| `#202124` | hsl(225, 6%, 13%) | 1 |

### Background Colors

Used on large-area elements: `#ffffff`, `#f9fafe`

### Text Colors

Text color palette: `#000000`, `#7a7a7a`, `#6b34fa`, `#f9fafe`, `#fd7f20`, `#ffffff`, `#000002`, `#32363d`, `#800654`, `#8d8f93`

### Gradients

```css
background-image: radial-gradient(circle at 80% 3%, rgb(56, 167, 205), rgba(255, 255, 255, 0) 35%), radial-gradient(circle at 60% 60%, rgb(121, 23, 64), rgba(255, 255, 255, 0) 45%), radial-gradient(circle at 36% 65%, rgb(56, 167, 205), rgba(255, 255, 255, 0) 9%);
```

```css
background-image: linear-gradient(60deg, rgb(122, 122, 122) 0%, rgb(122, 122, 122) 100%);
```

### Full Color Inventory

| Hex | Contexts | Count |
|-----|----------|-------|
| `#7a7a7a` | text, border | 855 |
| `#000000` | text, border, background | 451 |
| `#ffffff` | background, text, border | 149 |
| `#5f626a` | text, border | 109 |
| `#6b34fa` | text, border | 52 |
| `#32363d` | text, border | 30 |
| `#800654` | text, border, background | 21 |
| `#fd7f20` | text, border, background | 14 |
| `#8d8f93` | text, border | 12 |
| `#141b38` | text, border | 10 |
| `#d6ddeb` | border | 5 |
| `#babbc0` | border | 2 |
| `#999999` | text, border | 2 |
| `#3a4652` | background | 1 |
| `#d2d2d2` | background | 1 |
| `#202124` | background | 1 |

## Typography

### Font Families

- **Maven Pro** — used for all (586 elements)
- **DM Sans** — used for body (133 elements)
- **Times** — used for body (101 elements)
- **themify** — used for body (3 elements)
- **uicore-icons** — used for body (1 elements)
- **Noto Sans** — used for body (1 elements)

### Type Scale

| Size (px) | Size (rem) | Weight | Line Height | Letter Spacing | Used On |
|-----------|------------|--------|-------------|----------------|---------|
| 50px | 3.125rem | 400 | 50px | normal | span, i |
| 42px | 2.625rem | 700 | 50.4px | -1.134px | h2 |
| 28px | 1.75rem | 300 | 25.2px | normal | span |
| 24px | 1.5rem | 700 | 28.8px | -0.648px | h3, span |
| 23px | 1.4375rem | 400 | 23px | normal | div, i |
| 18px | 1.125rem | 400 | 33.75px | normal | span |
| 17px | 1.0625rem | 400 | 31.875px | normal | body, div, nav, a |
| 16px | 1rem | 400 | 18.4px | normal | html, head, meta, link |
| 15px | 0.9375rem | 400 | 15px | normal | p, a, span, i |
| 14px | 0.875rem | 700 | 14px | normal | a, span, div |
| 13px | 0.8125rem | 400 | 0px | normal | div, a, img, span |
| 12px | 0.75rem | 700 | 76px | normal | a, span, em, div |
| 0px | 0rem | 400 | 0px | normal | div, span |

### Heading Scale

```css
h2 { font-size: 42px; font-weight: 700; line-height: 50.4px; }
h3 { font-size: 24px; font-weight: 700; line-height: 28.8px; }
h5 { font-size: 16px; font-weight: 400; line-height: 18.4px; }
```

### Body Text

```css
body { font-size: 17px; font-weight: 400; line-height: 31.875px; }
```

### Font Weights in Use

`400` (649x), `700` (179x), `900` (3x), `300` (1x)

## Spacing

**Base unit:** 2px

| Token | Value | Rem |
|-------|-------|-----|
| spacing-5 | 5px | 0.3125rem |
| spacing-15 | 15px | 0.9375rem |
| spacing-30 | 30px | 1.875rem |
| spacing-38 | 38px | 2.375rem |
| spacing-50 | 50px | 3.125rem |
| spacing-60 | 60px | 3.75rem |
| spacing-64 | 64px | 4rem |
| spacing-80 | 80px | 5rem |
| spacing-90 | 90px | 5.625rem |
| spacing-100 | 100px | 6.25rem |
| spacing-109 | 109px | 6.8125rem |
| spacing-130 | 130px | 8.125rem |
| spacing-150 | 150px | 9.375rem |
| spacing-250 | 250px | 15.625rem |

## Border Radii

| Label | Value | Count |
|-------|-------|-------|
| sm | 3px | 1 |
| md | 8px | 2 |
| lg | 12px | 6 |
| lg | 15px | 1 |
| xl | 18px | 1 |
| full | 50px | 6 |
| full | 100px | 2 |
| full | 850px | 6 |

## Box Shadows

**sm** — blur: 0px
```css
box-shadow: rgba(0, 0, 0, 0.02) 0px 0px 0px 1px, rgba(0, 0, 0, 0.04) 0px 2px 35px 0px;
```

**sm** — blur: 0px
```css
box-shadow: rgba(0, 0, 0, 0.5) 0px 0px 0px 0px;
```

**xs** — blur: 0px
```css
box-shadow: rgba(0, 0, 0, 0) 0px 1px 0px 0px;
```

**md** — blur: 10px
```css
box-shadow: rgba(0, 0, 0, 0.29) 0px 0px 10px 0px;
```

**md** — blur: 8px
```css
box-shadow: rgba(0, 0, 0, 0.1) 0px 8px 8px 0px;
```

**lg** — blur: 22px
```css
box-shadow: rgba(0, 0, 0, 0.4) 1px 0px 22px -9px;
```

**lg** — blur: 30px
```css
box-shadow: rgba(0, 0, 0, 0.18) 0px 0px 30px 0px;
```

## CSS Custom Properties

### Colors

```css
--sby-color-1: #141b38;
--sby-color-2: #696d80;
--sby-color-3: #434960;
--sby-color-4: #f3f4f5;
--sby-color-5: #9295a6;
--sby-color-6: #e6e6eb;
--sby-color-7: #fff;
--sby-color-8: #ced0d9;
--sby-color-9: #f9f9fa;
--wp--preset--color--black: #000000;
--wp--preset--color--cyan-bluish-gray: #abb8c3;
--wp--preset--color--white: #ffffff;
--wp--preset--color--pale-pink: #f78da7;
--wp--preset--color--vivid-red: #cf2e2e;
--wp--preset--color--luminous-vivid-orange: #ff6900;
--wp--preset--color--luminous-vivid-amber: #fcb900;
--wp--preset--color--light-green-cyan: #7bdcb5;
--wp--preset--color--vivid-green-cyan: #00d084;
--wp--preset--color--pale-cyan-blue: #8ed1fc;
--wp--preset--color--vivid-cyan-blue: #0693e3;
--wp--preset--color--vivid-purple: #9b51e0;
--wp-admin-theme-color: #3858e9;
--wp-admin-theme-color--rgb: 56,88,233;
--wp-admin-theme-color-darker-10: #2145e6;
--wp-admin-theme-color-darker-10--rgb: 33.0384615385,68.7307692308,230.4615384615;
--wp-admin-theme-color-darker-20: #183ad6;
--wp-admin-theme-color-darker-20--rgb: 23.6923076923,58.1538461538,214.3076923077;
--wp-admin-border-width-focus: 2px;
--evo_color_1: #202124;
--evo_color_2: #656565;
--evo_boxcolor_1: #f0f0f0;
--evo_linecolor_1: #d4d4d4;
--evo_color_link: #656565;
--evo_color_prime: #00aafb;
--evo_color_second: #fed584;
--evo_color_white: #ffffff;
--evo_color_green: #69c33b;
--evo_color_red: #ff5953;
--evo_ett_color: var(--evo_color_1);
--ett_dateblock_color: var(--evo_color_1);
--ett_title_color: var(--evo_color_1);
--ett_subtitle_color: var(--evo_color_1);
```

### Spacing

```css
--bdt-position-margin-offset: 0.0001px;
--wp--preset--font-size--small: 13px;
--wp--preset--font-size--medium: 20px;
--wp--preset--font-size--large: 36px;
--wp--preset--font-size--x-large: 42px;
--wp--preset--spacing--20: 0.44rem;
--wp--preset--spacing--30: 0.67rem;
--wp--preset--spacing--40: 1rem;
--wp--preset--spacing--50: 1.5rem;
--wp--preset--spacing--60: 2.25rem;
--wp--preset--spacing--70: 3.38rem;
--wp--preset--spacing--80: 5.06rem;
--evo-image-size: 120px;
```

### Typography

```css
--evo_font_1: 'Poppins', sans-serif;
--evo_font_2: 'Noto Sans',arial;
--evo_font_x: 'monospace';
--evo_font_weight: 800;
--fa-font-regular: normal 400 1em/1 'evo_FontAwesome';
--fa-font-solid: normal 900 1em/1 'evo_FontAwesome';
```

### Shadows

```css
--wp--preset--shadow--natural: 6px 6px 9px rgba(0, 0, 0, 0.2);
--wp--preset--shadow--deep: 12px 12px 50px rgba(0, 0, 0, 0.4);
--wp--preset--shadow--sharp: 6px 6px 0px rgba(0, 0, 0, 0.2);
--wp--preset--shadow--outlined: 6px 6px 0px -3px rgb(255, 255, 255), 6px 6px rgb(0, 0, 0);
--wp--preset--shadow--crisp: 6px 6px 0px rgb(0, 0, 0);
```

### Other

```css
--bdt-breakpoint-s: 640px;
--bdt-breakpoint-m: 960px;
--bdt-breakpoint-l: 1200px;
--bdt-breakpoint-xl: 1600px;
--bdt-leader-fill-content: '.';
--wp--preset--aspect-ratio--square: 1;
--wp--preset--aspect-ratio--4-3: 4/3;
--wp--preset--aspect-ratio--3-4: 3/4;
--wp--preset--aspect-ratio--3-2: 3/2;
--wp--preset--aspect-ratio--2-3: 2/3;
--wp--preset--aspect-ratio--16-9: 16/9;
--wp--preset--aspect-ratio--9-16: 9/16;
--wp--preset--gradient--vivid-cyan-blue-to-vivid-purple: linear-gradient(135deg,rgb(6,147,227) 0%,rgb(155,81,224) 100%);
--wp--preset--gradient--light-green-cyan-to-vivid-green-cyan: linear-gradient(135deg,rgb(122,220,180) 0%,rgb(0,208,130) 100%);
--wp--preset--gradient--luminous-vivid-amber-to-luminous-vivid-orange: linear-gradient(135deg,rgb(252,185,0) 0%,rgb(255,105,0) 100%);
--wp--preset--gradient--luminous-vivid-orange-to-vivid-red: linear-gradient(135deg,rgb(255,105,0) 0%,rgb(207,46,46) 100%);
--wp--preset--gradient--very-light-gray-to-cyan-bluish-gray: linear-gradient(135deg,rgb(238,238,238) 0%,rgb(169,184,195) 100%);
--wp--preset--gradient--cool-to-warm-spectrum: linear-gradient(135deg,rgb(74,234,220) 0%,rgb(151,120,209) 20%,rgb(207,42,186) 40%,rgb(238,44,130) 60%,rgb(251,105,98) 80%,rgb(254,248,76) 100%);
--wp--preset--gradient--blush-light-purple: linear-gradient(135deg,rgb(255,206,236) 0%,rgb(152,150,240) 100%);
--wp--preset--gradient--blush-bordeaux: linear-gradient(135deg,rgb(254,205,165) 0%,rgb(254,45,45) 50%,rgb(107,0,62) 100%);
--wp--preset--gradient--luminous-dusk: linear-gradient(135deg,rgb(255,203,112) 0%,rgb(199,81,192) 50%,rgb(65,88,208) 100%);
--wp--preset--gradient--pale-ocean: linear-gradient(135deg,rgb(255,245,203) 0%,rgb(182,227,212) 50%,rgb(51,167,181) 100%);
--wp--preset--gradient--electric-grass: linear-gradient(135deg,rgb(202,248,128) 0%,rgb(113,206,126) 100%);
--wp--preset--gradient--midnight: linear-gradient(135deg,rgb(2,3,129) 0%,rgb(40,116,252) 100%);
--evo_cl_b40: rgb(0 0 0 / 40%);
--evo_cl_b30: rgb(0 0 0 / 30%);
--evo_cl_b20: rgb(0 0 0 / 20%);
--evo_cl_b10: rgb(0 0 0 / 10%);
--evo_cl_b5: rgb(0 0 0 / 5%);
--evo_cl_w: rgb(256 256 256 / 100%);
--evo_cl_link: #2b97ed;
--evocg0: #f6f7f7;
--evocg5: #dcdcde;
--evocg10: #c3c4c7;
--evocg20: #a7aaad;
--evocg30: #8c8f94;
--evocg40: #787c82;
--evocg50: #646970;
--evocg60: #50575e;
--evocg70: #3c434a;
--evocg80: #2c3338;
--evocg90: #1d2327;
--evocg100: #101517;
--evoclg0: #ffffff;
--evoclg3: #fbfbfc;
--evoclg6: #f7f7f8;
--evoclg8: #f5f5f6;
--evoclg10: #f2f2f3;
--evoclg20: #e6e6e8;
--evoclg30: #dadadd;
--evoclg40: #ceced2;
--evoclg50: #c2c2c6;
--evoclg60: #b6b6bb;
--evoclg70: #aaaaaa;
--evoclg80: #9e9e9f;
--evoclg90: #929293;
--evoclg100: #858687;
--direction-multiplier: 1;
--page-title-display: block;
--fa-style-family-classic: 'evo_FontAwesome';
```

### Dependencies

```css
--evo_ett_color: --evo_color_1;
--ett_dateblock_color: --evo_color_1;
--ett_title_color: --evo_color_1;
--ett_subtitle_color: --evo_color_1;
```

### Semantic

```css
success: [object Object];
warning: [object Object];
error: [object Object];
info: [object Object];
```

## Breakpoints

| Name | Value | Type |
|------|-------|------|
| sm | 479px | max-width |
| sm | 480px | max-width |
| 568px | 568px | max-width |
| 569px | 569px | min-width |
| sm | 600px | min-width |
| sm | 639px | max-width |
| sm | 640px | min-width |
| sm | 650px | max-width |
| sm | 680px | max-width |
| md | 720px | max-width |
| md | 721px | min-width |
| md | 767px | max-width |
| md | 768px | min-width |
| md | 782px | min-width |
| md | 800px | max-width |
| 880px | 880px | max-width |
| 881px | 881px | min-width |
| 900px | 900px | max-width |
| 959px | 959px | max-width |
| lg | 960px | min-width |
| lg | 1024px | max-width |
| lg | 1025px | min-width |
| 1199px | 1199px | max-width |
| 1200px | 1200px | max-width |
| xl | 1300px | max-width |
| 2xl | 1599px | max-width |
| 2xl | 1600px | min-width |
| 99999px | 99999px | max-width |

## Transitions & Animations

**Easing functions:** `[object Object]`, `[object Object]`, `[object Object]`, `[object Object]`, `[object Object]`, `[object Object]`, `[object Object]`, `[object Object]`

**Durations:** `0.4s`, `0.2s`, `0.3s`, `0.45s`, `0.15s`, `0s`, `0.5s`, `0.35s`, `0.6s`, `0.25s`, `0.27s`, `0.1s`

### Common Transitions

```css
transition: all;
transition: 0.4s;
transition: 0.2s cubic-bezier(0.68, 0.01, 0.58, 0.75);
transition: opacity 0.3s cubic-bezier(0.165, 0.84, 0.44, 1), transform 0.4s cubic-bezier(0.1, 0.76, 0.37, 1.19);
transition: 0.45s cubic-bezier(0.23, 1, 0.32, 1);
transition: 0.3s 0.15s, background-color 0.15s 0.15s;
transition: 0.3s, background-color 0.15s;
transition: background 0.3s, border 0.3s, border-radius 0.3s, box-shadow 0.3s;
transition: 0.5s;
transition: background 0.3s, border-radius 0.3s, opacity 0.3s;
```

### Keyframe Animations

**sby-sk-scaleout**
```css
@keyframes sby-sk-scaleout {
  0% { transform: scale(0); }
  100% { opacity: 0; transform: scale(1); }
}
```

**fa-spin**
```css
@keyframes fa-spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(359deg); }
}
```

**bdt-spinner-rotate**
```css
@keyframes bdt-spinner-rotate {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(270deg); }
}
```

**bdt-spinner-dash**
```css
@keyframes bdt-spinner-dash {
  0% { stroke-dashoffset: 88px; }
  50% { stroke-dashoffset: 22px; transform: rotate(135deg); }
  100% { stroke-dashoffset: 88px; transform: rotate(450deg); }
}
```

**bdt-fade**
```css
@keyframes bdt-fade {
  0% { opacity: 0; }
  100% { opacity: 1; }
}
```

**bdt-scale-up**
```css
@keyframes bdt-scale-up {
  0% { transform: scale(0.9); }
  100% { transform: scale(1); }
}
```

**bdt-scale-down**
```css
@keyframes bdt-scale-down {
  0% { transform: scale(1.1); }
  100% { transform: scale(1); }
}
```

**bdt-slide-top**
```css
@keyframes bdt-slide-top {
  0% { transform: translateY(-100%); }
  100% { transform: translateY(0px); }
}
```

**bdt-slide-bottom**
```css
@keyframes bdt-slide-bottom {
  0% { transform: translateY(100%); }
  100% { transform: translateY(0px); }
}
```

**bdt-slide-left**
```css
@keyframes bdt-slide-left {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(0px); }
}
```

## Component Patterns

Detected UI component patterns and their most common styles:

### Buttons (9 instances)

```css
.button {
  background-color: rgb(253, 127, 32);
  color: rgb(255, 255, 255);
  font-size: 14px;
  font-weight: 700;
  padding-top: 18px;
  padding-right: 0px;
  border-radius: 12px;
}
```

### Cards (4 instances)

```css
.card {
  background-color: rgb(128, 6, 84);
  border-radius: 8px;
  box-shadow: rgba(0, 0, 0, 0.1) 0px 8px 8px 0px;
  padding-top: 0px;
  padding-right: 17px;
}
```

### Links (101 instances)

```css
.link {
  color: rgb(0, 0, 2);
  font-size: 12px;
  font-weight: 700;
}
```

### Navigation (11 instances)

```css
.navigatio {
  background-color: rgb(255, 255, 255);
  color: rgb(122, 122, 122);
  padding-top: 0px;
  padding-bottom: 0px;
  padding-left: 0px;
  padding-right: 0px;
  position: static;
  box-shadow: rgba(0, 0, 0, 0) 0px 1px 0px 0px;
}
```

### Footer (3 instances)

```css
.foote {
  color: rgb(122, 122, 122);
  padding-top: 0px;
  padding-bottom: 0px;
  font-size: 17px;
}
```

### Modals (2 instances)

```css
.modal {
  background-color: rgb(0, 0, 0);
  border-radius: 0px;
  padding-top: 0px;
  padding-right: 0px;
}
```

### Dropdowns (148 instances)

```css
.dropdown {
  background-color: rgb(255, 255, 255);
  border-radius: 0px;
  box-shadow: rgba(0, 0, 0, 0.02) 0px 0px 0px 1px, rgba(0, 0, 0, 0.04) 0px 2px 35px 0px;
  border-color: rgb(0, 0, 2);
  padding-top: 0px;
}
```

### Badges (2 instances)

```css
.badge {
  background-color: rgb(253, 127, 32);
  color: rgb(107, 52, 250);
  font-size: 15px;
  font-weight: 400;
  padding-top: 0px;
  padding-right: 0px;
  border-radius: 50%;
}
```

### Tooltips (1 instances)

```css
.tooltip {
  background-color: rgb(58, 70, 82);
  color: rgb(255, 255, 255);
  font-size: 12px;
  border-radius: 10px 10px 10px 0px;
  padding-top: 10px;
  padding-right: 12px;
  box-shadow: rgba(0, 0, 0, 0.29) 0px 0px 10px 0px;
}
```

### Switches (2 instances)

```css
.switche {
  border-radius: 0px;
  border-color: rgb(0, 0, 0);
}
```

## Component Clusters

Reusable component instances grouped by DOM structure and style similarity:

### Button — 7 instances, 1 variant

**Variant 1** (7 instances)

```css
  background: rgba(0, 0, 0, 0);
  color: rgb(122, 122, 122);
  padding: 0px 0px 0px 0px;
  border-radius: 0px;
  border: 0px none rgb(122, 122, 122);
  font-size: 17px;
  font-weight: 400;
```

### Button — 4 instances, 1 variant

**Variant 1** (4 instances)

```css
  background: rgba(0, 0, 0, 0);
  color: rgb(122, 122, 122);
  padding: 0px 0px 0px 0px;
  border-radius: 0px;
  border: 0px none rgb(122, 122, 122);
  font-size: 17px;
  font-weight: 400;
```

### Button — 4 instances, 1 variant

**Variant 1** (4 instances)

```css
  background: rgb(253, 127, 32);
  color: rgb(255, 255, 255);
  padding: 18px 40px 18px 40px;
  border-radius: 12px;
  border: 0px none rgb(255, 255, 255);
  font-size: 14px;
  font-weight: 700;
```

### Button — 4 instances, 1 variant

**Variant 1** (4 instances)

```css
  background: rgba(0, 0, 0, 0);
  color: rgb(255, 255, 255);
  padding: 0px 0px 0px 0px;
  border-radius: 0px;
  border: 0px none rgb(255, 255, 255);
  font-size: 14px;
  font-weight: 700;
```

### Button — 4 instances, 1 variant

**Variant 1** (4 instances)

```css
  background: rgba(0, 0, 0, 0);
  color: rgb(255, 255, 255);
  padding: 0px 0px 0px 0px;
  border-radius: 0px;
  border: 0px none rgb(255, 255, 255);
  font-size: 14px;
  font-weight: 700;
```

### Button — 1 instance, 1 variant

**Variant 1** (1 instance)

```css
  background: rgba(0, 0, 0, 0);
  color: rgb(122, 122, 122);
  padding: 0px 0px 0px 0px;
  border-radius: 0px;
  border: 0px none rgb(122, 122, 122);
  font-size: 17px;
  font-weight: 400;
```

### Button — 2 instances, 1 variant

**Variant 1** (2 instances)

```css
  background: rgb(253, 127, 32);
  color: rgb(255, 255, 255);
  padding: 18px 40px 18px 40px;
  border-radius: 12px;
  border: 0px none rgb(107, 52, 250);
  font-size: 14px;
  font-weight: 700;
```

### Button — 2 instances, 1 variant

**Variant 1** (2 instances)

```css
  background: rgba(0, 0, 0, 0);
  color: rgb(255, 255, 255);
  padding: 0px 0px 0px 0px;
  border-radius: 0px;
  border: 0px none rgb(255, 255, 255);
  font-size: 14px;
  font-weight: 700;
```

## Layout System

**0 grid containers** and **106 flex containers** detected.

### Container Widths

| Max Width | Padding |
|-----------|---------|
| 1280px | 0px |
| 1170px | 0px |
| 100% | 0px |
| 1062px | 0px |

### Flex Patterns

| Direction/Wrap | Count |
|----------------|-------|
| row/nowrap | 62x |
| column/nowrap | 16x |
| row/wrap | 28x |

**Gap values:** `25px`, `5px`

## Accessibility (WCAG 2.1)

**Overall Score: 100%** — 1 passing, 0 failing color pairs

### Passing Color Pairs

| Foreground | Background | Ratio | Level |
|------------|------------|-------|-------|
| `#ffffff` | `#202124` | 16.1:1 | AAA |

## Design System Score

**Overall: 79/100 (Grade: C)**

| Category | Score |
|----------|-------|
| Color Discipline | 92/100 |
| Typography Consistency | 50/100 |
| Spacing System | 85/100 |
| Shadow Consistency | 90/100 |
| Border Radius Consistency | 80/100 |
| Accessibility | 100/100 |
| CSS Tokenization | 100/100 |

**Strengths:** Tight, disciplined color palette, Well-defined spacing scale, Clean elevation system, Strong accessibility compliance, Good CSS variable tokenization

**Issues:**
- 6 font families — consider limiting to 2 (heading + body)
- 628 !important rules — prefer specificity over overrides
- 89% of CSS is unused — consider purging
- 11777 duplicate CSS declarations

## Gradients

**4 unique gradients** detected.

| Type | Direction | Stops | Classification |
|------|-----------|-------|----------------|
| radial | circle at 80% 3% | 2 | brand |
| radial | circle at 60% 60% | 2 | brand |
| radial | circle at 36% 65% | 2 | brand |
| linear | 60deg | 2 | brand |

```css
background: radial-gradient(circle at 80% 3%, rgb(56, 167, 205), rgba(255, 255, 255, 0) 35%);
background: radial-gradient(circle at 60% 60%, rgb(121, 23, 64), rgba(255, 255, 255, 0) 45%);
background: radial-gradient(circle at 36% 65%, rgb(56, 167, 205), rgba(255, 255, 255, 0) 9%);
background: linear-gradient(60deg, rgb(122, 122, 122) 0%, rgb(122, 122, 122) 100%);
```

## Z-Index Map

**16 unique z-index values** across 4 layers.

| Layer | Range | Elements |
|-------|-------|----------|
| modal | 9999,2147483647 | div.s.b.y._.l.i.g.h.t.b.o.x.O.v.e.r.l.a.y, div.s.b.y._.l.i.g.h.t.b.o.x, span.e.v.o.l.b.c.l.o.s.e |
| dropdown | 100,999 | a.s.b.y._.l.b.-.p.r.e.v, a.s.b.y._.l.b.-.n.e.x.t, div.u.i.c.o.r.e.-.b.a.c.k.-.t.o.-.t.o.p. .u.i.c.o.r.e.-.i.-.a.r.r.o.w. .u.i.c.o.r.e._.h.i.d.e._.m.o.b.i.l.e |
| sticky | 10,50 | ul.s.u.b.-.m.e.n.u, ul.s.u.b.-.m.e.n.u, ul.s.u.b.-.m.e.n.u |
| base | -1,5 | span.s.b.y._.p.l.a.y._.b.t.n._.b.g, a.b.d.t.-.d.u.a.l.-.b.u.t.t.o.n.-.a. .b.d.t.-.e.p.-.b.u.t.t.o.n. .b.d.t.-.e.p.-.b.u.t.t.o.n.-.e.f.f.e.c.t.-.a. .b.d.t.-.e.p.-.b.u.t.t.o.n.-.s.i.z.e.-.x.s, div.b.d.t.-.e.p.-.b.u.t.t.o.n.-.t.e.x.t |

**Issues:**
- [object Object]

## SVG Icons

**1 unique SVG icons** detected. Dominant style: **filled**.

| Size Class | Count |
|------------|-------|
| xl | 1 |

**Icon colors:** `currentColor`, `rgb(0, 0, 0)`

## Font Files

| Family | Source | Weights | Styles |
|--------|--------|---------|--------|
| evo_FontAwesome | self-hosted | 400, 900 | normal |
| evo_FontAwesomeB | self-hosted | 400 | normal |
| eicons | self-hosted | 400 | normal |
| Font Awesome 5 Brands | self-hosted | 400 | normal |
| Font Awesome 5 Free | self-hosted | 400, 900 | normal |
| uicore-icons | self-hosted | 400 | normal |
| DM Sans | self-hosted | 100, 200, 300, 400, 500, 600, 700, 800, 900 | italic, normal |
| Maven Pro | self-hosted | 400, 500, 600, 700, 800, 900 | normal |
| themify | self-hosted | normal | normal |
| Noto Sans | google-fonts | 400, 700 | italic, normal |
| Poppins | cdn | 700, 800, 900 | normal |

**Google Fonts URL:** `https://fonts.googleapis.com/`

## Image Style Patterns

| Pattern | Count | Key Styles |
|---------|-------|------------|
| thumbnail | 6 | objectFit: fill, borderRadius: 0px, shape: square |
| general | 2 | objectFit: fill, borderRadius: 0px, shape: square |
| gallery | 2 | objectFit: fill, borderRadius: 0px, shape: square |

**Aspect ratios:** 1:1 (5x), 21:9 (2x), 16:9 (1x), 3:2 (1x), 4.41:1 (1x)

## Motion Language

**Feel:** springy · **Scroll-linked:** yes

### Duration Tokens

| name | value | ms |
|---|---|---|
| `xs` | `100ms` | 100 |
| `sm` | `200ms` | 200 |
| `md` | `270ms` | 270 |
| `lg` | `450ms` | 450 |

### Easing Families

- **custom** (93 uses) — `cubic-bezier(0.68, 0.01, 0.58, 0.75)`, `cubic-bezier(0.4, 0, 0.21, 0.99)`
- **ease-out** (22 uses) — `cubic-bezier(0.165, 0.84, 0.44, 1)`, `cubic-bezier(0.23, 1, 0.32, 1)`, `cubic-bezier(0.24, 0.85, 0.58, 1)`
- **spring** (10 uses) — `cubic-bezier(0.1, 0.76, 0.37, 1.19)`
- **ease-in-out** (5 uses) — `ease`
- **linear** (1 uses) — `linear`

### Spring / Overshoot Easings

- `cubic-bezier(0.1, 0.76, 0.37, 1.19)`

### Keyframes In Use

| name | kind | properties | uses |
|---|---|---|---|
| `sby-sk-scaleout` | reveal | transform, opacity | 1 |
| `sby-sk-scaleout` | reveal | transform, opacity | 1 |
| `testalt4` | fade | background-position, opacity | 1 |
| `uicoreFadeIn` | fade | opacity | 2 |
| `uicoreFloat` | slide | transform | 1 |

## Component Anatomy

### button — 28 instances

**Slots:** label
**Variants:** link
**Sizes:** sm · xs · md

| variant | count | sample label |
|---|---|---|
| default | 24 | FASTING BOOKLET |
| link | 4 | FASTING BOOKLET |

## Brand Voice

**Tone:** friendly · **Pronoun:** you-only · **Headings:** Title Case (balanced)

### Top CTA Verbs

- **fasting** (5)
- **watch** (5)
- **donate** (5)
- **share** (5)
- **find** (5)
- **listen** (3)

### Button Copy Patterns

- "fasting booklet" (5×)
- "donate now" (5×)
- "share your testimony" (5×)
- "find a branch" (5×)
- "watch more messages" (3×)
- "listen to messages" (3×)
- "watch more messages
listen to messages" (2×)

### Sample Headings

> WELCOME TO KHARIS
> CHANGING THE WORLD WITH A TOUCH OF HIS GRACE
> June 2026 Corporate Fasting and Prayer
> Latest Messages
> Build God A House
> Testimonies
> This is an opportunity for you to give glory to God.

## Page Intent

**Type:** `landing` (confidence 0.29)

Alternates: legal (0.4)

## Section Roles

Reading order (top→bottom): nav → content → nav → hero → content → content → hero → content → hero → content → testimonials → content → footer → content → content → content → content → footer

| # | Role | Heading | Confidence |
|---|------|---------|------------|
| 0 | nav | — | 0.9 |
| 1 | content | WELCOME TO KHARIS | 0.3 |
| 2 | hero | June 2026 Corporate Fasting and Prayer | 0.85 |
| 3 | content | — | 0.3 |
| 4 | content | — | 0.3 |
| 5 | hero | Latest Messages | 0.4 |
| 6 | content | — | 0.3 |
| 7 | hero | Build God A House | 0.4 |
| 8 | content | Testimonies | 0.3 |
| 9 | testimonials | This is an opportunity for you to give glory to God. | 0.4 |
| 10 | content | — | 0.3 |
| 11 | footer | — | 0.95 |
| 12 | content | — | 0.3 |
| 13 | content | — | 0.3 |
| 14 | content | — | 0.3 |
| 15 | content | — | 0.3 |
| 16 | footer | — | 0.95 |
| 17 | nav | — | 0.9 |

## Material Language

**Label:** `flat` (confidence 0)

| Metric | Value |
|--------|-------|
| Avg saturation | 0.257 |
| Shadow profile | soft |
| Avg shadow blur | 0px |
| Max radius | 850px |
| backdrop-filter in use | no |
| Gradients | 4 |

## Imagery Style

**Label:** `photography` (confidence 0.383)
**Counts:** total 10, svg 1, icon 4, screenshot-like 0, photo-like 5
**Dominant aspect:** square-ish
**Radius profile on images:** square

## Quick Start

To recreate this design in a new project:

1. **Install fonts:** Add `Maven Pro` from Google Fonts or your font provider
2. **Import CSS variables:** Copy `variables.css` into your project
3. **Tailwind users:** Use the generated `tailwind.config.js` to extend your theme
4. **Design tokens:** Import `design-tokens.json` for tooling integration
