import SwiftUI

// MARK: - Page Menu Content (inside PopoverCard)

struct CanvasPageMenuContent: View {
    @Bindable var viewModel: CanvasViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow(systemIcon: "doc.fill.badge.plus", label: "Add Page to End") {
                viewModel.showPageMenu = false
            }
            menuRow(systemIcon: "doc.on.doc.fill", label: "Add Page After This") {
                viewModel.showPageMenu = false
            }
            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
            menuRow(systemIcon: "xmark.bin.fill", label: "Delete This Page", isDestructive: true) {
                viewModel.showPageMenu = false
            }
            menuRow(systemIcon: "trash.fill", label: "Delete All Pages", isDestructive: true) {
                viewModel.showPageMenu = false
            }
        }
        .padding(.vertical, 6)
        .frame(width: 230)
    }

    private func menuRow(
        systemIcon: String,
        label: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.epilogue(13, weight: .semiBold))
                    .tracking(-0.04 * 13)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundColor(isDestructive ? .red : ReefColors.black)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
