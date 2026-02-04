#!/usr/bin/env swift

import Foundation

// MARK: - Token Types

/// Represents the types of tokens in the language
enum TokenType: Equatable {
    case number(Double)
    case identifier(String)
    case keyword(Keyword)
    case operator_(Operator)
    case lparen, rparen, lbrace, rbrace
    case semicolon, comma, assign
    case eof
    
    enum Keyword: String {
        case let_, var_, func_, if_, else_, while_, return_
    }
    
    enum Operator: String {
        case plus = "+", minus = "-", multiply = "*", divide = "/"
        case equal = "==", notEqual = "!=", less = "<", greater = ">"
        case lessEqual = "<=", greaterEqual = ">="
    }
}

struct Token {
    let type: TokenType
    let line: Int
    let column: Int
}

// MARK: - Lexer

/// Lexical analyzer that converts source code into tokens
final class Lexer {
    private let source: String
    private var current: String.Index
    private var line = 1
    private var column = 1
    
    init(source: String) {
        self.source = source
        self.current = source.startIndex
    }
    
    /// Tokenizes the entire source code
    func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while let token = try nextToken() {
            tokens.append(token)
            if case .eof = token.type { break }
        }
        return tokens
    }
    
    private func nextToken() throws -> Token? {
        skipWhitespace()
        
        guard current < source.endIndex else {
            return Token(type: .eof, line: line, column: column)
        }
        
        let startLine = line
        let startColumn = column
        let char = source[current]
        
        // Numbers
        if char.isNumber {
            let number = try scanNumber()
            return Token(type: .number(number), line: startLine, column: startColumn)
        }
        
        // Identifiers and keywords
        if char.isLetter || char == "_" {
            let identifier = scanIdentifier()
            let type: TokenType
            
            if let keyword = TokenType.Keyword(rawValue: identifier) {
                type = .keyword(keyword)
            } else {
                type = .identifier(identifier)
            }
            return Token(type: type, line: startLine, column: startColumn)
        }
        
        // Operators and punctuation
        advance()
        switch char {
        case "+": return Token(type: .operator_(.plus), line: startLine, column: startColumn)
        case "-": return Token(type: .operator_(.minus), line: startLine, column: startColumn)
        case "*": return Token(type: .operator_(.multiply), line: startLine, column: startColumn)
        case "/": return Token(type: .operator_(.divide), line: startLine, column: startColumn)
        case "(": return Token(type: .lparen, line: startLine, column: startColumn)
        case ")": return Token(type: .rparen, line: startLine, column: startColumn)
        case "{": return Token(type: .lbrace, line: startLine, column: startColumn)
        case "}": return Token(type: .rbrace, line: startLine, column: startColumn)
        case ";": return Token(type: .semicolon, line: startLine, column: startColumn)
        case ",": return Token(type: .comma, line: startLine, column: startColumn)
        case "=":
            if peek() == "=" {
                advance()
                return Token(type: .operator_(.equal), line: startLine, column: startColumn)
            }
            return Token(type: .assign, line: startLine, column: startColumn)
        case "!":
            if peek() == "=" {
                advance()
                return Token(type: .operator_(.notEqual), line: startLine, column: startColumn)
            }
            throw LexerError.unexpectedCharacter(char, line: startLine, column: startColumn)
        case "<":
            if peek() == "=" {
                advance()
                return Token(type: .operator_(.lessEqual), line: startLine, column: startColumn)
            }
            return Token(type: .operator_(.less), line: startLine, column: startColumn)
        case ">":
            if peek() == "=" {
                advance()
                return Token(type: .operator_(.greaterEqual), line: startLine, column: startColumn)
            }
            return Token(type: .operator_(.greater), line: startLine, column: startColumn)
        default:
            throw LexerError.unexpectedCharacter(char, line: startLine, column: startColumn)
        }
    }
    
    private func scanNumber() throws -> Double {
        var numStr = ""
        while current < source.endIndex && (source[current].isNumber || source[current] == ".") {
            numStr.append(source[current])
            advance()
        }
        guard let number = Double(numStr) else {
            throw LexerError.invalidNumber(numStr, line: line, column: column)
        }
        return number
    }
    
    private func scanIdentifier() -> String {
        var identifier = ""
        while current < source.endIndex && (source[current].isLetter || source[current].isNumber || source[current] == "_") {
            identifier.append(source[current])
            advance()
        }
        return identifier
    }
    
    private func skipWhitespace() {
        while current < source.endIndex {
            let char = source[current]
            if char == "\n" {
                line += 1
                column = 1
                current = source.index(after: current)
            } else if char.isWhitespace {
                advance()
            } else {
                break
            }
        }
    }
    
    private func advance() {
        guard current < source.endIndex else { return }
        current = source.index(after: current)
        column += 1
    }
    
    private func peek() -> Character? {
        let next = source.index(after: current)
        guard next < source.endIndex else { return nil }
        return source[next]
    }
}

