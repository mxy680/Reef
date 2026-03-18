import Foundation

// MARK: - Errors

enum CalculatorError: Error, LocalizedError {
    case divisionByZero
    case invalidExpression
    case unmatchedParenthesis
    case domainError(String)

    var errorDescription: String? {
        switch self {
        case .divisionByZero:       return "Division by zero"
        case .invalidExpression:    return "Invalid expression"
        case .unmatchedParenthesis: return "Unmatched parenthesis"
        case .domainError(let msg): return msg
        }
    }
}

// MARK: - Token

enum Token: Equatable {
    case number(Double)
    case op(Character)
    case `func`(String)
    case paren(Character)
    case constant(String)
}

// MARK: - Engine

struct CalculatorEngine {

    // MARK: Public entry point

    static func evaluate(_ expression: String) throws -> Double {
        let tokens = try tokenize(expression)
        var index = 0
        let result = try parseAddSub(tokens: tokens, index: &index)
        guard index == tokens.count else {
            throw CalculatorError.invalidExpression
        }
        return result
    }

    // MARK: - Tokenizer

    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        var chars = Array(input.lowercased())
        var i = 0

        let knownFunctions: Set<String> = [
            "sin", "cos", "tan", "asin", "acos", "atan",
            "ln", "log", "sqrt", "abs"
        ]
        let knownConstants: Set<String> = ["pi", "e"]

        while i < chars.count {
            let ch = chars[i]

            // Skip whitespace
            if ch.isWhitespace {
                i += 1
                continue
            }

            // Number (integer or decimal)
            if ch.isNumber || ch == "." {
                var numStr = String(ch)
                i += 1
                while i < chars.count && (chars[i].isNumber || chars[i] == ".") {
                    numStr.append(chars[i])
                    i += 1
                }
                guard let value = Double(numStr) else {
                    throw CalculatorError.invalidExpression
                }
                tokens.append(.number(value))
                continue
            }

            // Identifier — function name or constant
            if ch.isLetter {
                var name = String(ch)
                i += 1
                while i < chars.count && chars[i].isLetter {
                    name.append(chars[i])
                    i += 1
                }
                if knownFunctions.contains(name) {
                    tokens.append(.func(name))
                } else if knownConstants.contains(name) {
                    tokens.append(.constant(name))
                } else {
                    throw CalculatorError.invalidExpression
                }
                continue
            }

            // Factorial
            if ch == "!" {
                tokens.append(.op(ch))
                i += 1
                continue
            }

            // Operators
            if "+-*/^%".contains(ch) {
                tokens.append(.op(ch))
                i += 1
                continue
            }

            // Parentheses
            if ch == "(" || ch == ")" {
                tokens.append(.paren(ch))
                i += 1
                continue
            }

            throw CalculatorError.invalidExpression
        }

