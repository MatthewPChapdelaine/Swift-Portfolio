#!/usr/bin/env swift
/*
 * CLI Calculator - Perform basic arithmetic operations
 * Compile: swiftc cli-calculator.swift -o cli-calculator
 * Run: ./cli-calculator or swift cli-calculator.swift
 */

import Foundation

print("=== CLI Calculator ===")
print("Operations: +, -, *, /")

print("Enter first number: ", terminator: "")
guard let num1Str = readLine(), let num1 = Double(num1Str) else {
    print("Error: Invalid number input")
    exit(1)
}

print("Enter operator (+, -, *, /): ", terminator: "")
guard let operatorStr = readLine() else {
    print("Error: Invalid operator")
    exit(1)
}

print("Enter second number: ", terminator: "")
guard let num2Str = readLine(), let num2 = Double(num2Str) else {
    print("Error: Invalid number input")
    exit(1)
}

let result: Double

switch operatorStr {
case "+":
    result = num1 + num2
case "-":
    result = num1 - num2
case "*":
    result = num1 * num2
case "/":
    if num2 == 0 {
        print("Error: Cannot divide by zero")
        exit(1)
    }
    result = num1 / num2
default:
    print("Error: Invalid operator")
    exit(1)
}

print("Result: \(num1) \(operatorStr) \(num2) = \(result)")
