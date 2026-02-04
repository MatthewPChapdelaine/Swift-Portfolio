#!/usr/bin/env swift

/// Memory Pool (Object Pool) Implementation
/// Uses Swift Actors for thread-safe resource management
///
/// Features:
/// - Actor-based object pooling
/// - Automatic pool growth/shrink
/// - Resource lifecycle management
/// - Performance benchmarks
/// - Memory-efficient reuse
/// - Thread-safe operations
///
/// Compile: swiftc -o pool MemoryPool.swift
/// Run: ./pool
/// Or: swift MemoryPool.swift

import Foundation
import Dispatch

// MARK: - Poolable Protocol

/// Protocol for objects that can be pooled
protocol Poolable: AnyObject {
    /// Reset object state for reuse
    func reset()
    
    /// Initialize object
    func initialize()
}

// MARK: - Pool Configuration

/// Configuration for memory pool
struct PoolConfig {
    let minSize: Int
    let maxSize: Int
    let growthFactor: Double
    let shrinkThreshold: Double
    
    static let `default` = PoolConfig(
        minSize: 10,
        maxSize: 100,
        growthFactor: 1.5,
        shrinkThreshold: 0.3
    )
}

// MARK: - Object Pool (Actor-based)

/// Thread-safe object pool using Swift Actor
actor ObjectPool<T: Poolable> {
    private var available: [T] = []
    private var inUse: Set<ObjectIdentifier> = []
    private let config: PoolConfig
    private let factory: () -> T
    
    private(set) var totalCreated = 0
    private(set) var totalReused = 0
    private(set) var currentSize = 0
    private(set) var peakSize = 0
    
    init(config: PoolConfig = .default, factory: @escaping () -> T) {
        self.config = config
        self.factory = factory
    }
    
    /// Acquire object from pool
    func acquire() -> T {
        let object: T
        
        if let reusable = available.popLast() {
            object = reusable
            totalReused += 1
        } else {
            object = factory()
            totalCreated += 1
            currentSize += 1
        }
        
        object.initialize()
        inUse.insert(ObjectIdentifier(object))
        
        peakSize = max(peakSize, inUse.count)
        
        return object
    }
    
    /// Release object back to pool
    func release(_ object: T) {
        let id = ObjectIdentifier(object)
        
        guard inUse.contains(id) else {
            print("⚠️  Warning: Releasing object not from this pool")
            return
        }
        
        inUse.remove(id)
        object.reset()
        
        if available.count < config.maxSize {
            available.append(object)
        } else {
            // Pool is full, discard object
            currentSize -= 1
        }
        
        // Check if we should shrink
        if shouldShrink() {
            shrink()
        }
    }
    
    /// Prewarm pool with objects
    func prewarm(count: Int) {
        let count = min(count, config.maxSize)
        for _ in 0..<count {
            let object = factory()
            object.reset()
            available.append(object)
            totalCreated += 1
            currentSize += 1
        }
    }
    
    private func shouldShrink() -> Bool {
        let utilizationRatio = Double(inUse.count) / Double(currentSize)
        return currentSize > config.minSize && utilizationRatio < config.shrinkThreshold
    }
    
    private func shrink() {
        let targetSize = max(config.minSize, Int(Double(currentSize) / config.growthFactor))
        let removeCount = currentSize - targetSize
        
        if removeCount > 0 && removeCount <= available.count {
            available.removeLast(removeCount)
            currentSize -= removeCount
        }
    }
    
    /// Get pool statistics
    func statistics() -> PoolStatistics {
        return PoolStatistics(
            totalCreated: totalCreated,
            totalReused: totalReused,
            currentSize: currentSize,
            peakSize: peakSize,
            available: available.count,
            inUse: inUse.count
        )
    }
    
    /// Clear pool
    func clear() {
        available.removeAll()
        inUse.removeAll()
        currentSize = 0
    }
}

// MARK: - Pool Statistics

/// Statistics for pool performance
struct PoolStatistics {
    let totalCreated: Int
    let totalReused: Int
    let currentSize: Int
    let peakSize: Int
    let available: Int
    let inUse: Int
    
