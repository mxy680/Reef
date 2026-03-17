import SwiftUI

/// Reusable dropdown overlay that attaches to a trigger view.
///
/// The trigger view becomes tappable — tap opens the dropdown,
/// tap anywhere else dismisses it.
///
/// Usage:
/// ```swift
/// headerIcon("bell")
///     .reefDropdown(isPresented: $show) {
///         Text("Dropdown content")
///     }
/// ```
struct ReefDropdown<DropdownContent: View>: ViewModifier {
    @Environment(ReefTheme.self) private var theme
    @Binding var isPresented: Bool
    let alignment: Alignment
    let offset: CGSize
    let minWidth: CGFloat
    @ViewBuilder let dropdown: () -> DropdownContent

    func body(content: Content) -> some View {
        content
            // Tap trigger to toggle
            .contentShape(Rectangle())
            .onTapGesture {
                isPresented.toggle()
            }
            // Dismiss backdrop (only when open)
            .overlay(alignment: alignment) {
                if isPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .transition(.opacity)
                }
            }
            // Dropdown content
            .overlay(alignment: alignment) {
                if isPresented {
                    dropdownCard
                        .offset(x: offset.width, y: offset.height)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: unitPoint)),
                            removal: .opacity
                        ))
                }
            }
            .zIndex(isPresented ? 100 : 0)
            .animation(.easeInOut(duration: 0.2), value: isPresented)
    }

    private var dropdownCard: some View {
        let dark = theme.isDarkMode
        return dropdown()
            .background(theme.colors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(dark ? ReefColors.Dark.border : ReefColors.gray500, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(dark ? ReefColors.Dark.shadow : ReefColors.gray500)
                    .offset(x: 3, y: 3)
            )
            .fixedSize(horizontal: true, vertical: true)
            .frame(minWidth: minWidth, alignment: alignment == .topTrailing ? .trailing : .leading)
    }

    private var unitPoint: UnitPoint {
        switch alignment {
        case .topTrailing: .topTrailing
        case .topLeading: .topLeading
        case .bottomTrailing: .bottomTrailing
        case .bottomLeading: .bottomLeading
        default: .top
        }
    }
}

extension View {
    /// Attach a dropdown to this view. Tap the view to open, tap outside to dismiss.
    func reefDropdown<DropdownContent: View>(
        isPresented: Binding<Bool>,
        alignment: Alignment = .topTrailing,
        offset: CGSize = CGSize(width: 0, height: 48),
        minWidth: CGFloat = 200,
        @ViewBuilder content: @escaping () -> DropdownContent
    ) -> some View {
        modifier(ReefDropdown(
            isPresented: isPresented,
            alignment: alignment,
            offset: offset,
            minWidth: minWidth,
            dropdown: content
        ))
    }
}