        return tokens
    }

    // MARK: - Recursive-Descent Parser

    // Level 0: addition and subtraction (left-associative)
    private static func parseAddSub(tokens: [Token], index: inout Int) throws -> Double {
        var left = try parseMulDiv(tokens: tokens, index: &index)

        while index < tokens.count, case .op(let op) = tokens[index], op == "+" || op == "-" {
            index += 1
            let right = try parseMulDiv(tokens: tokens, index: &index)
            left = op == "+" ? left + right : left - right
        }

        return left
    }

    // Level 1: multiplication, division, modulo (left-associative)
    private static func parseMulDiv(tokens: [Token], index: inout Int) throws -> Double {
        var left = try parseExponent(tokens: tokens, index: &index)

        while index < tokens.count, case .op(let op) = tokens[index],
              op == "*" || op == "/" || op == "%" {
            index += 1
            let right = try parseExponent(tokens: tokens, index: &index)
            switch op {
            case "*":
                left = left * right
            case "/":
                guard right != 0 else { throw CalculatorError.divisionByZero }
                left = left / right
            case "%":
                guard right != 0 else { throw CalculatorError.divisionByZero }
                left = left.truncatingRemainder(dividingBy: right)
            default:
                break
            }
        }

        return left
    }

    // Level 2: exponentiation (right-associative)
    private static func parseExponent(tokens: [Token], index: inout Int) throws -> Double {
        let base = try parseUnary(tokens: tokens, index: &index)

        if index < tokens.count, case .op(let op) = tokens[index], op == "^" {
            index += 1
            // Right-associative: recurse at the same level
            let exponent = try parseExponent(tokens: tokens, index: &index)
            return pow(base, exponent)
        }

        return base
    }

    // Level 3: unary minus, functions, factorial (postfix !)
    private static func parseUnary(tokens: [Token], index: inout Int) throws -> Double {
        // Unary minus
        if index < tokens.count, case .op(let op) = tokens[index], op == "-" {
            index += 1
            let operand = try parseUnary(tokens: tokens, index: &index)
            return -operand
        }

        // Unary plus (no-op)
        if index < tokens.count, case .op(let op) = tokens[index], op == "+" {
            index += 1
            return try parseUnary(tokens: tokens, index: &index)
        }

        // Function application
        if index < tokens.count, case .func(let name) = tokens[index] {
            index += 1
            // Expect opening paren
            guard index < tokens.count, case .paren(let p) = tokens[index], p == "(" else {
                throw CalculatorError.invalidExpression
            }
            index += 1
            let arg = try parseAddSub(tokens: tokens, index: &index)
            guard index < tokens.count, case .paren(let cp) = tokens[index], cp == ")" else {
                throw CalculatorError.unmatchedParenthesis
            }
            index += 1
            return try applyFunction(name, arg: arg)
        }

        // Primary (atom), then check for trailing factorial
        var value = try parsePrimary(tokens: tokens, index: &index)

        while index < tokens.count, case .op(let op) = tokens[index], op == "!" {
            index += 1
            value = try factorial(value)
        }

        return value
    }

    // Level 4: parenthesised expressions, numbers, constants
    private static func parsePrimary(tokens: [Token], index: inout Int) throws -> Double {
        guard index < tokens.count else {
            throw CalculatorError.invalidExpression
        }

        switch tokens[index] {
        case .number(let v):
            index += 1
            return v

        case .constant(let name):
            index += 1
            switch name {
            case "pi": return Double.pi
            case "e":  return M_E
            default:   throw CalculatorError.invalidExpression
            }

        case .paren(let p) where p == "(":
            index += 1
            let value = try parseAddSub(tokens: tokens, index: &index)
            guard index < tokens.count, case .paren(let cp) = tokens[index], cp == ")" else {
                throw CalculatorError.unmatchedParenthesis
            }
            index += 1
            return value

        default:
            throw CalculatorError.invalidExpression
        }
    }

    // MARK: - Helpers

    private static func applyFunction(_ name: String, arg: Double) throws -> Double {
        switch name {
        case "sin":  return sin(arg)
        case "cos":  return cos(arg)
        case "tan":  return tan(arg)
        case "asin":
            guard arg >= -1 && arg <= 1 else {
                throw CalculatorError.domainError("asin domain: [-1, 1]")
            }
            return asin(arg)
        case "acos":
            guard arg >= -1 && arg <= 1 else {
                throw CalculatorError.domainError("acos domain: [-1, 1]")
            }
            return acos(arg)
        case "atan":  return atan(arg)
        case "ln":
            guard arg > 0 else {
                throw CalculatorError.domainError("ln requires positive argument")
            }
            return log(arg)
        case "log":
            guard arg > 0 else {
                throw CalculatorError.domainError("log requires positive argument")
            }
            return log10(arg)
        case "sqrt":
            guard arg >= 0 else {
                throw CalculatorError.domainError("sqrt requires non-negative argument")
            }
            return sqrt(arg)
        case "abs":   return abs(arg)
        default:      throw CalculatorError.invalidExpression
        }
    }

    private static func factorial(_ value: Double) throws -> Double {
        guard value >= 0, value == value.rounded(), value <= 170 else {
            throw CalculatorError.domainError("Factorial requires a non-negative integer ≤ 170")
        }
        let n = Int(value)
        if n == 0 { return 1 }
        var result: Double = 1
        for i in 1...n {
            result *= Double(i)
        }
        return result
    }
}