enum LexerError: Error, CustomStringConvertible {
    case unexpectedCharacter(Character, line: Int, column: Int)
    case invalidNumber(String, line: Int, column: Int)
    
    var description: String {
        switch self {
        case .unexpectedCharacter(let char, let line, let column):
            return "Unexpected character '\(char)' at line \(line), column \(column)"
        case .invalidNumber(let str, let line, let column):
            return "Invalid number '\(str)' at line \(line), column \(column)"
        }
    }
}

// MARK: - Abstract Syntax Tree

/// Represents expressions in the AST
enum Expression {
    case number(Double)
    case variable(String)
    case binary(BinaryOp, Box<Expression>, Box<Expression>)
    case call(String, [Expression])
    case assignment(String, Box<Expression>)
    
    enum BinaryOp {
        case add, subtract, multiply, divide
        case equal, notEqual, less, greater, lessEqual, greaterEqual
    }
}

/// Represents statements in the AST
enum Statement {
    case expression(Expression)
    case variableDeclaration(String, isMutable: Bool, Expression)
    case functionDeclaration(String, parameters: [String], body: [Statement])
    case ifStatement(condition: Expression, thenBranch: [Statement], elseBranch: [Statement]?)
    case whileStatement(condition: Expression, body: [Statement])
    case returnStatement(Expression?)
    case block([Statement])
}

/// Box type for recursive enums
final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Parser

/// Recursive descent parser that builds an AST from tokens
final class Parser {
    private var tokens: [Token]
    private var current = 0
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    /// Parses the tokens into a program (list of statements)
    func parse() throws -> [Statement] {
        var statements: [Statement] = []
        while !isAtEnd() {
            statements.append(try statement())
        }
        return statements
    }
    
    private func statement() throws -> Statement {
        if match(.keyword(.let_)) {
            return try variableDeclaration(mutable: false)
        }
        if match(.keyword(.var_)) {
            return try variableDeclaration(mutable: true)
        }
        if match(.keyword(.func_)) {
            return try functionDeclaration()
        }
        if match(.keyword(.if_)) {
            return try ifStatement()
        }
        if match(.keyword(.while_)) {
            return try whileStatement()
        }
        if match(.keyword(.return_)) {
            return try returnStatement()
        }
        if match(.lbrace) {
            return try block()
        }
        
        let expr = try expression()
        try consume(.semicolon)
        return .expression(expr)
    }
    
    private func variableDeclaration(mutable: Bool) throws -> Statement {
        guard case .identifier(let name) = peek().type else {
            throw ParserError.expectedIdentifier(peek())
        }
        advance()
        try consume(.assign)
        let expr = try expression()
        try consume(.semicolon)
        return .variableDeclaration(name, isMutable: mutable, expr)
    }
    
    private func functionDeclaration() throws -> Statement {
        guard case .identifier(let name) = peek().type else {
            throw ParserError.expectedIdentifier(peek())
        }
        advance()
        try consume(.lparen)
        
        var parameters: [String] = []
        if case .identifier(let param) = peek().type {
            parameters.append(param)
            advance()
            while match(.comma) {
                guard case .identifier(let param) = peek().type else {
                    throw ParserError.expectedIdentifier(peek())
                }
                parameters.append(param)
                advance()
            }
        }
        
        try consume(.rparen)
        try consume(.lbrace)
        
        var body: [Statement] = []
        while !check(.rbrace) && !isAtEnd() {
            body.append(try statement())
        }
        
        try consume(.rbrace)
        return .functionDeclaration(name, parameters: parameters, body: body)
    }
    
