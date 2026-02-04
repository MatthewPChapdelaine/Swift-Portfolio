# Quick Reference Guide - Advanced Swift Programs

## 🎯 One-Line Summary Per Program

| # | Program | What It Does | Key Feature |
|---|---------|--------------|-------------|
| 1 | **MultiThreadedServer.swift** | Concurrent TCP server | Actor-based concurrency |
| 2 | **DesignPatterns.swift** | 7 design patterns | Protocol-oriented patterns |
| 3 | **WebFramework.swift** | HTTP framework + routing | Middleware pipeline |
| 4 | **DatabaseORM.swift** | SQLite ORM system | Generic repositories |
| 5 | **GraphAlgorithms.swift** | 6 graph algorithms | Generic graphs |
| 6 | **CompressionTool.swift** | Huffman compression | Optimal encoding |
| 7 | **MemoryPool.swift** | Object pooling | Actor-based pooling |
| 8 | **LexerParser.swift** | Expression parser | AST evaluation |

---

## 🚀 Quick Run Commands

```bash
# Run any program directly
swift <ProgramName>.swift

# Examples:
swift MultiThreadedServer.swift    # Demo: Async server with 5 clients
swift DesignPatterns.swift         # Demo: All 7 patterns
swift WebFramework.swift           # Demo: HTTP routes + middleware
swift DatabaseORM.swift            # Demo: CRUD operations
swift GraphAlgorithms.swift        # Demo: All 6 algorithms
swift CompressionTool.swift        # Demo: Text compression
swift MemoryPool.swift             # Demo: Object pooling + benchmarks
swift LexerParser.swift            # Demo: Math expression parsing
```

---

## 📊 Program Statistics

```
Total Programs:        8
Total Lines of Code:   5,180+
Total File Size:       184KB
Documentation:         Extensive inline + README
Test Coverage:         Working demos in each program
Swift Version:         5.5+ (requires async/await)
External Dependencies: None (only Foundation + SQLite3)
```

---

## 🎓 Learning Path

### Beginner → Intermediate
1. Start with **DesignPatterns.swift** - Learn foundational patterns
2. Then **GraphAlgorithms.swift** - Understand data structures
3. Move to **LexerParser.swift** - Build a real parser

### Intermediate → Advanced
4. Study **MultiThreadedServer.swift** - Master concurrency
5. Explore **MemoryPool.swift** - Understand resource management
6. Deep dive **DatabaseORM.swift** - Build data layers

### Advanced Projects
7. **WebFramework.swift** - Create production frameworks
8. **CompressionTool.swift** - Implement complex algorithms

---

## 💡 Key Concepts Covered

### Concurrency
- ✅ Actors (thread-safe state)
- ✅ Async/await (structured concurrency)
- ✅ TaskGroup (parallel execution)
- ✅ DispatchQueue (traditional concurrency)

### Type System
- ✅ Protocols (interface abstraction)
- ✅ Generics (type-safe reuse)
- ✅ Associated types (protocol generics)
- ✅ Enums with values (algebraic types)

### Memory Management
- ✅ Value types (struct, enum)
- ✅ Reference types (class)
- ✅ ARC (automatic reference counting)
- ✅ Object pooling (resource reuse)

### Architecture
- ✅ Protocol-oriented programming
- ✅ SOLID principles
- ✅ Design patterns (GoF)
- ✅ Clean code practices

### Algorithms
- ✅ Graph algorithms (BFS, DFS, Dijkstra)
- ✅ Sorting (Bubble, Quick, Merge)
- ✅ Compression (Huffman)
- ✅ Parsing (recursive descent)

---

## 🔧 Code Snippets

### Using the ORM
```swift
// Define a model
struct Product: Model {
    typealias ID = Int
    var id: Int?
    var name: String
    var price: Double
    
    static let tableName = "products"
    static let columns: [Column] = [
        Column(name: "id", type: .integer, isPrimaryKey: true, isAutoIncrement: true),
        Column(name: "name", type: .text, isNotNull: true),
        Column(name: "price", type: .real, isNotNull: true)
    ]
    // ... implement protocol methods
}

// Use it
let db = try Database(path: "app.db")
let repo = Repository<Product>(db: db)
try repo.createTable()
try repo.insert(Product(name: "iPhone", price: 999.99))
```

