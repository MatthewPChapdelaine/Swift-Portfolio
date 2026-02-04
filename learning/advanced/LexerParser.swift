#!/usr/bin/env swift

/// Expression Lexer and Parser with AST Evaluation
/// Implements tokenization, parsing, and evaluation of mathematical expressions
///
/// Features:
/// - Lexical analysis (tokenization)
/// - Recursive descent parser
/// - Abstract Syntax Tree (AST) construction
/// - Expression evaluation
/// - Error handling with detailed messages
/// - Support for operators: +, -, *, /, ^, ()
/// - Variables and assignments
///
/// Grammar:
///   expression  → assignment
///   assignment  → IDENTIFIER "=" assignment | logical
///   logical     → additive ( ("==" | "!=" | "<" | ">" | "<=" | ">=") additive )*
///   additive    → multiplicative ( ("+" | "-") multiplicative )*
///   multiplicative → exponent ( ("*" | "/") exponent )*
///   exponent    → unary ( "^" unary )*
///   unary       → ("+" | "-") unary | primary
///   primary     → NUMBER | IDENTIFIER | "(" expression ")"
///
/// Compile: swiftc -o parser LexerParser.swift
/// Run: ./parser
/// Or: swift LexerParser.swift

import Foundation

// MARK: - Token Types

/// Token types for lexical analysis
enum TokenType: Equatable {
    case number(Double)
    case identifier(String)
    case plus
    case minus
    case multiply
    case divide
    case power
    case leftParen
    case rightParen
    case equal
    case equalEqual
    case notEqual
    case less
    case greater
    case lessEqual
    case greaterEqual
    case eof
    
    var description: String {
        switch self {
        case .number(let value): return "NUMBER(\(value))"
        case .identifier(let name): return "ID(\(name))"
        case .plus: return "+"
        case .minus: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        case .power: return "^"
        case .leftParen: return "("
        case .rightParen: return ")"
        case .equal: return "="
        case .equalEqual: return "=="
        case .notEqual: return "!="
        case .less: return "<"
        case .greater: return ">"
        case .lessEqual: return "<="
        case .greaterEqual: return ">="
        case .eof: return "EOF"
        }
    }
}

/// Token with position information
struct Token {
    let type: TokenType
    let position: Int
    
    init(_ type: TokenType, position: Int = 0) {
        self.type = type
        self.position = position
    }
}

// MARK: - Lexer

/// Lexical analyzer (tokenizer)
class Lexer {
    private let input: String
    private var position = 0
    private var currentChar: Character?
    
    init(_ input: String) {
        self.input = input
        self.currentChar = input.first
    }
    
    private func advance() {
        position += 1
        if position < input.count {
            let index = input.index(input.startIndex, offsetBy: position)
            currentChar = input[index]
        } else {
            currentChar = nil
        }
    }
    
    private func peek(offset: Int = 1) -> Character? {
        let peekPos = position + offset
        guard peekPos < input.count else { return nil }
        let index = input.index(input.startIndex, offsetBy: peekPos)
        return input[index]
    }
    
    private func skipWhitespace() {
        while let char = currentChar, char.isWhitespace {
            advance()
        }
    }
    
    private func number() throws -> Token {
        let startPos = position
        var numStr = ""
        
        while let char = currentChar, char.isNumber || char == "." {
            numStr.append(char)
            advance()
        }
        
        guard let value = Double(numStr) else {
            throw ParserError.invalidNumber(numStr, position: startPos)
        }
        
        return Token(.number(value), position: startPos)
    }
    
    private func identifier() -> Token {
        let startPos = position
        var idStr = ""
        
        while let char = currentChar, char.isLetter || char.isNumber || char == "_" {
            idStr.append(char)
            advance()
        }
        
        return Token(.identifier(idStr), position: startPos)
    }
    
