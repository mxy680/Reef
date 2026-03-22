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
}

// MARK: - Enums

enum StudentType: String, Codable, Sendable, CaseIterable {
    case highSchool = "high_school"
    case college = "college"
    case graduate = "graduate"
    case other = "other"

    var displayLabel: String {
        switch self {
        case .highSchool: "High schooler"
        case .college: "College student"
        case .graduate: "Grad student"
        case .other: "Something else entirely"
        }
    }
}

enum MajorField: String, Codable, Sendable, CaseIterable {
    case stem = "stem"
    case business = "business"
    case humanities = "humanities"
    case arts = "arts"
    case health = "health"
    case other = "other"

    var displayLabel: String {
        switch self {
        case .stem: "STEM"
        case .business: "Business"
        case .humanities: "Humanities"
        case .arts: "Arts"
        case .health: "Health / Pre-Med"
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
        case .aceExams: "Ace my exams"
        case .understand: "Actually understand what's going on"
        case .saveTime: "Stop studying until 3am"
        case .boostGPA: "Rescue my GPA"
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
        case .procrastination: "Procrastination"
        case .confusingMaterial: "Confusing material"
        case .noOneToAsk: "No one to ask"
        case .testAnxiety: "Test anxiety"
        case .cantRetain: "Can't retain anything"
        case .timeManagement: "Time management"
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
        case .visual: "Seeing it"
        case .auditory: "Hearing it"
        case .handson: "Doing it"
        case .reading: "Reading it"
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
    case fifteen = 15
    case thirty = 30
    case fortyFive = 45
    case sixty = 60

    var displayLabel: String {
        switch self {
        case .fifteen: "15 min"
        case .thirty: "30 min"
        case .fortyFive: "45 min"
        case .sixty: "60 min"
        }
    }

    var subtitle: String {
        switch self {
        case .fifteen: "just a taste"
        case .thirty: "solid effort"
        case .fortyFive: "okay we see you"
        case .sixty: "absolute machine"
        }
    }
}

enum ReferralSource: String, Codable, Sendable, CaseIterable {
    case tiktok = "tiktok"
    case instagram = "instagram"
    case friend = "friend"
    case teacherSchool = "teacher_school"
    case google = "google"
    case other = "other"

    var displayLabel: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .friend: "A friend (bless them)"
        case .teacherSchool: "Teacher / School"
        case .google: "Google"
        case .other: "Other"
        }
    }
}

// MARK: - Answers

struct OnboardingAnswers: Sendable {
    var studentType: StudentType?
    var major: MajorField?
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
    static func courses(for studentType: StudentType?, major: MajorField?) -> [String] {
        switch major {
        case .stem:
            return ["Calculus", "Physics", "Chemistry", "Biology", "Organic Chemistry",
                    "Linear Algebra", "Differential Equations", "Statistics",
                    "Computer Science", "Engineering", "Data Science"]
        case .business:
            return ["Accounting", "Economics", "Finance", "Statistics", "Business Analytics"]
        case .health:
            return ["Biology", "Chemistry", "Organic Chemistry", "Anatomy",
                    "Biochemistry", "Physics"]
        case .humanities, .arts:
            return ["Math", "Statistics", "Economics", "Computer Science"]
        case .other, nil:
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