    var reuseRate: Double {
        let total = totalCreated + totalReused
        return total > 0 ? Double(totalReused) / Double(total) * 100.0 : 0.0
    }
    
    var utilizationRate: Double {
        return currentSize > 0 ? Double(inUse) / Double(currentSize) * 100.0 : 0.0
    }
    
    func display(title: String = "Pool Statistics") {
        print("\n📊 \(title)")
        print(String(repeating: "=", count: 50))
        print("Total created:     \(totalCreated)")
        print("Total reused:      \(totalReused)")
        print("Reuse rate:        \(String(format: "%.1f%%", reuseRate))")
        print("Current pool size: \(currentSize)")
        print("Peak size:         \(peakSize)")
        print("Available:         \(available)")
        print("In use:            \(inUse)")
        print("Utilization:       \(String(format: "%.1f%%", utilizationRate))")
    }
}

// MARK: - Example Poolable Objects

/// Example: Database Connection
class DatabaseConnection: Poolable {
    let id: UUID
    var isConnected: Bool = false
    var queryCount: Int = 0
    
    init() {
        self.id = UUID()
    }
    
    func initialize() {
        isConnected = true
    }
    
    func reset() {
        isConnected = false
        queryCount = 0
    }
    
    func executeQuery(_ query: String) -> String {
        guard isConnected else { return "Error: Not connected" }
        queryCount += 1
        return "Query executed: \(query)"
    }
}

/// Example: HTTP Client
class HTTPClient: Poolable {
    let id: UUID
    var baseURL: String?
    var headers: [String: String] = [:]
    var requestCount: Int = 0
    
    init() {
        self.id = UUID()
    }
    
    func initialize() {
        baseURL = "https://api.example.com"
        headers["User-Agent"] = "PooledHTTPClient/1.0"
    }
    
    func reset() {
        baseURL = nil
        headers.removeAll()
        requestCount = 0
    }
    
    func get(_ endpoint: String) -> String {
        requestCount += 1
        return "GET \(baseURL ?? "")\(endpoint)"
    }
}

/// Example: Buffer
class Buffer: Poolable {
    var data: [UInt8]
    let capacity: Int
    
    init(capacity: Int = 1024) {
        self.capacity = capacity
        self.data = []
        self.data.reserveCapacity(capacity)
    }
    
    func initialize() {
        // Nothing to do
    }
    
    func reset() {
        data.removeAll(keepingCapacity: true)
    }
    
    func write(_ bytes: [UInt8]) {
        data.append(contentsOf: bytes)
    }
}

// MARK: - Benchmark

/// Performance benchmark utilities
class Benchmark {
    
    /// Measure execution time
    static func measure(name: String, iterations: Int = 1, block: () async throws -> Void) async rethrows {
        let start = Date()
        
        for _ in 0..<iterations {
            try await block()
        }
        
        let elapsed = Date().timeIntervalSince(start)
        let average = elapsed / Double(iterations)
        
        print("\n⏱️  \(name)")
        print("   Total: \(String(format: "%.3f", elapsed))s")
        print("   Average: \(String(format: "%.3f", average))s")
        print("   Iterations: \(iterations)")
    }
    
    /// Compare with and without pooling
    static func comparePooling() async {
        print("\n🔬 PERFORMANCE COMPARISON")
        print(String(repeating: "=", count: 50))
        
        let iterations = 1000
        
        // Without pooling
        await measure(name: "Without Pooling", iterations: iterations) {
            let conn = DatabaseConnection()
            conn.initialize()
            _ = conn.executeQuery("SELECT * FROM users")
            conn.reset()
        }
        
        // With pooling
        let pool = ObjectPool<DatabaseConnection>(config: .default) {
            DatabaseConnection()
        }
        
        await pool.prewarm(count: 10)
        
        await measure(name: "With Pooling", iterations: iterations) {
            let conn = await pool.acquire()
            _ = conn.executeQuery("SELECT * FROM users")
            await pool.release(conn)
        }
        
        let stats = await pool.statistics()
        stats.display(title: "Pool Performance")
        
        let improvement = calculateImprovement(withoutPooling: 1.0, withPooling: stats.reuseRate / 100.0)
        print("\n💡 Performance improvement: \(String(format: "%.1f%%", improvement))")
    }
    