    private func ifStatement() throws -> Statement {
        try consume(.lparen)
        let condition = try expression()
        try consume(.rparen)
        try consume(.lbrace)
        
        var thenBranch: [Statement] = []
        while !check(.rbrace) && !isAtEnd() {
            thenBranch.append(try statement())
        }
        try consume(.rbrace)
        
        var elseBranch: [Statement]?
        if match(.keyword(.else_)) {
            try consume(.lbrace)
            var statements: [Statement] = []
            while !check(.rbrace) && !isAtEnd() {
                statements.append(try statement())
            }
            try consume(.rbrace)
            elseBranch = statements
        }
        
        return .ifStatement(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
    }
    
    private func whileStatement() throws -> Statement {
        try consume(.lparen)
        let condition = try expression()
        try consume(.rparen)
        try consume(.lbrace)
        
        var body: [Statement] = []
        while !check(.rbrace) && !isAtEnd() {
            body.append(try statement())
        }
        try consume(.rbrace)
        
        return .whileStatement(condition: condition, body: body)
    }
    
    private func returnStatement() throws -> Statement {
        let expr = check(.semicolon) ? nil : try expression()
        try consume(.semicolon)
        return .returnStatement(expr)
    }
    
    private func block() throws -> Statement {
        var statements: [Statement] = []
        while !check(.rbrace) && !isAtEnd() {
            statements.append(try statement())
        }
        try consume(.rbrace)
        return .block(statements)
    }
    
    private func expression() throws -> Expression {
        return try assignment()
    }
    
    private func assignment() throws -> Expression {
        let expr = try equality()
        
        if match(.assign) {
            guard case .variable(let name) = expr else {
                throw ParserError.invalidAssignmentTarget
            }
            let value = try assignment()
            return .assignment(name, Box(value))
        }
        
        return expr
    }
    
    private func equality() throws -> Expression {
        var expr = try comparison()
        
        while true {
            if match(.operator_(.equal)) {
                let right = try comparison()
                expr = .binary(.equal, Box(expr), Box(right))
            } else if match(.operator_(.notEqual)) {
                let right = try comparison()
                expr = .binary(.notEqual, Box(expr), Box(right))
            } else {
                break
            }
        }
        
        return expr
    }
    
    private func comparison() throws -> Expression {
        var expr = try term()
        
        while true {
            if match(.operator_(.less)) {
                let right = try term()
                expr = .binary(.less, Box(expr), Box(right))
            } else if match(.operator_(.lessEqual)) {
                let right = try term()
                expr = .binary(.lessEqual, Box(expr), Box(right))
            } else if match(.operator_(.greater)) {
                let right = try term()
                expr = .binary(.greater, Box(expr), Box(right))
            } else if match(.operator_(.greaterEqual)) {
                let right = try term()
                expr = .binary(.greaterEqual, Box(expr), Box(right))
            } else {
                break
            }
        }
        
        return expr
    }
    
    private func term() throws -> Expression {
        var expr = try factor()
        
        while match(.operator_(.plus)) || match(.operator_(.minus)) {
            let op: Expression.BinaryOp = previous().type == .operator_(.plus) ? .add : .subtract
            let right = try factor()
            expr = .binary(op, Box(expr), Box(right))
        }
        
        return expr
    }
    
    private func factor() throws -> Expression {
        var expr = try primary()
        
        while match(.operator_(.multiply)) || match(.operator_(.divide)) {
            let op: Expression.BinaryOp = previous().type == .operator_(.multiply) ? .multiply : .divide
            let right = try primary()
            expr = .binary(op, Box(expr), Box(right))
        }
        
        return expr
    }
    
    private func primary() throws -> Expression {
        if case .number(let value) = peek().type {
            advance()
            return .number(value)
        }
        
        if case .identifier(let name) = peek().type {
            advance()
            if match(.lparen) {
                var args: [Expression] = []
                if !check(.rparen) {
                    args.append(try expression())
                    while match(.comma) {
                        args.append(try expression())
                    }
                }
                try consume(.rparen)
                return .call(name, args)
            }
            return .variable(name)
        }
        
        if match(.lparen) {
            let expr = try expression()
            try consume(.rparen)
            return expr
        }
        
        throw ParserError.unexpectedToken(peek())
    }
    
    // Helper methods
    
    @discardableResult
    private func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }
    
    private func check(_ type: TokenType) -> Bool {
        guard !isAtEnd() else { return false }
        return tokens[current].type == type
    }
    
    @discardableResult
    private func advance() -> Token {
        if !isAtEnd() { current += 1 }
        return previous()
    }
    
    private func isAtEnd() -> Bool {
        return peek().type == .eof
    }
    
    private func peek() -> Token {
        return tokens[current]
    }
    
    private func previous() -> Token {
        return tokens[current - 1]
    }
    
    private func consume(_ type: TokenType) throws {
        guard check(type) else {
            throw ParserError.expected(type, got: peek())
        }
        advance()
    }
}

