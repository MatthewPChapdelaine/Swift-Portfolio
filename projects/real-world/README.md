# Swift Real-World Projects

Three modern projects demonstrating Swift's powerful features and safety.

## Projects

### 1. Blog Engine (`blog-engine/`)
Type-safe blogging with Vapor and async/await.

**Features:**
- Swift concurrency (async/await)
- Vapor web framework
- Fluent ORM with SQLite
- Type-safe models and routes
- Codable for JSON serialization
- Strong compile-time guarantees
- Actor-based concurrency

**Tech Stack:**
- Vapor - Web framework
- Fluent - ORM
- SQLite - Database
- Codable - Serialization

**Run:**
```bash
cd blog-engine
swift build
swift run
```

### 2. Chat Application (`chat-application/`)
Real-time chat with Swift Actors.

**Features:**
- Actor-based concurrency
- WebSocket real-time messaging
- Structured concurrency with Tasks
- Thread-safe state management
- Type-safe message handling
- Modern async patterns
- Value semantics

**Tech Stack:**
- WebSocketKit - WebSockets
- Actors - Concurrency
- Vapor - HTTP server
- Structured Concurrency

**Run:**
```bash
cd chat-application
swift build
swift run
```

### 3. Package Manager (`package-manager/`)
Dependency management with Swift's type system.

**Features:**
- Type-safe dependency resolution
- YAML manifest parsing
- Codable for serialization
- Value types and immutability
- Result types for errors
- Protocol-oriented design
- Swift Package Manager integration

**Tech Stack:**
- Yams - YAML parsing
- Codable - Serialization
- Foundation - Core libraries
- Swift Package Manager

**Run:**
```bash
cd package-manager
swift build
swift run PackageManager install
```

## Swift Paradigms Demonstrated

- **Async/Await**: Modern concurrency
- **Actors**: Thread-safe state
- **Protocols**: Generic abstractions
- **Value Types**: Copy-on-write semantics
- **Optionals**: Safe null handling
- **Result Types**: Error handling
- **Codable**: Automatic serialization
- **Strong Types**: Compile-time safety

## Common Setup

All projects require:
- Swift 5.7+
- Swift Package Manager
- macOS 12+ or Linux

## Learning Path

1. **Package Manager** - Value types and protocols
2. **Blog Engine** - Async/await and databases
3. **Chat Application** - Actors and concurrency

## License

MIT
