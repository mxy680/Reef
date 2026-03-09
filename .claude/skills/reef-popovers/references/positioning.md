# Popover Positioning Pattern

Complete pattern for anchoring a PopoverCard below a toolbar button.

## State

Track the trigger button's global X midpoint and a boolean toggle:

```swift
@State private var showPopover = false
@State private var triggerMidX: CGFloat = 0
```

Capture `triggerMidX` using a `GeometryReader` on the button:

```swift
Button { ... }
    .background(GeometryReader { geo in
        Color.clear.onAppear {
            triggerMidX = geo.frame(in: .global).midX
        }
    })
```

## Overlay + GeometryReader

Place the popover as an overlay on the trigger's toolbar/container, aligned `.bottomLeading`
so it hangs below:

```swift
ToolbarView(...)
    .overlay(alignment: .bottomLeading) {
        if showPopover {
            GeometryReader { geo in
                let containerMinX = geo.frame(in: .global).minX
                let containerWidth = geo.size.width
                let popoverWidth: CGFloat = 190  // match content .frame(width:)
                let idealX = triggerMidX - containerMinX - popoverWidth / 2
                let clampedX = max(12, min(idealX, containerWidth - popoverWidth - 12))
                let arrowOffset = (triggerMidX - containerMinX) - (clampedX + popoverWidth / 2)

                PopoverCard(arrowOffset: arrowOffset) {
                    MyContent()
                }
                .transition(.scale(scale: 0.01, anchor: .top))
                .offset(x: clampedX)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    .animation(.easeOut(duration: 0.2), value: showPopover)
    .zIndex(2)
```

## Gotchas

- **Transition placement**: `.transition()` must go on `PopoverCard`, before `.offset(x:)`.
  If placed on the `GeometryReader`, the scale origin is the GR center (full toolbar width),
  causing asymmetric animation.
- **GeometryReader sizing**: Use `.fixedSize(horizontal: false, vertical: true)` so the GR
  takes the popover's intrinsic height instead of expanding to fill.
- **zIndex**: The overlay container needs `.zIndex(2)` (or higher than siblings) to render
  above adjacent views like step toolbars or content areas.
- **No opacity fade**: Use `.scale(scale: 0.01, anchor: .top)` alone — no `.combined(with: .opacity)`.
  The scale-from-zero already creates a clean appear/disappear without ghosting.