enum ParserError: Error, CustomStringConvertible {
    case unexpectedToken(Token)
    case expected(TokenType, got: Token)
    case expectedIdentifier(Token)
    case invalidAssignmentTarget
    
    var description: String {
        switch self {
        case .unexpectedToken(let token):
            return "Unexpected token at line \(token.line), column \(token.column)"
        case .expected(let expected, let got):
            return "Expected \(expected) but got \(got.type) at line \(got.line)"
        case .expectedIdentifier(let token):
            return "Expected identifier at line \(token.line)"
        case .invalidAssignmentTarget:
            return "Invalid assignment target"
        }
    }
}

// MARK: - Interpreter

/// Runtime value types
enum Value {
    case number(Double)
    case function(parameters: [String], body: [Statement], closure: Environment)
    case void
    
    var asNumber: Double? {
        if case .number(let n) = self { return n }
        return nil
    }
    
    var isTruthy: Bool {
        switch self {
        case .number(let n): return n != 0
        case .function: return true
        case .void: return false
        }
    }
}

/// Symbol table for variable and function storage
final class Environment {
    private var values: [String: Value] = [:]
    private let parent: Environment?
    
    init(parent: Environment? = nil) {
        self.parent = parent
    }
    
    func define(name: String, value: Value) {
        values[name] = value
    }
    
    func get(name: String) throws -> Value {
        if let value = values[name] {
            return value
        }
        if let parent = parent {
            return try parent.get(name: name)
        }
        throw RuntimeError.undefinedVariable(name)
    }
    
    func assign(name: String, value: Value) throws {
        if values[name] != nil {
            values[name] = value
            return
        }
        if let parent = parent {
            try parent.assign(name: name, value: value)
            return
        }
        throw RuntimeError.undefinedVariable(name)
    }
}

/// Interpreter that executes the AST
final class Interpreter {
    private var environment = Environment()
    private var returnValue: Value?
    
    /// Executes a program (list of statements)
    func execute(statements: [Statement]) throws {
        for statement in statements {
            try execute(statement: statement)
        }
    }
    
    private func execute(statement: Statement) throws {
        switch statement {
        case .expression(let expr):
            _ = try evaluate(expression: expr)
            
        case .variableDeclaration(let name, _, let expr):
            let value = try evaluate(expression: expr)
            environment.define(name: name, value: value)
            
        case .functionDeclaration(let name, let params, let body):
            let function = Value.function(parameters: params, body: body, closure: environment)
            environment.define(name: name, value: function)
            
        case .ifStatement(let condition, let thenBranch, let elseBranch):
            let condValue = try evaluate(expression: condition)
            if condValue.isTruthy {
                for stmt in thenBranch {
                    try execute(statement: stmt)
                    if returnValue != nil { return }
                }
            } else if let elseBranch = elseBranch {
                for stmt in elseBranch {
                    try execute(statement: stmt)
                    if returnValue != nil { return }
                }
            }
            
        case .whileStatement(let condition, let body):
            while try evaluate(expression: condition).isTruthy {
                for stmt in body {
                    try execute(statement: stmt)
                    if returnValue != nil { return }
                }
            }
            
        case .returnStatement(let expr):
            returnValue = try expr.map { try evaluate(expression: $0) } ?? .void
            
        case .block(let statements):
            try executeBlock(statements: statements, environment: Environment(parent: environment))
        }
    }
    
    private func executeBlock(statements: [Statement], environment: Environment) throws {
        let previous = self.environment
        defer { self.environment = previous }
        
        self.environment = environment
        
        for statement in statements {
            try execute(statement: statement)
            if returnValue != nil { return }
        }
    }
    
