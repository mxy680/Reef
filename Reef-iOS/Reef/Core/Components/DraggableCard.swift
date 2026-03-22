import SwiftUI

/// A high-performance draggable card container.
/// Isolates drag state into a single wrapper so the content view's body
/// is NOT re-evaluated during drag — only the offset changes.
/// The content is rendered once and the offset is applied as a
/// geometry effect, not a layout change.
struct DraggableCard<Content: View>: View {
    @State private var position: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .offset(x: position.width + dragOffset.width,
                    y: position.height + dragOffset.height)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        // Use transaction to skip animations during drag
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        position.width += value.translation.width
                        position.height += value.translation.height
                        dragOffset = .zero
                    }
            )
    }
}
