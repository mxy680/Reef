import Foundation

struct Tutor: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let species: String
    let shortBio: String
    let funFact: String
    let teachingStyle: String
    let voiceDescription: String
    let introPhrase: String
    let accentColor: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case species
        case shortBio = "short_bio"
        case funFact = "fun_fact"
        case teachingStyle = "teaching_style"
        case voiceDescription = "voice_description"
        case introPhrase = "intro_phrase"
        case accentColor = "accent_color"
    }
}
