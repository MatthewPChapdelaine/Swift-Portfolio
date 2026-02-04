# Swift Project Template

A basic Swift project structure with Swift Package Manager.

## Structure

```
swift-project-template/
├── Sources/
│   └── SwiftProject/
│       └── main.swift           # Main application code
├── Tests/
│   └── SwiftProjectTests/
│       └── SwiftProjectTests.swift  # Unit tests (XCTest)
├── Package.swift                # Swift Package Manager configuration
└── README.md                   # This file
```

## Setup

```bash
# Install Swift
# https://www.swift.org/download/

# For macOS, Xcode includes Swift
# For Linux, follow Swift installation guide

# Resolve dependencies (if any)
swift package resolve
```

## Usage

```bash
# Run the application
swift run

# Or build and run executable
swift build
.build/debug/SwiftProject
```

## Testing

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter SwiftProjectTests
```

## Build

```bash
# Build in debug mode
swift build

# Build in release mode
swift build -c release

# Build for specific platform
swift build --arch arm64
```

## Development

1. Install Swift (via Xcode on macOS or Swift toolchain on Linux)
2. Run `swift build` to compile the project
3. Make your changes in `Sources/SwiftProject/`
4. Write tests in `Tests/SwiftProjectTests/`
5. Run `swift test` before committing

## REPL

```bash
# Start Swift REPL
swift

# Import package in REPL
swift -I .build/debug -L .build/debug -lSwiftProject
```

## Xcode Integration

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open SwiftProject.xcodeproj
```

## Package Management

```bash
# Update dependencies
swift package update

# Show dependencies
swift package show-dependencies

# Clean build artifacts
swift package clean
```
