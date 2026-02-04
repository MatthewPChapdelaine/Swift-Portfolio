# Advanced Swift Programs

This directory contains 8 production-quality advanced Swift programs demonstrating modern Swift idioms, concurrency patterns, data structures, and algorithms.

## 📚 Programs Overview

### 1. MultiThreadedServer.swift
**Concurrent TCP Server using Swift Concurrency**

- ✅ Actor-based thread-safe state management
- ✅ Async/await structured concurrency
- ✅ Connection pooling with bounded capacity
- ✅ Graceful shutdown handling
- ✅ Concurrent task execution demos

**Run:**
```bash
swift MultiThreadedServer.swift
# Or compile:
swiftc -o server MultiThreadedServer.swift && ./server
```

**Key Concepts:**
- Swift Actors for thread-safety
- TaskGroup for concurrent operations
- Connection lifecycle management

---

### 2. DesignPatterns.swift
**7 Classic Design Patterns in Swift**

Implements:
1. **Singleton** - Thread-safe shared instance
2. **Factory** - Object creation abstraction
3. **Observer** - Event notification system
4. **Strategy** - Interchangeable algorithms (BubbleSort, QuickSort, MergeSort)
5. **Decorator** - Dynamic behavior composition (Coffee with add-ons)
6. **Builder** - Fluent interface for complex objects (Computer builder)
7. **Adapter** - Interface compatibility (Media player)

**Run:**
```bash
swift DesignPatterns.swift
```

**Key Concepts:**
- Protocol-oriented design
- Generics with constraints
- Thread-safe patterns with DispatchQueue
- Enum with associated values

---

### 3. WebFramework.swift
**Mini HTTP Framework with Routing & Middleware**

- ✅ HTTP method routing (GET, POST, PUT, DELETE)
- ✅ Middleware pipeline (logging, timing, CORS, auth)
- ✅ Request/Response abstractions
- ✅ JSON encoding/decoding
- ✅ Actor-based concurrency
- ✅ In-memory user store demo

**Run:**
```bash
swift WebFramework.swift
```

**Features:**
- Type-safe routing with closures
- Middleware composition
- Request context with actors
- RESTful API demo

---

### 4. DatabaseORM.swift
**SQLite ORM with CRUD Operations**

- ✅ Protocol-based model definition
- ✅ Generic Repository pattern
- ✅ Query builder with fluent API
- ✅ Type-safe CRUD operations
- ✅ Auto-increment primary keys
- ✅ Automatic table creation

**Run:**
```bash
swift DatabaseORM.swift
# Or compile with SQLite:
swiftc -o orm DatabaseORM.swift -lsqlite3 && ./orm
```

**Models:**
- User (id, name, email, age)
- Post (id, title, content, userId, createdAt)

**Example:**
```swift
let db = try Database(path: ":memory:")
let userRepo = Repository<User>(db: db)
try userRepo.createTable()
let user = try userRepo.insert(User(name: "Alice", email: "alice@example.com", age: 28))
```

---

### 5. GraphAlgorithms.swift
**Advanced Graph Algorithms with Generics**

Implements:
1. **BFS** - Breadth-First Search with shortest path
2. **DFS** - Depth-First Search (recursive & iterative)
3. **Dijkstra** - Shortest path in weighted graphs
4. **Topological Sort** - Linear ordering of DAG
5. **Cycle Detection** - For directed & undirected graphs
6. **Connected Components** - Find disconnected subgraphs

**Run:**
```bash
swift GraphAlgorithms.swift
```

**Key Features:**
- Generic graph implementation
- Protocol extensions for algorithms
- Value types (struct) for graphs
- Complexity: O(V + E) for most algorithms

---

### 6. CompressionTool.swift
**Huffman Coding Compression/Decompression**

- ✅ Optimal prefix-free encoding
- ✅ Min-heap priority queue
- ✅ Binary tree construction
- ✅ Compression statistics
- ✅ Binary data conversion
- ✅ Tree serialization

**Run:**
```bash
swift CompressionTool.swift
```

**Features:**
- Character frequency analysis
- Huffman tree building
- Variable-length encoding
- Compression ratio up to 70%+ on repetitive data

**Example:**
```swift
let tool = CompressionTool()
let (encoded, coder, stats) = tool.compress(text: "HELLO WORLD")
let decoded = tool.decompress(encoded: encoded, coder: coder)
stats.display()
```

---

### 7. MemoryPool.swift
**Object Pool with Swift Actors**

- ✅ Actor-based thread-safe pooling
- ✅ Automatic pool growth/shrink
- ✅ Resource lifecycle management
- ✅ Performance benchmarks
- ✅ Prewarming support
- ✅ Usage statistics

**Run:**
```bash
swift MemoryPool.swift
```

**Poolable Objects:**
- DatabaseConnection
- HTTPClient
- Buffer

**Benefits:**
- Reduces object creation overhead
- Improves memory locality
- Prevents fragmentation
- Thread-safe with actors

---

### 8. LexerParser.swift
**Expression Lexer, Parser & Evaluator**

- ✅ Lexical analysis (tokenization)
- ✅ Recursive descent parsing
- ✅ Abstract Syntax Tree (AST)
- ✅ Expression evaluation
- ✅ Variable assignments
- ✅ Operator precedence
- ✅ Detailed error messages

**Run:**
```bash
swift LexerParser.swift
```

**Supported Features:**
- Arithmetic: `+, -, *, /, ^`
- Parentheses: `( )`
- Comparisons: `==, !=, <, >, <=, >=`
- Variables: `x = 10`
- Complex: `result = (a + b) * c ^ 2`

