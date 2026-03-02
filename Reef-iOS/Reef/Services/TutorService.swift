import Foundation

actor TutorService {
    static let shared = TutorService()

    func listTutors() async throws -> [Tutor] {
        // TODO: Swap with Supabase query when tutors table is ready
        // let response: [Tutor] = try await supabase
        //     .from("tutors")
        //     .select()
        //     .order("name", ascending: true)
        //     .execute()
        //     .value
        // return response

        return Self.seedTutors
    }

    // MARK: - Seed Data

    private static let seedTutors: [Tutor] = [
        Tutor(
            id: "tutor-kai",
            name: "Kai",
            emoji: "\u{1F40B}",
            species: "Orca Whale",
            shortBio: "Kai breaks down complex problems into bite-sized steps, making tough concepts feel as natural as riding a wave.",
            funFact: "Orca whales are actually the largest member of the dolphin family — so Kai and Finn are technically cousins!",
            teachingStyle: "Patient and methodical. Kai walks you through each step, checking understanding before moving forward. Loves using real-world analogies to make abstract concepts click.",
            voiceDescription: "Warm & encouraging",
            introPhrase: "Hey there! I'm Kai. Let's dive into this problem together — one step at a time.",
            accentColor: "5B9EAD"
        ),
        Tutor(
            id: "tutor-otto",
            name: "Otto",
            emoji: "\u{1F419}",
            species: "Octopus",
            shortBio: "With eight arms to juggle ideas, Otto helps you see problems from every angle and discover solutions on your own.",
            funFact: "Octopuses have three hearts and blue blood — Otto says that's triple the love for learning!",
            teachingStyle: "Curious and exploratory. Otto encourages you to discover patterns on your own, asking guiding questions rather than giving answers right away.",
            voiceDescription: "Curious & playful",
            introPhrase: "Hi! I'm Otto — let's stretch our minds and see this problem from every angle!",
            accentColor: "E8A87C"
        ),
        Tutor(
            id: "tutor-shelly",
            name: "Shelly",
            emoji: "\u{1F980}",
            species: "Hermit Crab",
            shortBio: "Shelly brings order to chaos, helping you organize your thinking and work through problems with care and precision.",
            funFact: "Hermit crabs swap shells when they outgrow them — Shelly says that's basically upgrading your problem-solving toolkit!",
            teachingStyle: "Calm and methodical. Shelly loves structure — expect clear definitions, organized steps, and gentle reminders to double-check your work.",
            voiceDescription: "Calm & methodical",
            introPhrase: "Hello! I'm Shelly. Let's work through this together, nice and steady.",
            accentColor: "D4A5A5"
        ),
        Tutor(
            id: "tutor-finn",
            name: "Finn",
            emoji: "\u{1F42C}",
            species: "Dolphin",
            shortBio: "Finn brings infectious energy to every problem, celebrating small wins and keeping the momentum going until it clicks.",
            funFact: "Dolphins sleep with one eye open. Finn says that's how you should watch for tricky problems!",
            teachingStyle: "Energetic and upbeat. Finn celebrates small wins, keeps the momentum going, and loves challenge problems to push your understanding further.",
            voiceDescription: "Energetic & upbeat",
            introPhrase: "What's up! I'm Finn — ready to crush this? Let's make it click!",
            accentColor: "85C1E9"
        ),
    ]
}
