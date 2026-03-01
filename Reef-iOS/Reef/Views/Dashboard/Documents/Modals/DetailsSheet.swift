import SwiftUI

struct DetailsSheet: View {
    let document: Document
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(document.displayName)
                .font(.epilogue(20, weight: .black))
                .tracking(-0.04 * 20)
                .foregroundStyle(ReefColors.black)

            VStack(spacing: 12) {
                ForEach(rows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                            .font(.epilogue(13, weight: .semiBold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(ReefColors.gray600)

                        Spacer()

                        Text(row.value)
                            .font(.epilogue(13, weight: .semiBold))
                            .tracking(-0.04 * 13)
                            .foregroundStyle(ReefColors.black)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.top, 20)

            HStack {
                Spacer()

                Button {
                    onClose()
                } label: {
                    Text("Close")
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                        .foregroundStyle(ReefColors.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(ReefColors.gray100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ReefColors.black, lineWidth: 2)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ReefColors.black)
                                .offset(x: 4, y: 4)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
        }
        .padding(28)
        .presentationDetents([.medium])
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
