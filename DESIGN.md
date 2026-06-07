# Kharis Design System

> Every value below was extracted from computed styles on kharis.org.
> Do not invent colours, radii, or button styles. The website is the source of truth.

## Colour

### Brand Palette (from kharis.org)
| Token | Hex | RGB | Role |
|-------|-----|-----|------|
| orange | #FD7F20 | rgb(253, 127, 32) | Primary CTA. Every button on the website. |
| purple | #6B34FA | rgb(107, 52, 250) | Identity. Logo, social icons. Not for buttons. |
| magenta | #800654 | rgb(128, 6, 84) | Feature icons (50px icon-boxes). |

### Text Palette
| Token | Hex | Role |
|-------|-----|------|
| heading | #32363D | Section headings on light surfaces |
| body | #7A7A7A | Body copy, descriptions |
| muted | #999999 | Secondary metadata |
| near-black | #000002 | Nav links (DM Sans 12px bold uppercase) |
| white | #FFFFFF | Headings on dark surfaces, button text |

### Surface Palette
| Token | Hex | Role |
|-------|-----|------|
| page | #FFFFFF | Website default background |
| section-alt | #F9FAFE | Alternate section background |
| card | #FDFDFD | Card backgrounds, 15px radius, shadow |
| overlay | rgba(0,0,0,0.6) | Hero/banner overlays |
| dark | #0D0D0D | App dark mode background |
| elevated | #1A1A1A | Cards and sheets in dark mode |
| subtle | #252525 | Inputs and secondary surfaces in dark mode |

### Colour Strategy
Restrained. Tinted neutrals with one accent (orange) at CTA points. Purple reserved for identity marks only. No gradients on buttons. No glows. The church's warmth comes from content (photography, sermon artwork), not from surface effects.

## Typography

### Fonts
- **Headings**: Maven Pro (weights: 400, 500, 600, 700, 800)
- **Body**: DM Sans (weights: 400, 500, 600, 700)

### Scale (from kharis.org)
| Step | Size | Weight | Font | Usage |
|------|------|--------|------|-------|
| Display | 42px | 700 | Maven Pro | Page headings ("WELCOME TO KHARIS") |
| H2 | 24px | 700 | Maven Pro | Section subheads ("About Us", "Locations") |
| H3 | 18px | 600 | Maven Pro | Card titles, sermon names |
| Body | 17px | 400 | Maven Pro | Default body text |
| Nav | 12px | 700 | DM Sans | Navigation links (uppercase) |
| Caption | 14px | 400 | DM Sans | Metadata, timestamps |
| Overline | 11px | 600 | DM Sans | Labels, badges (uppercase, tracking) |

### Letter Spacing
- Display headings: -1.134px (tracking-tighter)
- Section headings: -0.648px
- Body and nav: normal

## Buttons

One button style. From kharis.org (all 6 CTAs identical):

```
background: #FD7F20 (solid, no gradient)
color: #FFFFFF
font-family: "Maven Pro", sans-serif
font-size: 14px
font-weight: 700
text-transform: uppercase
padding: 18px 40px
border-radius: 12px
border: none
box-shadow: none
letter-spacing: normal
```

There is no secondary/outline/ghost button on the website. For the app, derive secondary and ghost variants from the same family:
- Secondary: transparent background, 1px solid #FD7F20 border, #FD7F20 text
- Ghost: transparent background, #7A7A7A text, no border

## Radius

| Token | Value | Source |
|-------|-------|--------|
| button | 12px | All CTAs on kharis.org |
| card | 15px | Feature cards (box-shadow: 0 0 30px rgba(0,0,0,0.18)) |
| social | 50% | Social media icon circles |
| input | 8px | Derived for form fields |

## Shadows
| Token | Value | Source |
|-------|-------|--------|
| card | 0 0 30px rgba(0,0,0,0.18) | Feature cards on kharis.org |
| none | none | All buttons (no shadow on any CTA) |

## Motion
- Transitions: 200ms ease
- No bounce, no elastic
- Reduced motion: honour prefers-reduced-motion, degrade to instant

## Icons
- Feature icons: magenta (#800654) at 50px (from icon-box components on kharis.org)
- Social icons: purple (#6B34FA) foreground on orange (#FD7F20) circle background
- App navigation: outlined inactive, filled active (active state in orange #FD7F20)

## Absolute Bans (for this project)
- No gradient text
- No glassmorphism
- No AI-purple glows
- No em dashes
- No side-stripe borders
- No identical card grids
- No fake product screenshots
- No serif fonts
- No Inter font
- No teal/green (the old app's off-brand colour)
