//
//  UploadOptionsSheet.swift
//  Reef
//
//  Bottom sheet for upload options including assignment mode toggle
//

import SwiftUI

struct UploadOptionsSheet: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Binding var isPresented: Bool
    @State private var assignmentModeEnabled: Bool = false
    let urls: [URL]
    let onUpload: (Bool) -> Void  // Pass assignment mode selection

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var cardBackgroundColor: Color {
        Color.adaptiveCardBackground(for: effectiveColorScheme)
    }

    private var textFieldBackgroundColor: Color {
        effectiveColorScheme == .dark ? Color.deepOcean : Color.lightGrayBackground
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack {
                Spacer()

                // Bottom sheet content
                VStack(spacing: 0) {
                    // Header with drag indicator
                    VStack(spacing: 12) {
                        // Drag indicator
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 36, height: 5)
                            .padding(.top, 12)

                        Text("Upload Options")
                            .font(.quicksand(20, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    }
                    .padding(.bottom, 20)

                    // Content
                    VStack(spacing: 24) {
                        // File count info
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))

                            Text("\(urls.count) \(urls.count == 1 ? "file" : "files") selected")
                                .font(.quicksand(15, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(textFieldBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Assignment mode toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $assignmentModeEnabled) {
                                HStack(spacing: 12) {
                                    Image(systemName: "list.number")
                                        .font(.system(size: 20))
                                        .foregroundColor(assignmentModeEnabled ? .vibrantTeal : Color.adaptiveSecondary(for: effectiveColorScheme))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Assignment Mode")
                                            .font(.quicksand(16, weight: .semiBold))
                                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                                        Text("Extract individual problems for step-by-step solving")
                                            .font(.quicksand(13, weight: .regular))
                                            .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .vibrantTeal))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(textFieldBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            // Processing time warning when enabled
                            if assignmentModeEnabled {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                    Text("Takes 1-2 minutes to process")
                                        .font(.quicksand(12, weight: .regular))
                                }
                                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                                .padding(.leading, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        // Upload button
                        Button {
                            isPresented = false
                            onUpload(assignmentModeEnabled)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 16))
                                Text("Upload")
                                    .font(.quicksand(16, weight: .semiBold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.vibrantTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 20, y: -5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: assignmentModeEnabled)
    }
}

#Preview {
    UploadOptionsSheet(
        isPresented: .constant(true),
        urls: [URL(fileURLWithPath: "/test.pdf")],
        onUpload: { _ in }
    )
}
