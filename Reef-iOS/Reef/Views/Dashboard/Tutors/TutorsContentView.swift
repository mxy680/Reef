import SwiftUI

// MARK: - Main View

struct TutorsContentView: View {
    @Bindable var viewModel: TutorsViewModel
    @Environment(\.layoutMetrics) private var metrics
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let dark = theme.isDarkMode
        return GeometryReader { geo in
            let availableHeight = geo.size.height
            // Reserve fixed space for header (~90pt) and section label (~30pt), dots (~30pt), paddings
            let fixedChrome: CGFloat = 180
            let flexHeight = max(0, availableHeight - fixedChrome)
            // Spotlight gets ~40% of flex space, carousel gets ~60%
            let spotlightHeight = flexHeight * 0.38
            let carouselHeight = flexHeight * 0.55

            VStack(spacing: 0) {
                headerRow
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)

                if viewModel.isLoading {
                    skeletonCarousel
                        .padding(.top, 24)
                    Spacer()
                } else if viewModel.tutors.isEmpty {
                    emptyState
                        .padding(.top, 40)
                    Spacer()
                } else {
                    // Spotlight hero
                    if let tutor = viewModel.activeTutor {
                        TutorSpotlightView(
                            tutor: tutor,
                            isSpeaking: viewModel.speakingTutorId == tutor.id,
                            onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) },
                            onStartSession: { /* placeholder */ },
                            avatarSize: min(spotlightHeight * 0.55, metrics.spotlightAvatarSize * 1.3)
                        )
                        .frame(maxHeight: spotlightHeight)
                        .id(viewModel.activeTutorId)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .animation(.spring(duration: 0.35), value: viewModel.activeTutorId)
                        .padding(.bottom, 16)
                    }

                    // Carousel section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CHOOSE YOUR TUTOR")
                            .font(.epilogue(11, weight: .bold))
                            .tracking(0.06 * 11)
                            .foregroundStyle(dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400)

                        tutorCarousel(cardHeight: carouselHeight * 0.85)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(metrics.contentPadding)
        .dashboardCard()
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - Header

    private var headerRow: some View {
        let dark = theme.isDarkMode
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tutors")
                    .font(.epilogue(24, weight: .black))
                    .tracking(-0.04 * 24)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.text : ReefColors.black)

                Spacer()

                // Find Your Tutor quiz button
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text("Find Your Tutor")
                        .font(.epilogue(14, weight: .bold))
                        .tracking(-0.04 * 14)
                }
                .foregroundStyle(ReefColors.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ReefColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(dark ? ReefColors.DashboardDark.border : ReefColors.black, lineWidth: 1.5)
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(dark ? ReefColors.DashboardDark.shadow : ReefColors.black)
                        .offset(x: 4, y: 4)
                )
                .compositingGroup()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.showQuiz = true
                    }
                }
                .accessibilityAddTraits(.isButton)
                .padding(.top, 4)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            }

            HStack(spacing: 10) {
                Text("Meet your AI study companions — tap a card to learn more.")
                    .font(.epilogue(14, weight: .medium))
                    .tracking(-0.04 * 14)
                    .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

                if let activeId = viewModel.activeTutorId,
                   let tutor = viewModel.tutors.first(where: { $0.id == activeId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text(tutor.name)
                            .font(.epilogue(12, weight: .bold))
                            .tracking(-0.04 * 12)
                    }
                    .foregroundStyle(Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonCarousel: some View {
        let dark = theme.isDarkMode
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(dark ? ReefColors.DashboardDark.subtle : ReefColors.gray100)
                        .frame(width: metrics.tutorCardWidth, height: metrics.tutorCardHeight)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Carousel

    private func tutorCarousel(cardHeight: CGFloat) -> some View {
        let dark = theme.isDarkMode
        // Clamp card height to reasonable bounds
        let clampedHeight = max(200, min(cardHeight, 340))
        // Card width derived from height with aspect ratio
        let cardWidth = clampedHeight * 0.9

        return VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Array(viewModel.tutors.enumerated()), id: \.element.id) { index, tutor in
                        TutorCardView(
                            tutor: tutor,
                            index: index,
                            isSpeaking: viewModel.speakingTutorId == tutor.id,
                            isActive: viewModel.activeTutorId == tutor.id,
                            onTap: { withAnimation(.spring(duration: 0.3)) { viewModel.selectedTutor = tutor } },
                            onVoicePreview: { viewModel.toggleVoicePreview(for: tutor) },
                            onSelect: { viewModel.selectTutor(tutor) },
                            cardWidth: cardWidth,
                            cardHeight: clampedHeight
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }

            // Scroll hint dots
            HStack(spacing: 6) {
                ForEach(viewModel.tutors) { tutor in
                    Circle()
                        .fill(viewModel.activeTutorId == tutor.id
                              ? Color(hex: UInt(tutor.accentColor, radix: 16) ?? 0x5B9EAD)
                              : (dark ? ReefColors.DashboardDark.textDisabled : ReefColors.gray400).opacity(0.4))
                        .frame(width: viewModel.activeTutorId == tutor.id ? 8 : 6,
                               height: viewModel.activeTutorId == tutor.id ? 8 : 6)
                        .animation(.spring(duration: 0.25), value: viewModel.activeTutorId)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        let dark = theme.isDarkMode
        return VStack(spacing: 8) {
            Text("No tutors available")
                .font(.epilogue(15, weight: .semiBold))
                .tracking(-0.04 * 15)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textSecondary : ReefColors.gray600)

            Text("Check back soon — new tutors are on the way!")
                .font(.epilogue(13, weight: .medium))
                .tracking(-0.04 * 13)
                .foregroundStyle(dark ? ReefColors.DashboardDark.textMuted : ReefColors.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