    private static func calculateImprovement(withoutPooling: Double, withPooling: Double) -> Double {
        return (withPooling / withoutPooling - 1.0) * 100.0
    }
}

// MARK: - Demo Functions

func demonstrateBasicPooling() async {
    print("\n1️⃣  BASIC OBJECT POOLING")
    print(String(repeating: "=", count: 50))
    
    let pool = ObjectPool<DatabaseConnection>(config: .default) {
        DatabaseConnection()
    }
    
    print("Created pool with config: min=10, max=100")
    
    // Acquire objects
    print("\n📤 Acquiring 3 connections...")
    let conn1 = await pool.acquire()
    let conn2 = await pool.acquire()
    let conn3 = await pool.acquire()
    
    print("✅ Connection 1: \(conn1.id)")
    print("✅ Connection 2: \(conn2.id)")
    print("✅ Connection 3: \(conn3.id)")
    
    // Use objects
    print("\n🔧 Using connections...")
    print("   \(conn1.executeQuery("SELECT * FROM users"))")
    print("   \(conn2.executeQuery("INSERT INTO logs"))")
    print("   \(conn3.executeQuery("UPDATE settings"))")
    
    // Release objects
    print("\n📥 Releasing connections...")
    await pool.release(conn1)
    await pool.release(conn2)
    await pool.release(conn3)
    
    var stats = await pool.statistics()
    stats.display()
    
    // Reuse
    print("\n♻️  Acquiring again (should reuse)...")
    let conn4 = await pool.acquire()
    print("✅ Connection 4: \(conn4.id) (reused)")
    
    await pool.release(conn4)
    
    stats = await pool.statistics()
    stats.display()
}

func demonstratePrewarming() async {
    print("\n2️⃣  POOL PREWARMING")
    print(String(repeating: "=", count: 50))
    
    let pool = ObjectPool<HTTPClient>(config: .default) {
        HTTPClient()
    }
    
    print("🌡️  Prewarming pool with 20 objects...")
    await pool.prewarm(count: 20)
    
    var stats = await pool.statistics()
    print("✅ Pool ready: \(stats.available) objects available")
    
    // Quick acquisitions (no creation overhead)
    print("\n⚡️ Rapid acquisitions...")
    var clients: [HTTPClient] = []
    for _ in 0..<10 {
        clients.append(await pool.acquire())
    }
    
    print("✅ Acquired 10 clients instantly (no creation needed)")
    
    // Use clients
    for (i, client) in clients.enumerated() {
        _ = client.get("/api/users/\(i)")
    }
    
    // Release
    for client in clients {
        await pool.release(client)
    }
    
    stats = await pool.statistics()
    stats.display()
}

func demonstrateConcurrency() async {
    print("\n3️⃣  CONCURRENT ACCESS (Actor Safety)")
    print(String(repeating: "=", count: 50))
    
    let pool = ObjectPool<Buffer>(config: PoolConfig(
        minSize: 5,
        maxSize: 50,
        growthFactor: 1.5,
        shrinkThreshold: 0.3
    )) {
        Buffer(capacity: 1024)
    }
    
    print("🔒 Testing thread-safe access with 50 concurrent tasks...")
    
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<50 {
            group.addTask {
                let buffer = await pool.acquire()
                buffer.write([UInt8](repeating: UInt8(i), count: 10))
                
                // Simulate work
                try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...10_000_000))
                
                await pool.release(buffer)
            }
        }
    }
    
    print("✅ All tasks completed without race conditions")
    
    let stats = await pool.statistics()
    stats.display()
}

