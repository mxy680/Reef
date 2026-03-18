import SwiftUI

// MARK: - History Entry

struct CalculatorHistoryEntry: Identifiable {
    let id = UUID()
    let expression: String
    let result: String
    let timestamp: Date
}

// MARK: - ViewModel

@Observable
@MainActor
final class CalculatorViewModel {

    // MARK: - Displayed state

    var displayText: String = "" {
        didSet { updateResultPreview() }
    }

    var resultText: String = ""

    // MARK: - History

    private(set) var history: [CalculatorHistoryEntry] = []

    private static let maxHistoryCount = 50

    // MARK: - Mode

    var isCompact: Bool = true
    var isShowingHistory: Bool = false

    // MARK: - Input methods

    func appendCharacter(_ char: String) {
        displayText += char
    }

    func appendFunction(_ name: String) {
        // Append function name with opening paren so the user can type the argument
        displayText += "\(name)("
    }

    func clear() {
        displayText = ""
    }

    func allClear() {
        displayText = ""
        resultText = ""
    }

    func deleteLastCharacter() {
        guard !displayText.isEmpty else { return }
        displayText.removeLast()
    }

    func evaluate() {
        let expression = displayText.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else { return }

        do {
            let value = try CalculatorEngine.evaluate(expression)
            let formatted = format(value)
            let entry = CalculatorHistoryEntry(
                expression: expression,
                result: formatted,
                timestamp: Date()
            )
            insertHistory(entry)
            displayText = formatted
            resultText = ""
        } catch {
            resultText = "Error"
        }
    }

    func toggleSign() {
        // Wrap the current display in negation or strip leading minus
        guard !displayText.isEmpty else { return }
        if displayText.hasPrefix("-") {
            displayText = String(displayText.dropFirst())
        } else {
            displayText = "-" + displayText
        }
    }

    // MARK: - Private helpers

    private func updateResultPreview() {
        let expression = displayText.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else {
            resultText = ""
            return
        }
        do {
            let value = try CalculatorEngine.evaluate(expression)
            let formatted = format(value)
            // Only show preview when it differs from what's already typed
            resultText = (formatted == expression) ? "" : formatted
        } catch {
            resultText = ""
        }
    }

    private func insertHistory(_ entry: CalculatorHistoryEntry) {
        history.insert(entry, at: 0)
        if history.count > Self.maxHistoryCount {
            history = Array(history.prefix(Self.maxHistoryCount))
        }
    }

    // MARK: - Number formatting

    /// Formats a Double for display:
    /// - Strips trailing decimal zeros for normal magnitudes
    /// - Scientific notation for magnitudes > 1e12 or (non-zero) < 1e-6
    /// - Caps at 10 significant digits
    private func format(_ value: Double) -> String {
        guard value.isFinite else {
            return value.isNaN ? "Error" : (value > 0 ? "∞" : "-∞")
        }

        let absValue = abs(value)

        // Use scientific notation for very large or very small non-zero values
        if absValue != 0 && (absValue >= 1e12 || absValue < 1e-6) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            formatter.maximumSignificantDigits = 10
            formatter.exponentSymbol = "e"
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        // Standard formatting — up to 10 significant digits, strip trailing zeros
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumSignificantDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