    private func evaluate(expression: Expression) throws -> Value {
        switch expression {
        case .number(let value):
            return .number(value)
            
        case .variable(let name):
            return try environment.get(name: name)
            
        case .binary(let op, let left, let right):
            let leftVal = try evaluate(expression: left.value)
            let rightVal = try evaluate(expression: right.value)
            
            guard let leftNum = leftVal.asNumber, let rightNum = rightVal.asNumber else {
                throw RuntimeError.typeError("Expected numbers")
            }
            
            switch op {
            case .add: return .number(leftNum + rightNum)
            case .subtract: return .number(leftNum - rightNum)
            case .multiply: return .number(leftNum * rightNum)
            case .divide: return .number(leftNum / rightNum)
            case .equal: return .number(leftNum == rightNum ? 1 : 0)
            case .notEqual: return .number(leftNum != rightNum ? 1 : 0)
            case .less: return .number(leftNum < rightNum ? 1 : 0)
            case .greater: return .number(leftNum > rightNum ? 1 : 0)
            case .lessEqual: return .number(leftNum <= rightNum ? 1 : 0)
            case .greaterEqual: return .number(leftNum >= rightNum ? 1 : 0)
            }
            
        case .call(let name, let args):
            let function = try environment.get(name: name)
            guard case .function(let params, let body, let closure) = function else {
                throw RuntimeError.notCallable(name)
            }
            
            guard params.count == args.count else {
                throw RuntimeError.arityMismatch(expected: params.count, got: args.count)
            }
            
            let callEnv = Environment(parent: closure)
            for (param, arg) in zip(params, args) {
                let argValue = try evaluate(expression: arg)
                callEnv.define(name: param, value: argValue)
            }
            
            returnValue = nil
            try executeBlock(statements: body, environment: callEnv)
            let result = returnValue ?? .void
            returnValue = nil
            return result
            
        case .assignment(let name, let expr):
            let value = try evaluate(expression: expr.value)
            try environment.assign(name: name, value: value)
            return value
        }
    }
}

enum RuntimeError: Error, CustomStringConvertible {
    case undefinedVariable(String)
    case typeError(String)
    case notCallable(String)
    case arityMismatch(expected: Int, got: Int)
    
    var description: String {
        switch self {
        case .undefinedVariable(let name):
            return "Undefined variable: \(name)"
        case .typeError(let msg):
            return "Type error: \(msg)"
        case .notCallable(let name):
            return "'\(name)' is not callable"
        case .arityMismatch(let expected, let got):
            return "Expected \(expected) arguments but got \(got)"
        }
    }
}

// MARK: - REPL

/// Read-Eval-Print Loop for interactive programming
final class REPL {
    private let interpreter = Interpreter()
    
    func run() {
        print("Welcome to Swift Interpreter REPL")
        print("Type 'exit' to quit\n")
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine(), !input.isEmpty else { continue }
            
            if input == "exit" { break }
            
            do {
                let lexer = Lexer(source: input)
                let tokens = try lexer.tokenize()
                let parser = Parser(tokens: tokens)
                let statements = try parser.parse()
                try interpreter.execute(statements: statements)
            } catch {
                print("Error: \(error)")
            }
        }
        
        print("Goodbye!")
    }
}

// MARK: - Main

@main
struct CompilerInterpreter {
    static func main() {
        print("=== Swift Compiler & Interpreter Demo ===\n")
        
        // Example 1: Variable declarations and arithmetic
        let program1 = """
        let x = 10;
        let y = 20;
        let sum = x + y;
        """
        
        print("Program 1: Variables and Arithmetic")
        print(program1)
        runProgram(program1)
        
        // Example 2: Functions and recursion
        let program2 = """
        func factorial(n) {
            if (n <= 1) {
                return 1;
            } else {
                return n * factorial(n - 1);
            }
        }
        
        let result = factorial(5);
        """
        
        print("\nProgram 2: Factorial Function")
        print(program2)
        runProgram(program2)
        
        // Example 3: While loops
        let program3 = """
        var counter = 0;
        var sum = 0;
        
        while (counter < 10) {
            sum = sum + counter;
            counter = counter + 1;
        }
        """
        
        print("\nProgram 3: While Loop")
        print(program3)
        runProgram(program3)
        
        // Example 4: Fibonacci sequence
        let program4 = """
        func fib(n) {
            if (n <= 1) {
                return n;
            }
            return fib(n - 1) + fib(n - 2);
        }
        
        let f0 = fib(0);
        let f1 = fib(1);
        let f5 = fib(5);
        let f10 = fib(10);
        """
        
        print("\nProgram 4: Fibonacci Sequence")
        print(program4)
        runProgram(program4)
        
        print("\n=== Starting REPL ===")
        print("You can now enter commands interactively.")
        print("Try: let x = 42; or func square(n) { return n * n; }")
        
        // Uncomment to run REPL
        // let repl = REPL()
        // repl.run()
    }
    
    static func runProgram(_ source: String) {
        do {
            let lexer = Lexer(source: source)
            let tokens = try lexer.tokenize()
            print("✓ Lexical analysis completed (\(tokens.count) tokens)")
            
            let parser = Parser(tokens: tokens)
            let statements = try parser.parse()
            print("✓ Parsing completed (\(statements.count) statements)")
            
            let interpreter = Interpreter()
            try interpreter.execute(statements: statements)
            print("✓ Execution completed successfully")
        } catch {
            print("✗ Error: \(error)")
        }
    }
}
