#!/usr/bin/env swift

/// Comprehensive Design Patterns Implementation in Swift
/// Demonstrates modern Swift idioms for classic design patterns
///
/// Patterns Implemented:
/// 1. Singleton - Thread-safe shared instance
/// 2. Factory - Object creation abstraction
/// 3. Observer - Event notification system
/// 4. Strategy - Interchangeable algorithms
/// 5. Decorator - Dynamic behavior addition
/// 6. Builder - Complex object construction
/// 7. Adapter - Interface compatibility
///
/// Compile: swiftc -o patterns DesignPatterns.swift
/// Run: ./patterns
/// Or: swift DesignPatterns.swift

import Foundation

// MARK: - 1. Singleton Pattern

/// Thread-safe singleton using Swift's static let (initialized once)
final class ConfigurationManager {
    // Thread-safe singleton
    static let shared = ConfigurationManager()
    
    private var settings: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.config.queue", attributes: .concurrent)
    
    // Private initializer prevents external instantiation
    private init() {
        settings = [
            "appName": "DesignPatterns Demo",
            "version": "1.0.0",
            "debug": true
        ]
    }
    
    /// Thread-safe read operation
    func getSetting<T>(_ key: String) -> T? {
        queue.sync {
            settings[key] as? T
        }
    }
    
    /// Thread-safe write operation
    func setSetting<T>(_ key: String, value: T) {
        queue.async(flags: .barrier) {
            self.settings[key] = value
        }
    }
}

// MARK: - 2. Factory Pattern

/// Product protocol
protocol Vehicle {
    var type: String { get }
    var capacity: Int { get }
    func start()
    func stop()
}

/// Concrete products
struct Car: Vehicle {
    let type = "Car"
    let capacity: Int
    
    func start() {
        print("🚗 Car engine started")
    }
    
    func stop() {
        print("🚗 Car engine stopped")
    }
}

struct Truck: Vehicle {
    let type = "Truck"
    let capacity: Int
    
    func start() {
        print("🚛 Truck engine started")
    }
    
    func stop() {
        print("🚛 Truck engine stopped")
    }
}

struct Motorcycle: Vehicle {
    let type = "Motorcycle"
    let capacity: Int
    
    func start() {
        print("🏍️  Motorcycle engine started")
    }
    
    func stop() {
        print("🏍️  Motorcycle engine stopped")
    }
}

/// Vehicle type enumeration
enum VehicleType {
    case car(passengers: Int)
    case truck(cargo: Int)
    case motorcycle(riders: Int)
}

/// Factory class for creating vehicles
final class VehicleFactory {
    /// Creates vehicle based on type
    static func createVehicle(_ type: VehicleType) -> Vehicle {
        switch type {
        case .car(let passengers):
            return Car(capacity: passengers)
        case .truck(let cargo):
            return Truck(capacity: cargo)
        case .motorcycle(let riders):
            return Motorcycle(capacity: riders)
        }
    }
}

// MARK: - 3. Observer Pattern

/// Observer protocol
protocol EventObserver: AnyObject {
    var id: UUID { get }
    func notify(event: String, data: Any?)
}

/// Concrete observer
class EventLogger: EventObserver {
    let id = UUID()
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    func notify(event: String, data: Any?) {
        if let data = data {
            print("📢 [\(name)] Event: \(event), Data: \(data)")
        } else {
            print("📢 [\(name)] Event: \(event)")
        }
    }
}

/// Subject (Observable)
class EventPublisher {
    private var observers: [UUID: EventObserver] = [:]
    private let queue = DispatchQueue(label: "com.observer.queue", attributes: .concurrent)
    
    /// Add observer
    func subscribe(_ observer: EventObserver) {
        queue.async(flags: .barrier) {
            self.observers[observer.id] = observer
            print("✅ Observer \(observer.id) subscribed")
        }
    }
    
    /// Remove observer
    func unsubscribe(_ observer: EventObserver) {
        queue.async(flags: .barrier) {
            self.observers.removeValue(forKey: observer.id)
            print("❌ Observer \(observer.id) unsubscribed")
        }
    }
    