    /// Tokenize input string
    func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        
        while currentChar != nil {
            skipWhitespace()
            
            guard let char = currentChar else { break }
            
            switch char {
            case "+":
                tokens.append(Token(.plus, position: position))
                advance()
            case "-":
                tokens.append(Token(.minus, position: position))
                advance()
            case "*":
                tokens.append(Token(.multiply, position: position))
                advance()
            case "/":
                tokens.append(Token(.divide, position: position))
                advance()
            case "^":
                tokens.append(Token(.power, position: position))
                advance()
            case "(":
                tokens.append(Token(.leftParen, position: position))
                advance()
            case ")":
                tokens.append(Token(.rightParen, position: position))
                advance()
            case "=":
                if peek() == "=" {
                    tokens.append(Token(.equalEqual, position: position))
                    advance()
                    advance()
                } else {
                    tokens.append(Token(.equal, position: position))
                    advance()
                }
            case "!":
                if peek() == "=" {
                    tokens.append(Token(.notEqual, position: position))
                    advance()
                    advance()
                } else {
                    throw ParserError.unexpectedCharacter(char, position: position)
                }
            case "<":
                if peek() == "=" {
                    tokens.append(Token(.lessEqual, position: position))
                    advance()
                    advance()
                } else {
                    tokens.append(Token(.less, position: position))
                    advance()
                }
            case ">":
                if peek() == "=" {
                    tokens.append(Token(.greaterEqual, position: position))
                    advance()
                    advance()
                } else {
                    tokens.append(Token(.greater, position: position))
                    advance()
                }
            case let c where c.isNumber:
                tokens.append(try number())
            case let c where c.isLetter:
                tokens.append(identifier())
            default:
                throw ParserError.unexpectedCharacter(char, position: position)
            }
        }
        
        tokens.append(Token(.eof, position: position))
        return tokens
    }
}

// MARK: - AST Nodes

/// Abstract Syntax Tree node protocol
protocol ASTNode {
    func evaluate(context: inout EvaluationContext) throws -> Double
    func description() -> String
}

/// Number literal node
struct NumberNode: ASTNode {
    let value: Double
    
    func evaluate(context: inout EvaluationContext) throws -> Double {
        return value
    }
    
    func description() -> String {
        return "\(value)"
    }
}

/// Variable reference node
struct VariableNode: ASTNode {
    let name: String
    
    func evaluate(context: inout EvaluationContext) throws -> Double {
        guard let value = context.variables[name] else {
            throw ParserError.undefinedVariable(name)
        }
        return value
    }
    
    func description() -> String {
        return name
    }
}

/// Binary operation node
struct BinaryOpNode: ASTNode {
    let left: ASTNode
    let operator: TokenType
    let right: ASTNode
    
    func evaluate(context: inout EvaluationContext) throws -> Double {
        let leftVal = try left.evaluate(context: &context)
        let rightVal = try right.evaluate(context: &context)
        
        switch `operator` {
        case .plus:
            return leftVal + rightVal
        case .minus:
            return leftVal - rightVal
        case .multiply:
            return leftVal * rightVal
        case .divide:
            guard rightVal != 0 else {
                throw ParserError.divisionByZero
            }
            return leftVal / rightVal
        case .power:
            return pow(leftVal, rightVal)
        case .equalEqual:
            return leftVal == rightVal ? 1.0 : 0.0
        case .notEqual:
            return leftVal != rightVal ? 1.0 : 0.0
        case .less:
            return leftVal < rightVal ? 1.0 : 0.0
        case .greater:
            return leftVal > rightVal ? 1.0 : 0.0
        case .lessEqual:
            return leftVal <= rightVal ? 1.0 : 0.0
        case .greaterEqual:
            return leftVal >= rightVal ? 1.0 : 0.0
        default:
            throw ParserError.invalidOperator
        }
    }
    
    func description() -> String {
        return "(\(left.description()) \(`operator`.description) \(right.description()))"
    }
}

/// Unary operation node
struct UnaryOpNode: ASTNode {
    let operator: TokenType
    let operand: ASTNode
    
    func evaluate(context: inout EvaluationContext) throws -> Double {
        let value = try operand.evaluate(context: &context)
        
        switch `operator` {
        case .plus:
            return value
        case .minus:
            return -value
        default:
            throw ParserError.invalidOperator
        }
    }
    
    func description() -> String {
        return "(\(`operator`.description)\(operand.description()))"
    }
}

/// Assignment node
struct AssignmentNode: ASTNode {
    let name: String
    let value: ASTNode
    
    func evaluate(context: inout EvaluationContext) throws -> Double {
        let val = try value.evaluate(context: &context)
        context.variables[name] = val
        return val
    }
    
    func description() -> String {
        return "(\(name) = \(value.description()))"
    }
}

// MARK: - Evaluation Context

/// Context for variable storage during evaluation
struct EvaluationContext {
    var variables: [String: Double] = [:]
}

// MARK: - Parser Errors

enum ParserError: Error, CustomStringConvertible {
    case unexpectedToken(expected: String, got: TokenType, position: Int)
    case unexpectedCharacter(Character, position: Int)
    case invalidNumber(String, position: Int)
    case unexpectedEndOfInput
    case undefinedVariable(String)
    case divisionByZero
    case invalidOperator
    