### Using the Parser
```swift
let interpreter = Interpreter()
try interpreter.evaluate("x = 10")
try interpreter.evaluate("y = 20")
let result = try interpreter.evaluate("(x + y) * 2")  // 60
```

### Using the Object Pool
```swift
let pool = ObjectPool<DatabaseConnection> {
    DatabaseConnection()
}
await pool.prewarm(count: 10)

let conn = await pool.acquire()
conn.executeQuery("SELECT * FROM users")
await pool.release(conn)
```

### Using Graph Algorithms
```swift
var graph = DirectedGraph<String>()
graph.addEdge(from: "A", to: "B", weight: 5.0)
graph.addEdge(from: "B", to: "C", weight: 3.0)

let bfsResult = graph.bfs(from: "A")
let dijkstra = graph.dijkstra(from: "A")
```

---

## 📝 Common Patterns

### Error Handling Pattern
```swift
enum MyError: Error {
    case invalidInput
    case networkFailure
}

func process() throws -> Result {
    guard isValid else {
        throw MyError.invalidInput
    }
    return result
}

// Usage
do {
    let result = try process()
} catch {
    print("Error: \(error)")
}
```

### Actor Pattern (Thread-Safe)
```swift
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1
    }
    
    func getValue() -> Int {
        return value
    }
}

// Usage
let counter = Counter()
await counter.increment()
let value = await counter.getValue()
```

### Generic Repository Pattern
```swift
class Repository<T: Model> where T.ID == Int {
    func find(id: Int) throws -> T?
    func findAll() throws -> [T]
    func insert(_ model: T) throws -> T
    func update(_ model: T) throws
    func delete(id: Int) throws
}
```

---

## 🎯 Performance Tips

1. **Use value types** (struct) by default for data
2. **Use actors** for shared mutable state
3. **Pool expensive objects** (connections, buffers)
4. **Use lazy initialization** for heavy resources
5. **Avoid retain cycles** with weak/unowned
6. **Profile before optimizing** with Instruments

---

## 🔍 Debugging Tips

```swift
// Print with context
print("DEBUG [\(#file):\(#line)] \(#function): \(value)")

// Conditional compilation
#if DEBUG
    print("Debug info: \(details)")
#endif

// Assert in development
assert(value > 0, "Value must be positive")
precondition(isValid, "Invalid state")
```

---

## 📚 Related Reading

- **Swift Documentation**: https://docs.swift.org
- **Swift Evolution**: https://github.com/apple/swift-evolution
- **WWDC Sessions**: Search "Swift Concurrency" on developer.apple.com
- **Ray Wenderlich**: iOS & Swift tutorials
- **Hacking with Swift**: Free Swift tutorials

---

## ✅ Checklist for Each Program

Before running:
- [ ] Swift 5.5+ installed
- [ ] Read the file header comments
- [ ] Review the @main entry point
- [ ] Check compile instructions
- [ ] Run and observe output

For learning:
- [ ] Read all inline comments
- [ ] Understand the architecture section
- [ ] Try modifying the code
- [ ] Add new features
- [ ] Write unit tests

---

## 🎉 What's Next?

After mastering these programs:

1. **Combine them** - Build a web app with ORM + framework
2. **Add features** - Extend each program with new capabilities
3. **Optimize** - Profile and improve performance
4. **Test** - Write comprehensive unit tests
5. **Deploy** - Package as libraries or executables
6. **Contribute** - Share improvements or new patterns

---

## 📞 Need Help?

- Check the comprehensive README.md
- Read inline documentation (/// comments)
- Review the "USAGE INSTRUCTIONS" at bottom of each file
- Study the demo functions in each program
- Experiment with modifications

---

**Happy Coding! 🚀**

Each program is a complete, working example that you can learn from, modify, and extend.