    /// Notify all observers
    func publish(event: String, data: Any? = nil) {
        queue.sync {
            print("\n🔔 Publishing event: \(event)")
            for observer in observers.values {
                observer.notify(event: event, data: data)
            }
        }
    }
}

// MARK: - 4. Strategy Pattern

/// Strategy protocol
protocol SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T]
}

/// Concrete strategies
struct BubbleSort: SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T] {
        var arr = array
        let n = arr.count
        
        for i in 0..<n {
            for j in 0..<(n - i - 1) {
                if arr[j] > arr[j + 1] {
                    arr.swapAt(j, j + 1)
                }
            }
        }
        return arr
    }
}

struct QuickSort: SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T] {
        guard array.count > 1 else { return array }
        
        let pivot = array[array.count / 2]
        let less = array.filter { $0 < pivot }
        let equal = array.filter { $0 == pivot }
        let greater = array.filter { $0 > pivot }
        
        return sort(less) + equal + sort(greater)
    }
}

struct MergeSort: SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T] {
        guard array.count > 1 else { return array }
        
        let mid = array.count / 2
        let left = sort(Array(array[0..<mid]))
        let right = sort(Array(array[mid..<array.count]))
        
        return merge(left, right)
    }
    
    private func merge<T: Comparable>(_ left: [T], _ right: [T]) -> [T] {
        var result: [T] = []
        var leftIndex = 0
        var rightIndex = 0
        
        while leftIndex < left.count && rightIndex < right.count {
            if left[leftIndex] < right[rightIndex] {
                result.append(left[leftIndex])
                leftIndex += 1
            } else {
                result.append(right[rightIndex])
                rightIndex += 1
            }
        }
        
        result.append(contentsOf: left[leftIndex...])
        result.append(contentsOf: right[rightIndex...])
        
        return result
    }
}

/// Context that uses strategy
class Sorter<T: Comparable> {
    private var strategy: SortingStrategy
    
    init(strategy: SortingStrategy) {
        self.strategy = strategy
    }
    
    func setStrategy(_ strategy: SortingStrategy) {
        self.strategy = strategy
    }
    
    func sort(_ array: [T]) -> [T] {
        return strategy.sort(array)
    }
}

// MARK: - 5. Decorator Pattern

/// Component protocol
protocol Coffee {
    var description: String { get }
    var cost: Double { get }
}

/// Concrete component
struct SimpleCoffee: Coffee {
    var description: String { "Simple Coffee" }
    var cost: Double { 2.0 }
}

/// Decorator base
class CoffeeDecorator: Coffee {
    private let decoratedCoffee: Coffee
    
    init(decoratedCoffee: Coffee) {
        self.decoratedCoffee = decoratedCoffee
    }
    
    var description: String {
        decoratedCoffee.description
    }
    
    var cost: Double {
        decoratedCoffee.cost
    }
}

/// Concrete decorators
class MilkDecorator: CoffeeDecorator {
    override var description: String {
        super.description + ", Milk"
    }
    
    override var cost: Double {
        super.cost + 0.5
    }
}

class SugarDecorator: CoffeeDecorator {
    override var description: String {
        super.description + ", Sugar"
    }
    
    override var cost: Double {
        super.cost + 0.25
    }
}

class VanillaDecorator: CoffeeDecorator {
    override var description: String {
        super.description + ", Vanilla"
    }
    
    override var cost: Double {
        super.cost + 0.75
    }
}

// MARK: - 6. Builder Pattern

/// Complex product
struct Computer {
    let cpu: String
    let ram: Int
    let storage: Int
    let gpu: String?
    let monitor: String?
    
    func specs() -> String {
        var desc = "💻 Computer:\n"
        desc += "  CPU: \(cpu)\n"
        desc += "  RAM: \(ram)GB\n"
        desc += "  Storage: \(storage)GB\n"
        if let gpu = gpu {
            desc += "  GPU: \(gpu)\n"
        }
        if let monitor = monitor {
            desc += "  Monitor: \(monitor)\n"
        }
        return desc
    }
}

/// Builder class
class ComputerBuilder {
    private var cpu: String = "Intel i5"
    private var ram: Int = 8
    private var storage: Int = 256
    private var gpu: String?
    private var monitor: String?
    
