# Reef Color Palette

Source: `Reef-iOS/Reef/Extensions/ReefColors.swift`

---

## Primary Colors (Light Mode)

| Name | Hex | RGB | Purpose |
|------|-----|-----|---------|
| softCoral | `#F9C1B6` | 249, 193, 182 | Primary accent, actions, highlights, CTA buttons |
| seafoam | `#C3DFDE` | 195, 223, 222 | Secondary accent, soft green |
| deepCoral | `#D4877A` | 212, 135, 122 | Pressed/contrast coral for emphasis |
| deepTeal | `#5B9E9B` | 91, 158, 155 | Links, icon accents, muted teal primary |

## Neutral Colors

| Name | Hex | RGB | Purpose |
|------|-----|-----|---------|
| charcoal | `#2B2B2B` | 43, 43, 43 | Headlines, body text |
| midGray | `#7A7A7A` | 122, 122, 122 | Secondary text |
| blushWhite | `#F9F5F6` | 249, 245, 246 | Page background, warm blush white |

## Card & Component Colors

| Name | Hex | RGB | Purpose |
|------|-----|-----|---------|
| cardBackground | `#FFFFFF` | 255, 255, 255 | Card background - pure white |
| thumbnailBackground | `#F9F5F6` | 249, 245, 246 | Thumbnail background |
| thumbnailBorder | `#2B2B2B` | 43, 43, 43 | Thumbnail border - charcoal retro outline |
| deleteRed | `#E07A5F` | 224, 122, 95 | Delete button red |
| deleteRedBackground | `#FDF2F0` | 253, 242, 240 | Delete button background - very light red tint |

## Semantic Aliases

| Name | Maps To | Purpose |
|------|---------|---------|
| reefPrimary | deepTeal | Primary semantic color |
| reefSecondary | deepTeal | Secondary semantic color |
| reefAccent | deepCoral | Accent semantic color |
| reefText | charcoal | Text semantic color |
| reefBackground | blushWhite | Background semantic color |

---

## Dark Mode Colors

| Name | Hex | RGB | Purpose |
|------|-----|-----|---------|
| warmDark | `#1A1418` | 26, 20, 24 | Dark mode background - warm darkness |
| warmDarkCard | `#251E22` | 37, 30, 34 | Dark mode card background - slightly lighter |
| warmWhite | `#F5F0EE` | 245, 240, 238 | Dark mode text - warm white for readability |
| brightSeafoam | `#D4EDEC` | 212, 237, 236 | Dark mode secondary - bright seafoam |
| brightTealDark | `#7CB8B5` | 124, 184, 181 | Dark mode accent - bright teal for links |

---

## Drawing Tool Colors

### Default Pen Colors

**Light Mode:** Black, Deep Teal (`#5B9E9B`), Red (`~#E63333`)
**Dark Mode:** White, Deep Teal (`#5B9E9B`), Red (`~#E63333`)

### Default Highlighter Colors

| Color | Hex | Purpose |
|-------|-----|---------|
| Yellow | `~#FFEB3B` | Primary highlight |
| Blue | `~#99CCFF` | Secondary highlight |
| Pink | `~#FF99CC` | Tertiary highlight |

Users can add up to 4 custom colors per tool (pen/highlighter) for a total of 7 each.

---

## Gradients

**reefWarm** — deepCoral → softCoral → seafoam (leading to trailing)

**reefWarmVertical** — deepCoral → softCoral → seafoam (bottom to top)

**reefCoral** — deepCoral → softCoral (leading to trailing)

**preAuthGradient (Adaptive)**
- Light: deepCoral → softCoral (top to bottom)
- Dark: brightTealDark → warmDark (top to bottom)

---

## Design System Summary

The Reef color system uses a **warm, approachable palette**:
- **Primary:** Deep Teal — interactive elements and primary actions
- **Accent:** Deep Coral / Soft Coral — emphasis and CTAs
- **Secondary:** Seafoam — supporting UI elements
- **Neutral:** Charcoal / Gray / White — text and backgrounds
- **Dark Mode:** Warm tones maintained throughout
