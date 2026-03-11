import SwiftUI

struct DetailsSheet: View {
    let document: Document
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let dark = theme.isDarkMode
        VStack(alignment: .leading, spacing: 0) {
            Text(document.displayName)
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

            VStack(spacing: 12) {
                ForEach(rows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                            .font(.epilogue(13, weight: .semiBold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                        Spacer()

                        Text(row.value)
                            .font(.epilogue(13, weight: .semiBold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.top, 20)

            HStack {
                Spacer()

                ReefModalButton("Close", variant: .secondary) {
                    onClose()
                }
            }
            .padding(.top, 24)
        }
        .padding(32)
        .popupShell()
    }

    private var rows: [(label: String, value: String)] {
        let dateStr: String = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: document.createdAt) else {
                return document.createdAt
            }
            let display = DateFormatter()
            display.dateStyle = .long
            display.timeStyle = .short
            return display.string(from: date)
        }()

        return [
            ("Filename", document.filename),
            ("Status", document.status.rawValue.capitalized),
            ("Pages", document.pageCount.map(String.init) ?? "—"),
            ("Problems", document.problemCount.map(String.init) ?? "—"),
            ("Uploaded", dateStr),
            ("ID", document.id),
        ]
    }
}