    func setCPU(_ cpu: String) -> ComputerBuilder {
        self.cpu = cpu
        return self
    }
    
    func setRAM(_ ram: Int) -> ComputerBuilder {
        self.ram = ram
        return self
    }
    
    func setStorage(_ storage: Int) -> ComputerBuilder {
        self.storage = storage
        return self
    }
    
    func setGPU(_ gpu: String) -> ComputerBuilder {
        self.gpu = gpu
        return self
    }
    
    func setMonitor(_ monitor: String) -> ComputerBuilder {
        self.monitor = monitor
        return self
    }
    
    func build() -> Computer {
        return Computer(
            cpu: cpu,
            ram: ram,
            storage: storage,
            gpu: gpu,
            monitor: monitor
        )
    }
}

// MARK: - 7. Adapter Pattern

/// Target interface
protocol MediaPlayer {
    func play(fileName: String)
}

/// Adaptee with incompatible interface
class AdvancedMediaPlayer {
    func playMP4(fileName: String) {
        print("🎬 Playing MP4 file: \(fileName)")
    }
    
    func playVLC(fileName: String) {
        print("🎬 Playing VLC file: \(fileName)")
    }
}

/// Adapter
class MediaAdapter: MediaPlayer {
    private let advancedPlayer = AdvancedMediaPlayer()
    
    func play(fileName: String) {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "mp4":
            advancedPlayer.playMP4(fileName: fileName)
        case "vlc":
            advancedPlayer.playVLC(fileName: fileName)
        default:
            print("❌ Unsupported format: \(ext)")
        }
    }
}

/// Client class
class AudioPlayer: MediaPlayer {
    private let adapter = MediaAdapter()
    
    func play(fileName: String) {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        if ext == "mp3" {
            print("🎵 Playing MP3 file: \(fileName)")
        } else {
            adapter.play(fileName: fileName)
        }
    }
}

// MARK: - Main Entry Point

@main
struct DesignPatternsDemo {
    static func main() {
        print("╔════════════════════════════════════════╗")
        print("║     Design Patterns in Swift           ║")
        print("╚════════════════════════════════════════╝\n")
        
        demonstrateSingleton()
        demonstrateFactory()
        demonstrateObserver()
        demonstrateStrategy()
        demonstrateDecorator()
        demonstrateBuilder()
        demonstrateAdapter()
        
        print("\n╔════════════════════════════════════════╗")
        print("║     All Patterns Demonstrated!         ║")
        print("╚════════════════════════════════════════╝")
    }
    
    static func demonstrateSingleton() {
        print("\n1️⃣  SINGLETON PATTERN")
        print("═══════════════════════")
        
        let config1 = ConfigurationManager.shared
        let config2 = ConfigurationManager.shared
        
        config1.setSetting("theme", value: "dark")
        
        if let theme: String = config2.getSetting("theme") {
            print("✓ Same instance confirmed - theme: \(theme)")
        }
        
        if let appName: String = config1.getSetting("appName") {
            print("✓ App name: \(appName)")
        }
    }
    
    static func demonstrateFactory() {
        print("\n2️⃣  FACTORY PATTERN")
        print("═══════════════════════")
        
        let vehicles: [Vehicle] = [
            VehicleFactory.createVehicle(.car(passengers: 5)),
            VehicleFactory.createVehicle(.truck(cargo: 1000)),
            VehicleFactory.createVehicle(.motorcycle(riders: 2))
        ]
        
        for vehicle in vehicles {
            print("\n\(vehicle.type) - Capacity: \(vehicle.capacity)")
            vehicle.start()
            vehicle.stop()
        }
    }
    
    static func demonstrateObserver() {
        print("\n3️⃣  OBSERVER PATTERN")
        print("═══════════════════════")
        
        let publisher = EventPublisher()
        
        let logger1 = EventLogger(name: "Logger1")
        let logger2 = EventLogger(name: "Logger2")
        let logger3 = EventLogger(name: "Logger3")
        
        publisher.subscribe(logger1)
        publisher.subscribe(logger2)
        publisher.subscribe(logger3)
        
        publisher.publish(event: "UserLoggedIn", data: "john@example.com")
        
        publisher.unsubscribe(logger2)
        
        publisher.publish(event: "DataUpdated", data: ["count": 42])
    }
    