    var description: String {
        switch self {
        case .unexpectedToken(let expected, let got, let pos):
            return "Parse error at position \(pos): expected \(expected), got \(got.description)"
        case .unexpectedCharacter(let char, let pos):
            return "Lexer error at position \(pos): unexpected character '\(char)'"
        case .invalidNumber(let num, let pos):
            return "Lexer error at position \(pos): invalid number '\(num)'"
        case .unexpectedEndOfInput:
            return "Parse error: unexpected end of input"
        case .undefinedVariable(let name):
            return "Evaluation error: undefined variable '\(name)'"
        case .divisionByZero:
            return "Evaluation error: division by zero"
        case .invalidOperator:
            return "Evaluation error: invalid operator"
        }
    }
}

// MARK: - Parser

/// Recursive descent parser
class Parser {
    private var tokens: [Token]
    private var position = 0
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    private var currentToken: Token {
        return tokens[position]
    }
    
    private func advance() {
        if position < tokens.count - 1 {
            position += 1
        }
    }
    
    private func expect(_ type: TokenType) throws {
        guard currentToken.type == type else {
            throw ParserError.unexpectedToken(
                expected: type.description,
                got: currentToken.type,
                position: currentToken.position
            )
        }
        advance()
    }
    
    /// Parse expression
    func parse() throws -> ASTNode {
        let node = try expression()
        try expect(.eof)
        return node
    }
    
    private func expression() throws -> ASTNode {
        return try assignment()
    }
    
    private func assignment() throws -> ASTNode {
        let node = try logical()
        
        if case .identifier(let name) = node as? VariableNode?.name,
           case .equal = currentToken.type {
            advance()
            let value = try assignment()
            return AssignmentNode(name: name, value: value)
        }
        
        // Check for assignment
        if let varNode = node as? VariableNode, case .equal = currentToken.type {
            advance()
            let value = try assignment()
            return AssignmentNode(name: varNode.name, value: value)
        }
        
        return node
    }
    
    private func logical() throws -> ASTNode {
        var node = try additive()
        
        while case .equalEqual = currentToken.type {
            fallthrough
        case .notEqual: fallthrough
        case .less: fallthrough
        case .greater: fallthrough
        case .lessEqual: fallthrough
        case .greaterEqual:
            let op = currentToken.type
            advance()
            let right = try additive()
            node = BinaryOpNode(left: node, operator: op, right: right)
        default:
            break
        }
        
        return node
    }
    
    private func additive() throws -> ASTNode {
        var node = try multiplicative()
        
        while case .plus = currentToken.type {
            fallthrough
        case .minus:
            let op = currentToken.type
            advance()
            let right = try multiplicative()
            node = BinaryOpNode(left: node, operator: op, right: right)
        default:
            break
        }
        
        return node
    }
    
    private func multiplicative() throws -> ASTNode {
        var node = try exponent()
        
        while case .multiply = currentToken.type {
            fallthrough
        case .divide:
            let op = currentToken.type
            advance()
            let right = try exponent()
            node = BinaryOpNode(left: node, operator: op, right: right)
        default:
            break
        }
        
        return node
    }
    
    private func exponent() throws -> ASTNode {
        var node = try unary()
        
        if case .power = currentToken.type {
            let op = currentToken.type
            advance()
            let right = try exponent() // Right associative
            node = BinaryOpNode(left: node, operator: op, right: right)
        }
        
        return node
    }
    
    private func unary() throws -> ASTNode {
        if case .plus = currentToken.type {
            let op = currentToken.type
            advance()
            return UnaryOpNode(operator: op, operand: try unary())
        }
        
        if case .minus = currentToken.type {
            let op = currentToken.type
            advance()
            return UnaryOpNode(operator: op, operand: try unary())
        }
        
        return try primary()
    }
    
    private func primary() throws -> ASTNode {
        switch currentToken.type {
        case .number(let value):
            advance()
            return NumberNode(value: value)
            
        case .identifier(let name):
            advance()
            return VariableNode(name: name)
            
        case .leftParen:
            advance()
            let node = try expression()
            try expect(.rightParen)
            return node
            
        default:
            throw ParserError.unexpectedToken(
                expected: "number, identifier, or '('",
                got: currentToken.type,
                position: currentToken.position
            )
        }
    }
}

// MARK: - Interpreter

/// Expression interpreter
class Interpreter {
    private var context = EvaluationContext()
    
    /// Evaluate expression string
    func evaluate(_ input: String) throws -> Double {
        let lexer = Lexer(input)
        let tokens = try lexer.tokenize()
        
        let parser = Parser(tokens: tokens)
        let ast = try parser.parse()
        
        return try ast.evaluate(context: &context)
    }
    
