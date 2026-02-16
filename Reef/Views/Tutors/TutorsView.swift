//
//  TutorsView.swift
//  Reef
//
//  Tutors page — auto-scrolling marine animal carousel with profile cards.
//

import SwiftUI

struct TutorsView: View {
    let colorScheme: ColorScheme

    @StateObject private var selectionManager = TutorSelectionManager.shared

    @State private var isInitialLoad = true
    @State private var focusedTutorID: String?
    @State private var autoScrollTimer: Timer?
    @State private var isUserInteracting = false

    private let tutors = TutorCatalog.allTutors
    private let autoScrollInterval: TimeInterval = 4.0

    private var focusedTutor: Tutor {
        tutors.first { $0.id == focusedTutorID } ?? tutors[0]
    }

    private var cardBg: Color {
        Color.adaptiveCardBackground(for: colorScheme)
    }

    var body: some View {
        Group {
            if isInitialLoad {
                skeletonView
            } else {
                mainContent
            }
        }
        .onAppear {
            if focusedTutorID == nil {
                focusedTutorID = tutors[0].id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isInitialLoad = false
                }
            }
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero card
                heroCard

                // Info cards row
                HStack(alignment: .top, spacing: 16) {
                    infoCard(
                        icon: "quote.bubble.fill",
                        title: "Voice",
                        text: focusedTutor.voice,
                        tint: focusedTutor.accentColor
                    )
                    .id(focusedTutor.id + "-voice")

                    infoCard(
                        icon: "book.closed.fill",
                        title: "Lore",
                        text: focusedTutor.lore,
                        tint: focusedTutor.accentColor
                    )
                    .id(focusedTutor.id + "-lore")
                }

                // Fun fact card
                funFactCard

                // Carousel
                carouselSection
            }
            .padding(32)
            .animation(.easeInOut(duration: 0.3), value: focusedTutorID)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let tutor = focusedTutor
        let isActive = selectionManager.selectedTutorID == tutor.id

        let gradient = LinearGradient(
            colors: colorScheme == .dark
                ? [tutor.accentColor.opacity(0.7), tutor.accentColor.opacity(0.35)]
                : [tutor.accentColor.opacity(0.85), tutor.accentColor.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return VStack(spacing: 12) {
            Text(tutor.emoji)
                .font(.system(size: 56))
                .shadow(color: .black.opacity(0.15), radius: 8)
                .id(tutor.id + "-emoji")

            Text(tutor.name)
                .font(.dynaPuff(30, weight: .bold))
                .foregroundColor(.white)
                .id(tutor.id + "-name")

            Text("The \(tutor.species)")
                .font(.quicksand(15, weight: .semiBold))
                .foregroundColor(.white.opacity(0.85))

            Text(tutor.personality)
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)
                .id(tutor.id + "-personality")

            // Select button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isActive {
                        selectionManager.selectedTutorID = nil
                    } else {
                        selectionManager.selectTutor(tutor, preset: tutor.presetModes.first)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16))
                    Text(isActive ? "Active Tutor" : "Select as Active Tutor")
                        .font(.quicksand(15, weight: .semiBold))
                }
                .foregroundColor(isActive ? .white : Color.adaptiveText(for: colorScheme))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isActive ? Color.white.opacity(0.25) : Color.white)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Info Card

    private func infoCard(icon: String, title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.quicksand(16, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }

            Text(text)
                .font(.quicksand(13, weight: .regular))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBg)
        .dashboardCard(colorScheme: colorScheme)
    }

    // MARK: - Fun Fact Card

    private var funFactCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🧠")
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(
                    Color.deepTeal.opacity(colorScheme == .dark ? 0.15 : 0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("Did You Know?")
                    .font(.quicksand(14, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                Text(focusedTutor.funFact)
                    .font(.quicksand(13, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBg)
        .dashboardCard(colorScheme: colorScheme)
        .id(focusedTutor.id + "-funfact")
    }

    // MARK: - Carousel

    private var carouselSection: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tutors) { tutor in
                        TutorCardView(
                            tutor: tutor,
                            isFocused: tutor.id == focusedTutorID,
                            isActiveTutor: selectionManager.selectedTutorID == tutor.id,
                            colorScheme: colorScheme
                        )
                        .id(tutor.id)
                        .onTapGesture {
                            isUserInteracting = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                focusedTutorID = tutor.id
                            }
                            restartAutoScroll()
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedTutorID)
            .frame(height: 210)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in isUserInteracting = true }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUserInteracting = false
                        }
                    }
            )

            // Page dots
            HStack(spacing: 6) {
                ForEach(tutors) { tutor in
                    Circle()
                        .fill(tutor.id == focusedTutorID
                            ? Color.deepTeal
                            : Color.adaptiveSecondaryText(for: colorScheme).opacity(0.3))
                        .frame(width: tutor.id == focusedTutorID ? 8 : 5,
                               height: tutor.id == focusedTutorID ? 8 : 5)
                        .animation(.easeOut(duration: 0.2), value: focusedTutorID)
                }
            }
        }
    }

    // MARK: - Auto Scroll

    private func startAutoScroll() {
        stopAutoScroll()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            Task { @MainActor in
                guard !isUserInteracting else { return }
                advanceCarousel()
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func restartAutoScroll() {
        stopAutoScroll()
        DispatchQueue.main.asyncAfter(deadline: .now() + autoScrollInterval) {
            isUserInteracting = false
            startAutoScroll()
        }
    }

    private func advanceCarousel() {
        guard let currentID = focusedTutorID,
              let currentIndex = tutors.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIndex = (currentIndex + 1) % tutors.count
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            focusedTutorID = tutors[nextIndex].id
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero skeleton
                ZStack {
                    Color.adaptiveCardBackground(for: colorScheme)
                    SkeletonShimmerView(colorScheme: colorScheme)
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
                )

                // Info cards skeleton
                HStack(spacing: 16) {
                    skeletonInfoCard
                    skeletonInfoCard
                }

                // Fun fact skeleton
                skeletonInfoCard

                // Carousel skeleton
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        ZStack {
                            Color.adaptiveCardBackground(for: colorScheme)
                            SkeletonShimmerView(colorScheme: colorScheme)
                        }
                        .frame(width: 180, height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
                        )
                    }
                }
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    private var skeletonInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(width: 32, height: 32)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 60, height: 16)
            }
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                    .frame(height: 13)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                    .frame(height: 13)
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.04))
                        .frame(height: 13)
                    Spacer()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBg)
        .dashboardCard(colorScheme: colorScheme)
    }
}