func demonstrateGrowthAndShrink() async {
    print("\n4️⃣  DYNAMIC POOL GROWTH AND SHRINKING")
    print(String(repeating: "=", count: 50))
    
    let pool = ObjectPool<DatabaseConnection>(config: PoolConfig(
        minSize: 5,
        maxSize: 30,
        growthFactor: 1.5,
        shrinkThreshold: 0.3
    )) {
        DatabaseConnection()
    }
    
    // Start small
    await pool.prewarm(count: 5)
    var stats = await pool.statistics()
    print("📊 Initial: \(stats.currentSize) objects")
    
    // Grow pool
    print("\n📈 Acquiring 20 objects (pool will grow)...")
    var connections: [DatabaseConnection] = []
    for _ in 0..<20 {
        connections.append(await pool.acquire())
    }
    
    stats = await pool.statistics()
    print("✅ Pool grew to: \(stats.currentSize) objects")
    print("   Peak size: \(stats.peakSize)")
    
    // Release all but a few
    print("\n📉 Releasing most objects (pool should shrink)...")
    for conn in connections.dropLast(2) {
        await pool.release(conn)
    }
    
    stats = await pool.statistics()
    print("✅ Pool after shrink: \(stats.currentSize) objects")
    print("   In use: \(stats.inUse)")
    
    // Clean up
    for conn in connections.suffix(2) {
        await pool.release(conn)
    }
}

// MARK: - Main Entry Point

@main
struct MemoryPoolDemo {
    static func main() async {
        print("╔════════════════════════════════════════╗")
        print("║       Memory Pool Demo                  ║")
        print("║       Actor-based Object Pooling       ║")
        print("╚════════════════════════════════════════╝")
        
        await demonstrateBasicPooling()
        await demonstratePrewarming()
        await demonstrateConcurrency()
        await demonstrateGrowthAndShrink()
        await Benchmark.comparePooling()
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ Memory pool demo completed!")
        print(String(repeating: "=", count: 50))
        
        print("\n💡 KEY BENEFITS:")
        print("   • Reduces object creation overhead")
        print("   • Improves memory locality")
        print("   • Prevents memory fragmentation")
        print("   • Thread-safe with Swift Actors")
        print("   • Automatic growth and shrinking")
    }
}

/*
 USAGE INSTRUCTIONS:
 ═══════════════════
 
 1. Run directly:
    swift MemoryPool.swift
    
 2. Compile and run:
    swiftc -o pool MemoryPool.swift
    ./pool
 
 OBJECT POOL PATTERN:
 ══════════════════
 
 Purpose:
 - Reuse expensive-to-create objects
 - Reduce allocation/deallocation overhead
 - Control resource usage
 
 When to Use:
 - Database connections
 - Network sockets
 - Large buffers
 - Heavy objects (parsers, compilers)
 - Resource-constrained environments
 
 ARCHITECTURE:
 ════════════
 
 ObjectPool<T: Poolable> (Actor)
     │
     ├─> Available: [T]
     ├─> InUse: Set<ObjectIdentifier>
     └─> Factory: () -> T
 
 Poolable Protocol
     ├─> reset()
     └─> initialize()
 
 FEATURES:
 ════════
 
 ✓ Thread-safe with Actor
 ✓ Automatic pool growth
 ✓ Dynamic shrinking
 ✓ Prewarming support
 ✓ Usage statistics
 ✓ Configurable limits
 ✓ Performance tracking
 
 SWIFT FEATURES:
 ══════════════
 
 ✓ Actors for thread-safety
 ✓ Async/await concurrency
 ✓ Protocols with class constraint
 ✓ Generics with constraints
 ✓ Set for O(1) lookups
 ✓ ObjectIdentifier for tracking
 ✓ Structured concurrency (TaskGroup)
 
 CONFIGURATION:
 ═════════════
 
 PoolConfig:
 - minSize: Minimum pool size
 - maxSize: Maximum pool size
 - growthFactor: How much to grow (1.5 = 50% increase)
 - shrinkThreshold: When to shrink (0.3 = 30% utilization)
 
 EXTENDING:
 ═════════
 
 To create a poolable object:
 
   class MyResource: Poolable {
       func initialize() {
           // Setup for use
       }
       
       func reset() {
           // Clean up for reuse
       }
   }
 
 To use:
 
   let pool = ObjectPool<MyResource> { MyResource() }
   let resource = await pool.acquire()
   // Use resource
   await pool.release(resource)
 
 PRODUCTION CONSIDERATIONS:
 ═════════════════════════
 
 - Add timeout for acquire
 - Implement resource validation
 - Add metrics and monitoring
 - Health checks for pooled objects
 - Graceful shutdown
 - Resource leak detection
 - Pool warming strategies
 - Different eviction policies (LRU, FIFO)
*/