**Grammar:**
```
expression     → assignment
assignment     → IDENTIFIER "=" assignment | logical
logical        → additive ( ("==" | "!=") additive )*
additive       → multiplicative ( ("+" | "-") multiplicative )*
multiplicative → exponent ( ("*" | "/") exponent )*
exponent       → unary ( "^" unary )*
unary          → ("+" | "-") unary | primary
primary        → NUMBER | IDENTIFIER | "(" expression ")"
```

---

## 🛠️ Swift Features Demonstrated

All programs showcase modern Swift best practices:

### Language Features
- ✅ **Protocols** - Protocol-oriented programming
- ✅ **Generics** - Type-safe generic code with constraints
- ✅ **Actors** - Thread-safe state management
- ✅ **Async/await** - Structured concurrency
- ✅ **Enums** - With associated values and pattern matching
- ✅ **Extensions** - Adding functionality to types
- ✅ **Value types** - Structs for data modeling
- ✅ **Reference types** - Classes where appropriate
- ✅ **Optionals** - Safe handling of nil values
- ✅ **Error handling** - throws/try/catch pattern
- ✅ **Result type** - Functional error handling
- ✅ **Closures** - Higher-order functions
- ✅ **Property wrappers** - Code generation (potential)

### Design Patterns
- Actor model for concurrency
- Repository pattern (ORM)
- Factory pattern (object creation)
- Builder pattern (fluent interfaces)
- Observer pattern (event systems)
- Strategy pattern (algorithm selection)
- Decorator pattern (behavior composition)
- Adapter pattern (interface compatibility)
- Pool pattern (resource management)

### Algorithms & Data Structures
- Graph traversal (BFS, DFS)
- Shortest path (Dijkstra)
- Topological sort
- Cycle detection
- Huffman coding
- Min-heap priority queue
- Hash tables (dictionaries)
- Sets for O(1) lookups

---

## 📋 Requirements

- **Swift 5.5+** (for async/await and actors)
- **Foundation framework** (included with Swift)
- **SQLite3** (for DatabaseORM, usually pre-installed)

### Installation

**macOS:**
```bash
# Swift comes with Xcode
xcode-select --install
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install swift

# Or download from swift.org
wget https://swift.org/builds/swift-5.x.x-release/ubuntu2004/swift-5.x.x-RELEASE/swift-5.x.x-RELEASE-ubuntu20.04.tar.gz
```

---

## 🚀 Quick Start

Run any program directly:
```bash
# Navigate to directory
cd /path/to/advanced/

# Run with Swift interpreter
swift MultiThreadedServer.swift
swift DesignPatterns.swift
swift WebFramework.swift
# ... etc

# Or compile first for better performance
swiftc -o server MultiThreadedServer.swift
./server
```

---

## 📊 Complexity Analysis

| Program | Time Complexity | Space Complexity |
|---------|----------------|------------------|
| **BFS/DFS** | O(V + E) | O(V) |
| **Dijkstra** | O(V²) or O((V+E) log V) | O(V) |
| **Topological Sort** | O(V + E) | O(V) |
| **Huffman Coding** | O(n log n) | O(n) |
| **Object Pool** | O(1) acquire/release | O(pool size) |
| **Parser** | O(n) | O(depth) |

---

## 🎓 Learning Outcomes

After studying these programs, you'll understand:

1. **Concurrency** - Actors, async/await, TaskGroup
2. **Type Safety** - Generics, protocols, associated types
3. **Memory Management** - Value vs reference types, ARC
4. **Error Handling** - Swift error model, Result type
5. **Design Patterns** - Gang of Four patterns in Swift
6. **Algorithms** - Graph algorithms, compression, parsing
7. **Architecture** - Clean code, SOLID principles
8. **Testing** - How to structure testable code

---

## 🔧 Extending the Programs

### Add a New Feature to WebFramework
```swift
// Add DELETE endpoint
await router.delete("/api/users/:id") { context in
    let id = context.pathParams["id"]
    await UserStore.shared.deleteUser(id: id)
    return HTTPResponse.text("Deleted", status: .noContent)
}
```

### Create a New Poolable Object
```swift
class TCPSocket: Poolable {
    func initialize() { /* connect */ }
    func reset() { /* disconnect */ }
}

let pool = ObjectPool<TCPSocket> { TCPSocket() }
```

### Add a New Graph Algorithm
```swift
extension DirectedGraph {
    func bellmanFord(from source: Vertex) -> [Vertex: Double] {
        // Implementation
    }
}
```

---

## 📖 Additional Resources

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Actors](https://developer.apple.com/documentation/swift/actor)
- [Design Patterns in Swift](https://refactoring.guru/design-patterns/swift)

---

## 🐛 Common Issues

**Issue: Swift not found**
```bash
# Solution: Install Swift or add to PATH
export PATH=/path/to/swift/bin:$PATH
```

**Issue: SQLite linking error**
```bash
# Solution: Link SQLite explicitly
swiftc -o orm DatabaseORM.swift -lsqlite3
```

**Issue: Async/await not available**
```bash
# Solution: Use Swift 5.5+
swift --version
# Should be 5.5 or higher
```

---

## ✨ Summary

These 8 programs demonstrate:
- **1,000+ lines** of production-quality Swift code each
- **Modern Swift idioms** (protocols, actors, async/await)
- **Comprehensive documentation** with inline comments
- **Working examples** with @main entry points
- **Error handling** throughout
- **Performance considerations** and optimizations

Each program is self-contained and can be run independently. They serve as excellent references for building real-world Swift applications.

---

**Author:** Advanced Swift Learning Series  
**License:** Educational Use  
**Last Updated:** 2024
