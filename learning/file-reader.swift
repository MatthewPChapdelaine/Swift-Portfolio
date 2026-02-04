#!/usr/bin/env swift
/*
 * File Reader - Read and display file contents
 * Compile: swiftc file-reader.swift -o file-reader
 * Run: ./file-reader <filename> or swift file-reader.swift <filename>
 */

import Foundation

let args = CommandLine.arguments

if args.count != 2 {
    print("Usage: swift file-reader.swift <filename>")
    exit(1)
}

let filename = args[1]
let fileURL = URL(fileURLWithPath: filename)

do {
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    print("=== Contents of \(filename) ===")
    print(contents, terminator: "")
    print("\n=== End of file (\(contents.count) characters) ===")
} catch let error as NSError {
    if error.domain == NSCocoaErrorDomain {
        switch error.code {
        case NSFileReadNoSuchFileError:
            print("Error: File '\(filename)' not found")
        case NSFileReadNoPermissionError:
            print("Error: Permission denied to read '\(filename)'")
        default:
            print("Error reading file: \(error.localizedDescription)")
        }
    } else {
        print("Error reading file: \(error.localizedDescription)")
    }
}
