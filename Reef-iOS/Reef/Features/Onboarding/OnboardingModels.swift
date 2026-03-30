import Foundation

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome
    case studentType
    case major          // college/grad only
    case courses
    case favoriteTopic  // free response
    case studyGoal
    case goalValidation
    case painPoints
    case learningStyle
    case dailyGoal
    case tutorDemo
    case generatingPlan
    case planPreview
    case signUp
    case paywall
    case referral

    /// SF Symbol for the step icon shown above the card
    var icon: String {
        switch self {
        case .welcome: "bubble.left.and.text.bubble.right.fill"
        case .studentType: "graduationcap.fill"
        case .major: "building.columns.fill"
        case .courses: "books.vertical.fill"
        case .favoriteTopic: "lightbulb.fill"
        case .studyGoal: "target"
        case .goalValidation: "checkmark.seal.fill"
        case .painPoints: "bandage.fill"
        case .learningStyle: "brain.head.profile.fill"
        case .dailyGoal: "clock.fill"
        case .tutorDemo: "bubble.left.and.bubble.right.fill"
        case .generatingPlan: "waveform.circle.fill"
        case .planPreview: "list.clipboard.fill"
        case .signUp: "person.crop.circle.fill"
        case .paywall: "crown.fill"
        case .referral: "megaphone.fill"
        }
    }

    /// Whether this step uses OnboardingStepShell (vs custom layout)
    var usesShell: Bool {
        switch self {
        case .welcome, .goalValidation, .tutorDemo, .generatingPlan,
             .planPreview, .signUp, .paywall:
            return false
        default:
            return true
        }
    }
}

// MARK: - Enums

enum StudentType: String, Codable, Sendable, CaseIterable {
    case highSchool = "high_school"
    case college = "college"
    case graduate = "graduate"
    case other = "other"

    var displayLabel: String {
        switch self {
        case .highSchool: "High Schooler"
        case .college: "College Student"
        case .graduate: "Grad Student"
        case .other: "Something Else Entirely"
        }
    }
}

enum MajorField: String, Codable, Sendable, CaseIterable {
    case engineering = "engineering"
    case premed = "premed"
    case cs = "cs"
    case science = "science"
    case other = "other"

    var displayLabel: String {
        switch self {
        case .engineering: "Engineering"
        case .premed: "Pre-Med / Health"
        case .cs: "Computer Science"
        case .science: "Math / Science"
        case .other: "Other"
        }
    }
}

enum StudyGoal: String, Codable, Sendable, CaseIterable {
    case aceExams = "ace_exams"
    case understand = "understand"
    case saveTime = "save_time"
    case boostGPA = "boost_gpa"

    var displayLabel: String {
        switch self {
        case .aceExams: "Walk Into Exams Without Panicking"
        case .understand: "Actually Understand the Material"
        case .saveTime: "Stop Spending Forever on Homework"
        case .boostGPA: "Recover From Last Semester"
        }
    }

    var icon: String {
        switch self {
        case .aceExams: "🎯"
        case .understand: "🧠"
        case .saveTime: "⏰"
        case .boostGPA: "📈"
        }
    }
}

enum PainPoint: String, Codable, Sendable, CaseIterable {
    case procrastination = "procrastination"
    case confusingMaterial = "confusing_material"
    case noOneToAsk = "no_one_to_ask"
    case testAnxiety = "test_anxiety"
    case cantRetain = "cant_retain"
    case timeManagement = "time_management"

    var displayLabel: String {
        switch self {
        case .procrastination: "Procrastination Is My Entire Personality"
        case .confusingMaterial: "The Material Genuinely Doesn't Make Sense"
        case .noOneToAsk: "Office Hours? In This Economy?"
        case .testAnxiety: "I Know It Until the Test Hits"
        case .cantRetain: "I Forget Everything 5 Minutes Later"
        case .timeManagement: "Not Enough Hours in the Day"
        }
    }
}

enum LearningStyle: String, Codable, Sendable, CaseIterable {
    case visual = "visual"
    case auditory = "auditory"
    case handson = "handson"
    case reading = "reading"

    var displayLabel: String {
        switch self {
        case .visual: "Show Me, Don't Tell Me"
        case .auditory: "Just Explain It and I'll Get It"
        case .handson: "I Have to Try It Myself"
        case .reading: "Give Me the Textbook, I'll Figure It Out"
        }
    }

    var icon: String {
        switch self {
        case .visual: "👀"
        case .auditory: "👂"
        case .handson: "✍️"
        case .reading: "📖"
        }
    }
}

enum DailyGoalOption: Int, Codable, Sendable, CaseIterable {
    case thirty = 30
    case sixty = 60
    case threeHours = 180
    case twelve = 720

    var displayLabel: String {
        switch self {
        case .thirty: "30 min"
        case .sixty: "1 hour"
        case .threeHours: "3 hours"
        case .twelve: "12+ hours"
        }
    }

    var subtitle: String {
        switch self {
        case .thirty: "Quick dive"
        case .sixty: "Solid session"
        case .threeHours: "Deep dive"
        case .twelve: "You're in the deep end"
        }
    }
}

enum ReferralSource: String, Codable, Sendable, CaseIterable {
    case social = "social"
    case friend = "friend"
    case teacherSchool = "teacher_school"
    case mark = "mark"
    case other = "other"