    /// Get variable value
    func getVariable(_ name: String) -> Double? {
        return context.variables[name]
    }
    
    /// Set variable value
    func setVariable(_ name: String, value: Double) {
        context.variables[name] = value
    }
    
    /// Clear all variables
    func clearVariables() {
        context.variables.removeAll()
    }
    
    /// Get all variables
    func getAllVariables() -> [String: Double] {
        return context.variables
    }
}

// MARK: - Demo Functions

func demonstrateBasicArithmetic() {
    print("\n1️⃣  BASIC ARITHMETIC")
    print(String(repeating: "=", count: 50))
    
    let interpreter = Interpreter()
    let expressions = [
        "2 + 3",
        "10 - 4",
        "5 * 6",
        "20 / 4",
        "2 + 3 * 4",
        "(2 + 3) * 4",
        "10 / 2 + 3"
    ]
    
    for expr in expressions {
        do {
            let result = try interpreter.evaluate(expr)
            print("✅ \(expr) = \(result)")
        } catch {
            print("❌ \(expr) → \(error)")
        }
    }
}

func demonstrateExponents() {
    print("\n2️⃣  EXPONENTS")
    print(String(repeating: "=", count: 50))
    
    let interpreter = Interpreter()
    let expressions = [
        "2 ^ 3",
        "2 ^ 3 ^ 2",  // Right associative: 2^(3^2) = 2^9 = 512
        "(2 ^ 3) ^ 2",
        "4 ^ 0.5",  // Square root
        "10 + 2 ^ 3"
    ]
    
    for expr in expressions {
        do {
            let result = try interpreter.evaluate(expr)
            print("✅ \(expr) = \(result)")
        } catch {
            print("❌ \(expr) → \(error)")
        }
    }
}

func demonstrateVariables() {
    print("\n3️⃣  VARIABLES AND ASSIGNMENTS")
    print(String(repeating: "=", count: 50))
    
    let interpreter = Interpreter()
    let expressions = [
        "x = 10",
        "y = 5",
        "x + y",
        "z = x * y",
        "z + 10",
        "result = (x + y) * z"
    ]
    
    for expr in expressions {
        do {
            let result = try interpreter.evaluate(expr)
            print("✅ \(expr) = \(result)")
        } catch {
            print("❌ \(expr) → \(error)")
        }
    }
    
    print("\n📊 Variables:")
    for (name, value) in interpreter.getAllVariables().sorted(by: { $0.key < $1.key }) {
        print("   \(name) = \(value)")
    }
}

func demonstrateComparisons() {
    print("\n4️⃣  COMPARISON OPERATORS")
    print(String(repeating: "=", count: 50))
    
    let interpreter = Interpreter()
    let expressions = [
        "5 == 5",
        "5 != 3",
        "10 > 5",
        "3 < 7",
        "5 >= 5",
        "4 <= 4",
        "(2 + 3) == 5",
        "10 / 2 == 5"
    ]
    
    for expr in expressions {
        do {
            let result = try interpreter.evaluate(expr)
            let bool = result == 1.0 ? "true" : "false"
            print("✅ \(expr) = \(bool)")
        } catch {
            print("❌ \(expr) → \(error)")
        }
    }
}

func demonstrateComplexExpressions() {
    print("\n5️⃣  COMPLEX EXPRESSIONS")
    print(String(repeating: "=", count: 50))
    
    let interpreter = Interpreter()
    let expressions = [
        "a = 5",
        "b = 10",
        "c = 2",
        "result = (a + b) * c ^ 2 - 15 / 3",
        "formula = (a * b + c) / (a - c)",
        "nested = ((a + b) * (c + 3)) / (a + 2)"
    ]
    
    for expr in expressions {
        do {
            let result = try interpreter.evaluate(expr)
            print("✅ \(expr) = \(result)")
        } catch {
            print("❌ \(expr) → \(error)")
        }
    }
}

func demonstrateErrorHandling() {
    print("\n6️⃣  ERROR HANDLING")
    print(String(repeating: "=", count: 50))
    
    let interpreter = Interpreter()
    let expressions = [
        "5 +",           // Missing operand
        "(2 + 3",        // Missing closing paren
        "10 / 0",        // Division by zero
        "5 @ 3",         // Invalid operator
        "undefined_var", // Undefined variable
        "2 3"            // Missing operator
    ]
    
    for expr in expressions {
        do {
            let result = try interpreter.evaluate(expr)
            print("✅ \(expr) = \(result)")
        } catch {
            print("❌ \(expr)")
            print("   Error: \(error)")
        }
    }
}

