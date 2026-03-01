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
            id: "tutor-orca",
            name: "Orca",
            emoji: "\u{1F40B}",
            species: "Orca Whale",
            subject: "Algebra & Equations",
            shortBio: "Orca breaks down complex equations into bite-sized steps, making algebra feel as natural as riding a wave.",
            funFact: "Orca whales are actually the largest member of the dolphin family — so Orca and Finn are technically cousins!",
            teachingStyle: "Patient and methodical. Orca walks you through each step, checking understanding before moving forward. Loves using real-world analogies to make abstract concepts click.",
            voiceDescription: "Warm & encouraging",
            introPhrase: "Hey there! I'm Orca. Let's dive into this problem together — one step at a time.",
            accentColor: "5B9EAD"
        ),
        Tutor(
            id: "tutor-otto",
            name: "Otto",
            emoji: "\u{1F419}",
            species: "Octopus",
            subject: "Geometry & Spatial Reasoning",
            shortBio: "With eight arms to point out angles, shapes, and proofs, Otto makes geometry visual and fun.",
            funFact: "Octopuses have three hearts and blue blood — Otto says that's triple the love for geometry!",
            teachingStyle: "Curious and exploratory. Otto encourages you to discover patterns on your own, asking guiding questions rather than giving answers right away.",
            voiceDescription: "Curious & playful",
            introPhrase: "Hi! I'm Otto — let's stretch our minds and see this problem from every angle!",
            accentColor: "E8A87C"
        ),
        Tutor(
            id: "tutor-coral",
            name: "Coral",
            emoji: "\u{1F980}",
            species: "Hermit Crab",
            subject: "Statistics & Data Analysis",
            shortBio: "Coral organizes messy data sets with care, helping you see the stories numbers are trying to tell.",
            funFact: "Hermit crabs swap shells when they outgrow them — Coral says that's basically upgrading your hypothesis!",
            teachingStyle: "Calm and methodical. Coral loves structure — expect clear definitions, organized steps, and gentle reminders to double-check your arithmetic.",
            voiceDescription: "Calm & methodical",
            introPhrase: "Hello! I'm Coral. Let's sort through this data together, nice and steady.",
            accentColor: "D4A5A5"
        ),
        Tutor(
            id: "tutor-finn",
            name: "Finn",
            emoji: "\u{1F42C}",
            species: "Dolphin",
            subject: "Calculus & Functions",
            shortBio: "Finn loves the thrill of limits, derivatives, and integrals — and makes sure you feel that excitement too.",
            funFact: "Dolphins sleep with one eye open. Finn says that's how you should watch for tricky limit problems!",
            teachingStyle: "Energetic and upbeat. Finn celebrates small wins, keeps the momentum going, and loves challenge problems to push your understanding further.",
            voiceDescription: "Energetic & upbeat",
            introPhrase: "What's up! I'm Finn — ready to ride the curve? Let's make calculus click!",
            accentColor: "85C1E9"
        ),
    ]
}
