---
name: reef-popovers
description: >
  Create popovers in Reef-iOS that appear connected to a trigger button via an
  arrow, with neobrutalist styling and scale-from-trigger animation. Use when
  adding a new popover, dropdown, or floating panel anchored to a button in the
  Reef iPad app. Also use when modifying existing popovers or their positioning.
---

# Reef Popovers

## Key files

- `Reef-iOS/Reef/Design/Components/PopoverCard.swift` — reusable wrapper (arrow + card shell)
- `Reef-iOS/Reef/Design/Components/PopupShell.swift` — neobrutalist shell modifier (for reference)
- `Reef-iOS/Reef/Views/Canvas/DocumentCanvasView.swift` — reference implementation of positioning

## PopoverCard usage

Wrap content in `PopoverCard(arrowOffset:)`. The arrow points up at the trigger button.

```swift
PopoverCard(arrowOffset: arrowOffset) {
    MyPopoverContent()
}
```

- `arrowOffset` = horizontal offset of arrow tip from card center (0 = centered)
- Card has: white bg, 12pt corner radius, 2pt black stroke, 4pt 3D shadow
- Arrow: 16x8pt triangle, open-bottom stroke (merges with card border)
- Dark mode: reads `ThemeManager`, swaps to `DashboardDark` colors automatically

## Positioning pattern

Use `.overlay(alignment: .bottomLeading)` on the trigger's parent, with a `GeometryReader` to compute offsets. See [references/positioning.md](references/positioning.md) for the full pattern.

Key points:
1. Clamp card X to stay within screen bounds (12pt margin)
2. Compute `arrowOffset` so arrow still points at the button even when card is clamped
3. Apply `.transition()` to the `PopoverCard` itself, **before** `.offset(x:)` — never on the GeometryReader
4. Use `.zIndex()` on the overlay container to ensure popover renders above sibling views

## Animation

```swift
.transition(.scale(scale: 0.01, anchor: .top))
// on the parent:
.animation(.easeOut(duration: 0.2), value: showPopover)
```

- Scale from near-zero at `.top` anchor — looks like it expands from the button
- No opacity fade
- `easeOut` 200ms

## Tap-to-dismiss

Add a clear tap-to-dismiss layer as an `.overlay` on the content area below:

```swift
.overlay {
    if showPopover {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { showPopover = false }
    }
}
```

Do NOT dim the background for toolbar popovers.

## Content views

Popover content views should be plain `VStack` with padding — no background styling.
`PopoverCard` supplies the shell. Set `.frame(width:)` on the content to control card width,
and pass the same width as `popoverWidth` in the positioning calculation.