func demonstrateAST() {
    print("\n7️⃣  ABSTRACT SYNTAX TREE (AST)")
    print(String(repeating: "=", count: 50))
    
    let expressions = [
        "2 + 3",
        "2 * 3 + 4",
        "(2 + 3) * 4",
        "2 ^ 3 ^ 2"
    ]
    
    for expr in expressions {
        do {
            let lexer = Lexer(expr)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens: tokens)
            let ast = try parser.parse()
            
            print("\n📝 Expression: \(expr)")
            print("🌳 AST: \(ast.description())")
            
            var context = EvaluationContext()
            let result = try ast.evaluate(context: &context)
            print("✅ Result: \(result)")
        } catch {
            print("❌ \(expr) → \(error)")
        }
    }
}

// MARK: - Main Entry Point

@main
struct LexerParserDemo {
    static func main() {
        print("╔════════════════════════════════════════╗")
        print("║    Expression Lexer & Parser Demo     ║")
        print("║    Tokenization → AST → Evaluation    ║")
        print("╚════════════════════════════════════════╝")
        
        demonstrateBasicArithmetic()
        demonstrateExponents()
        demonstrateVariables()
        demonstrateComparisons()
        demonstrateComplexExpressions()
        demonstrateErrorHandling()
        demonstrateAST()
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ Lexer/Parser demo completed!")
        print(String(repeating: "=", count: 50))
        
        print("\n💡 FEATURES DEMONSTRATED:")
        print("   • Lexical analysis (tokenization)")
        print("   • Recursive descent parsing")
        print("   • Abstract Syntax Tree construction")
        print("   • Expression evaluation")
        print("   • Variable assignments")
        print("   • Operator precedence")
        print("   • Error handling with positions")
    }
}

/*
 USAGE INSTRUCTIONS:
 ═══════════════════
 
 1. Run directly:
    swift LexerParser.swift
    
 2. Compile and run:
    swiftc -o parser LexerParser.swift
    ./parser
 
 3. Use as library:
    let interpreter = Interpreter()
    let result = try interpreter.evaluate("2 + 3 * 4")
 
 GRAMMAR:
 ═══════
 
 expression     → assignment
 assignment     → IDENTIFIER "=" assignment | logical
 logical        → additive ( ("==" | "!=") additive )*
 additive       → multiplicative ( ("+" | "-") multiplicative )*
 multiplicative → exponent ( ("*" | "/") exponent )*
 exponent       → unary ( "^" unary )*
 unary          → ("+" | "-") unary | primary
 primary        → NUMBER | IDENTIFIER | "(" expression ")"
 
 OPERATOR PRECEDENCE (highest to lowest):
 ═══════════════════════════════════════
 
 1. Parentheses: ()
 2. Unary: +, -
 3. Exponentiation: ^ (right associative)
 4. Multiplication/Division: *, /
 5. Addition/Subtraction: +, -
 6. Comparison: ==, !=, <, >, <=, >=
 7. Assignment: =
 
 ARCHITECTURE:
 ════════════
 
 Input String
     ↓
 Lexer (Tokenization)
     ↓
 [Token]
     ↓
 Parser (Recursive Descent)
     ↓
 AST (Abstract Syntax Tree)
     ↓
 Evaluator
     ↓
 Result (Double)
 
 SWIFT FEATURES:
 ══════════════
 
 ✓ Enums with associated values
 ✓ Protocol-oriented design
 ✓ Error handling (throws, try)
 ✓ Pattern matching (switch)
 ✓ Struct vs Class (value/reference types)
 ✓ Optionals for safe navigation
 ✓ Recursive functions
 ✓ String manipulation
 
 EXTENDING:
 ═════════
 
 To add new operators:
 1. Add token type to TokenType enum
 2. Update lexer to recognize operator
 3. Add parsing method (if needed)
 4. Add evaluation in BinaryOpNode
 
 To add functions:
 1. Create FunctionCallNode
 2. Parse: IDENTIFIER "(" args ")"
 3. Evaluate with function table
 
 Example:
   case .identifier(let name):
       if peek() == "(" {
           return try functionCall(name)
       }
 
 PRODUCTION CONSIDERATIONS:
 ═════════════════════════
 
 For production:
 - Add more error recovery
 - Support more data types (strings, booleans)
 - Add function definitions
 - Implement control flow (if/else, loops)
 - Add type checking
 - Optimize AST evaluation
 - Add REPL (Read-Eval-Print Loop)
 - Support comments
 - Add source location tracking
 - Implement pretty-printer
*/