    static func demonstrateStrategy() {
        print("\n4️⃣  STRATEGY PATTERN")
        print("═══════════════════════")
        
        let numbers = [64, 34, 25, 12, 22, 11, 90]
        print("Original array: \(numbers)")
        
        let sorter = Sorter<Int>(strategy: BubbleSort())
        print("\n🔹 Using BubbleSort: \(sorter.sort(numbers))")
        
        sorter.setStrategy(QuickSort())
        print("🔹 Using QuickSort: \(sorter.sort(numbers))")
        
        sorter.setStrategy(MergeSort())
        print("🔹 Using MergeSort: \(sorter.sort(numbers))")
    }
    
    static func demonstrateDecorator() {
        print("\n5️⃣  DECORATOR PATTERN")
        print("═══════════════════════")
        
        var coffee: Coffee = SimpleCoffee()
        print("☕️ \(coffee.description) - $\(coffee.cost)")
        
        coffee = MilkDecorator(decoratedCoffee: coffee)
        print("☕️ \(coffee.description) - $\(coffee.cost)")
        
        coffee = SugarDecorator(decoratedCoffee: coffee)
        print("☕️ \(coffee.description) - $\(coffee.cost)")
        
        coffee = VanillaDecorator(decoratedCoffee: coffee)
        print("☕️ \(coffee.description) - $\(coffee.cost)")
    }
    
    static func demonstrateBuilder() {
        print("\n6️⃣  BUILDER PATTERN")
        print("═══════════════════════")
        
        let basicComputer = ComputerBuilder()
            .setCPU("Intel i5")
            .setRAM(8)
            .setStorage(256)
            .build()
        
        print(basicComputer.specs())
        
        let gamingComputer = ComputerBuilder()
            .setCPU("AMD Ryzen 9")
            .setRAM(32)
            .setStorage(1000)
            .setGPU("NVIDIA RTX 4090")
            .setMonitor("4K 144Hz")
            .build()
        
        print(gamingComputer.specs())
    }
    
    static func demonstrateAdapter() {
        print("\n7️⃣  ADAPTER PATTERN")
        print("═══════════════════════")
        
        let player = AudioPlayer()
        
        player.play(fileName: "song.mp3")
        player.play(fileName: "movie.mp4")
        player.play(fileName: "video.vlc")
        player.play(fileName: "unknown.xyz")
    }
}

/*
 USAGE INSTRUCTIONS:
 ═══════════════════
 
 1. Run directly:
    swift DesignPatterns.swift
    
 2. Compile and run:
    swiftc -o patterns DesignPatterns.swift
    ./patterns
 
 PATTERNS DEMONSTRATED:
 ═════════════════════
 
 1. SINGLETON
    - Thread-safe shared instance
    - Private initializer
    - Concurrent read/write with DispatchQueue
 
 2. FACTORY
    - Abstract object creation
    - Enum-based type selection
    - Protocol-oriented design
 
 3. OBSERVER
    - Event subscription/notification
    - Weak reference management
    - Thread-safe observer list
 
 4. STRATEGY
    - Interchangeable algorithms
    - Generic implementation
    - Runtime strategy switching
 
 5. DECORATOR
    - Dynamic behavior addition
    - Composition over inheritance
    - Chain of decorators
 
 6. BUILDER
    - Fluent interface
    - Method chaining
    - Complex object construction
 
 7. ADAPTER
    - Interface compatibility
    - Legacy code integration
    - Protocol-based adaptation
 
 SWIFT IDIOMS USED:
 ═════════════════
 
 ✓ Protocols and protocol-oriented programming
 ✓ Value types (struct) vs reference types (class)
 ✓ Generics with constraints
 ✓ Optionals and optional chaining
 ✓ Enums with associated values
 ✓ Extensions and protocol extensions
 ✓ Access control (private, final)
 ✓ Thread-safe concurrent access
 ✓ Type inference
 ✓ Closures and higher-order functions
*/
