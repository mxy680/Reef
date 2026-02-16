//
//  Tutor.swift
//  Reef
//
//  AI tutor persona models — marine animal characters.
//

import SwiftUI

// MARK: - Preset Mode

struct TutorPresetMode: Identifiable, Equatable {
    let id: String
    let name: String
    let patience: Double
    let hintFrequency: Double
    let explanationDepth: Double
}

// MARK: - Tutor

struct Tutor: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let species: String
    let specialty: String
    let tagline: String
    let backstory: String
    let accentColor: Color
    let presetModes: [TutorPresetMode]
}

// MARK: - Catalog

enum TutorCatalog {
    static let allTutors: [Tutor] = [
        Tutor(
            id: "finn",
            name: "Finn",
            emoji: "🐬",
            species: "Dolphin",
            specialty: "Math & Physics",
            tagline: "Patient explanations with real-world analogies",
            backstory: "Finn grew up racing through coral-filled currents, calculating angles and trajectories for fun. Now this friendly dolphin uses real-world ocean physics — wave frequencies, buoyancy, tidal forces — to make abstract math feel as natural as swimming.",
            accentColor: .deepTeal,
            presetModes: defaultPresets
        ),
        Tutor(
            id: "coral",
            name: "Coral",
            emoji: "🐙",
            species: "Octopus",
            specialty: "Biology & Chemistry",
            tagline: "Guides you with questions, not answers",
            backstory: "With eight arms and a massive brain, Coral is the reef's master problem-solver. This wise octopus never hands you the answer — instead, they ask the perfect question at the perfect moment to guide you toward your own breakthrough.",
            accentColor: Color(hex: "C75B8E"),
            presetModes: defaultPresets
        ),
        Tutor(
            id: "shelly",
            name: "Shelly",
            emoji: "🐢",
            species: "Sea Turtle",
            specialty: "Study Skills",
            tagline: "Motivational, structured, and goal-oriented",
            backstory: "Shelly has crossed every ocean with patience and persistence. This ancient sea turtle knows that the secret to any long journey is steady habits — time-boxing, spaced repetition, and never giving up, one stroke at a time.",
            accentColor: Color(hex: "6B8E6B"),
            presetModes: defaultPresets
        ),
        Tutor(
            id: "pearl",
            name: "Pearl",
            emoji: "🪼",
            species: "Jellyfish",
            specialty: "Literature & History",
            tagline: "Storytelling-based explanations that stick",
            backstory: "Pearl drifts through the deep, glowing with stories from every era. This luminous jellyfish weaves historical events into epic narratives and turns literary themes into unforgettable character journeys — learning with Pearl means you never forget the plot.",
            accentColor: Color(hex: "9B7DB8"),
            presetModes: defaultPresets
        ),
        Tutor(
            id: "chip",
            name: "Chip",
            emoji: "🐡",
            species: "Pufferfish",
            specialty: "Computer Science",
            tagline: "Concise, logical, and hands-off",
            backstory: "Small but sharp, Chip communicates in clean, efficient bursts — like well-written code. This pufferfish gives you just enough to unblock yourself, prefers pseudocode over paragraphs, and trusts you to figure things out with minimal hand-holding.",
            accentColor: Color(hex: "5A7FA5"),
            presetModes: defaultPresets
        ),
    ]

    private static let defaultPresets: [TutorPresetMode] = [
        TutorPresetMode(id: "encouraging", name: "Encouraging", patience: 0.8, hintFrequency: 0.7, explanationDepth: 0.7),
        TutorPresetMode(id: "strict", name: "Strict", patience: 0.3, hintFrequency: 0.2, explanationDepth: 0.4),
        TutorPresetMode(id: "socratic", name: "Socratic", patience: 0.7, hintFrequency: 0.3, explanationDepth: 0.5),
        TutorPresetMode(id: "hands-off", name: "Hands-off", patience: 0.5, hintFrequency: 0.1, explanationDepth: 0.3),
    ]

    static func tutor(for id: String) -> Tutor? {
        allTutors.first { $0.id == id }
    }
}