    var displayLabel: String {
        switch self {
        case .social: "TikTok / Instagram"
        case .friend: "A Friend Told Me"
        case .teacherSchool: "Teacher or School"
        case .mark: "Mark Told Me to Download This"
        case .other: "Don't Remember"
        }
    }
}

// MARK: - Answers

struct OnboardingAnswers: Sendable {
    var studentType: StudentType?
    var majors: Set<MajorField> = []
    var courses: Set<String> = []
    var favoriteTopic: String = ""
    var studyGoal: StudyGoal?
    var painPoints: Set<PainPoint> = []
    var learningStyle: LearningStyle?
    var dailyGoal: DailyGoalOption?
    var referralSource: ReferralSource?
    var referralCode: String = ""
}

// MARK: - Course Lists

enum CourseCatalog {
    static func courses(for studentType: StudentType?, majors: Set<MajorField>) -> [String] {
        if majors.isEmpty {
            switch studentType {
            case .highSchool:
                return ["Algebra", "Geometry", "Precalculus", "Calculus", "Physics",
                        "Chemistry", "Biology", "Computer Science", "Statistics",
                        "Trigonometry"]
            default:
                return ["Math", "Science", "Economics", "Computer Science",
                        "Statistics", "Physics", "Chemistry", "Biology"]
            }
        }

        var combined: [String] = []
        for major in majors {
            let majorCourses: [String]
            switch major {
            case .engineering:
                majorCourses = ["Calculus", "Physics", "Linear Algebra", "Differential Equations",
                        "Chemistry", "Statistics", "Computer Science", "Engineering",
                        "Data Science", "Economics"]
            case .premed:
                majorCourses = ["Biology", "Chemistry", "Organic Chemistry", "Anatomy",
                        "Biochemistry", "Physics", "Statistics", "Economics"]
            case .cs:
                majorCourses = ["Computer Science", "Calculus", "Linear Algebra", "Statistics",
                        "Data Science", "Discrete Math", "Physics", "Economics"]
            case .science:
                majorCourses = ["Calculus", "Physics", "Chemistry", "Biology", "Statistics",
                        "Linear Algebra", "Differential Equations", "Organic Chemistry",
                        "Economics"]
            case .other:
                majorCourses = ["Math", "Science", "Economics", "Computer Science",
                        "Statistics", "Physics", "Chemistry", "Biology"]
            }
            for c in majorCourses where !combined.contains(c) {
                combined.append(c)
            }
        }
        return combined
    }

    static func topicPlaceholder(for courses: Set<String>) -> String {
        let examples: [(Set<String>, String)] = [
            (["Calculus"], "\"implicit differentiation\", \"u-substitution\", \"Taylor series\""),
            (["Physics"], "\"projectile motion\", \"Newton's third law\", \"circuits\""),
            (["Chemistry"], "\"redox reactions\", \"Lewis structures\", \"titrations\""),
            (["Biology"], "\"mitosis\", \"Krebs cycle\", \"genetics\""),
            (["Organic Chemistry"], "\"SN2 reactions\", \"mechanisms\", \"stereochemistry\""),
            (["Computer Science"], "\"recursion\", \"binary trees\", \"sorting algorithms\""),
            (["Linear Algebra"], "\"eigenvalues\", \"matrix transformations\", \"vector spaces\""),
            (["Statistics"], "\"hypothesis testing\", \"regression\", \"probability distributions\""),
            (["Economics"], "\"supply and demand\", \"elasticity\", \"market equilibrium\""),
        ]

        for (courseSet, placeholder) in examples {
            if !courseSet.isDisjoint(with: courses) {
                return "e.g. \(placeholder)"
            }
        }

        return "e.g. \"derivatives\", \"Newton's laws\", \"acid-base reactions\""
    }

    static func topicSuggestions(for courses: Set<String>) -> [String] {
        var suggestions: [String] = []
        if courses.contains("Calculus") { suggestions.append(contentsOf: ["derivatives", "integrals", "limits"]) }
        if courses.contains("Physics") { suggestions.append(contentsOf: ["kinematics", "Newton's laws", "circuits"]) }
        if courses.contains("Chemistry") { suggestions.append(contentsOf: ["stoichiometry", "bonding", "equilibrium"]) }
        if courses.contains("Biology") { suggestions.append(contentsOf: ["mitosis", "Krebs cycle", "genetics"]) }
        if courses.contains("Organic Chemistry") { suggestions.append(contentsOf: ["SN2 reactions", "mechanisms", "stereochemistry"]) }
        if courses.contains("Computer Science") { suggestions.append(contentsOf: ["recursion", "binary trees", "algorithms"]) }
        if courses.contains("Linear Algebra") { suggestions.append(contentsOf: ["eigenvalues", "matrices", "vector spaces"]) }
        if courses.contains("Statistics") { suggestions.append(contentsOf: ["hypothesis testing", "regression", "probability"]) }
        if courses.contains("Economics") { suggestions.append(contentsOf: ["supply & demand", "elasticity", "GDP"]) }
        if suggestions.isEmpty { suggestions = ["derivatives", "Newton's laws", "redox reactions"] }
        return Array(suggestions.prefix(6))
    }
}
