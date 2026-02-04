#!/usr/bin/env swift

import Foundation

// MARK: - Window Types

/// Types of time windows for stream processing
enum WindowType {
    case tumbling(duration: Duration)
    case sliding(size: Duration, slide: Duration)
    case session(gap: Duration)
    case count(size: Int)
}

// MARK: - Event

/// Generic stream event with timestamp
struct Event<T>: Sendable where T: Sendable {
    let data: T
    let timestamp: Date
    let id: UUID
    
    init(data: T, timestamp: Date = Date()) {
        self.data = data
        self.timestamp = timestamp
        self.id = UUID()
    }
}

// MARK: - Window

/// Represents a window of events
struct Window<T>: Sendable where T: Sendable {
    let events: [Event<T>]
    let start: Date
    let end: Date
    let windowType: String
    
    var count: Int { events.count }
    
    func map<U>(_ transform: (T) -> U) -> [U] {
        return events.map { transform($0.data) }
    }
}

// MARK: - Stream Operator Protocol

/// Protocol for stream operators
protocol StreamOperator {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func process(_ input: Input) async -> Output?
}

// MARK: - Map Operator

/// Maps each element to a new value
struct MapOperator<T: Sendable, U: Sendable>: StreamOperator {
    typealias Input = Event<T>
    typealias Output = Event<U>
    
    let transform: @Sendable (T) -> U
    
    func process(_ input: Event<T>) async -> Event<U>? {
        return Event(data: transform(input.data), timestamp: input.timestamp)
    }
}

// MARK: - Filter Operator

/// Filters events based on predicate
struct FilterOperator<T: Sendable>: StreamOperator {
    typealias Input = Event<T>
    typealias Output = Event<T>
    
    let predicate: @Sendable (T) -> Bool
    
    func process(_ input: Event<T>) async -> Event<T>? {
        return predicate(input.data) ? input : nil
    }
}

// MARK: - Window Operator

/// Windows events based on time or count
actor WindowOperator<T: Sendable> {
    private var windows: [UUID: [Event<T>]] = [:]
    private var currentWindow: [Event<T>] = []
    private var windowStartTime: Date?
    
    private let windowType: WindowType
    
    init(windowType: WindowType) {
        self.windowType = windowType
    }
    
    func process(_ event: Event<T>) async -> [Window<T>] {
        switch windowType {
        case .tumbling(let duration):
            return await processTumblingWindow(event, duration: duration)
            
        case .sliding(let size, let slide):
            return await processSlidingWindow(event, size: size, slide: slide)
            
        case .session(let gap):
            return await processSessionWindow(event, gap: gap)
            
        case .count(let size):
            return await processCountWindow(event, size: size)
        }
    }
    
    private func processTumblingWindow(_ event: Event<T>, duration: Duration) async -> [Window<T>] {
        if windowStartTime == nil {
            windowStartTime = event.timestamp
        }
        
        currentWindow.append(event)
        
        let elapsed = event.timestamp.timeIntervalSince(windowStartTime!)
        let durationSeconds = Double(duration.components.seconds) + 
                             Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
        
        if elapsed >= durationSeconds {
            let window = Window(
                events: currentWindow,
                start: windowStartTime!,
                end: event.timestamp,
                windowType: "tumbling"
            )
            
            currentWindow = []
            windowStartTime = nil
            
            return [window]
        }
        
        return []
    }
    
    private func processSlidingWindow(_ event: Event<T>, size: Duration, slide: Duration) async -> [Window<T>] {
        currentWindow.append(event)
        
        let sizeSeconds = Double(size.components.seconds)
        let now = event.timestamp
        
        // Remove events outside the window
        currentWindow = currentWindow.filter { evt in
            now.timeIntervalSince(evt.timestamp) <= sizeSeconds
        }
        
        // Emit window if we have events
        if !currentWindow.isEmpty {
            let start = currentWindow.first!.timestamp
            let window = Window(
                events: currentWindow,
                start: start,
                end: now,
                windowType: "sliding"
            )
            return [window]
        }
        
        return []
    }
    
    private func processSessionWindow(_ event: Event<T>, gap: Duration) async -> [Window<T>] {
        let gapSeconds = Double(gap.components.seconds)
        
        if let lastEvent = currentWindow.last {
            let timeSinceLastEvent = event.timestamp.timeIntervalSince(lastEvent.timestamp)
            
            if timeSinceLastEvent > gapSeconds {
                // Gap exceeded, emit current window and start new one
                let window = Window(
                    events: currentWindow,
                    start: currentWindow.first!.timestamp,
                    end: lastEvent.timestamp,
                    windowType: "session"
                )
                
                currentWindow = [event]
                return [window]
            }
        }
        
        currentWindow.append(event)
        return []
    }
    
    private func processCountWindow(_ event: Event<T>, size: Int) async -> [Window<T>] {
        currentWindow.append(event)
        
        if currentWindow.count >= size {
            let window = Window(
                events: currentWindow,
                start: currentWindow.first!.timestamp,
                end: currentWindow.last!.timestamp,
                windowType: "count"
            )
            
            currentWindow = []
            return [window]
        }
        
        return []
    }
    
    func flush() async -> [Window<T>] {
        guard !currentWindow.isEmpty else { return [] }
        
        let window = Window(
            events: currentWindow,
            start: currentWindow.first!.timestamp,
            end: currentWindow.last!.timestamp,
            windowType: "final"
        )
        
        currentWindow = []
        return [window]
    }
}

// MARK: - Aggregation Functions

/// Common aggregation functions for windows
enum Aggregation {
    static func sum<T: Numeric>(_ values: [T]) -> T {
        return values.reduce(T.zero, +)
    }
    
    static func average<T: BinaryFloatingPoint>(_ values: [T]) -> T {
        guard !values.isEmpty else { return T.zero }
        return values.reduce(T.zero, +) / T(values.count)
    }
    
    static func min<T: Comparable>(_ values: [T]) -> T? {
        return values.min()
    }
    
    static func max<T: Comparable>(_ values: [T]) -> T? {
        return values.max()
    }
    
    static func count<T>(_ values: [T]) -> Int {
        return values.count
    }
}

// MARK: - Stream Processor

/// Main stream processing engine with backpressure support
actor StreamProcessor<T: Sendable> {
    typealias EventHandler = @Sendable (Event<T>) async throws -> Void
    typealias WindowHandler = @Sendable (Window<T>) async throws -> Void
    
    private var eventHandler: EventHandler?
    private var windowHandler: WindowHandler?
    
    private var buffer: [Event<T>] = []
    private let maxBufferSize: Int
    private var droppedEvents = 0
    
    private(set) var eventsProcessed = 0
    private(set) var windowsEmitted = 0
    private(set) var bytesProcessed = 0
    
    init(maxBufferSize: Int = 10000) {
        self.maxBufferSize = maxBufferSize
    }
    
    func onEvent(_ handler: @escaping EventHandler) {
        self.eventHandler = handler
    }
    
    func onWindow(_ handler: @escaping WindowHandler) {
        self.windowHandler = handler
    }
    
    func ingest(_ event: Event<T>) async throws {
        // Backpressure: drop events if buffer is full
        if buffer.count >= maxBufferSize {
            droppedEvents += 1
            return
        }
        
        buffer.append(event)
        eventsProcessed += 1
        
        try await eventHandler?(event)
    }
    
    func emitWindow(_ window: Window<T>) async throws {
        try await windowHandler?(window)
        windowsEmitted += 1
    }
    
    func getStatistics() -> ProcessorStatistics {
        return ProcessorStatistics(
            eventsProcessed: eventsProcessed,
            windowsEmitted: windowsEmitted,
            bufferSize: buffer.count,
            droppedEvents: droppedEvents
        )
    }
}

struct ProcessorStatistics {
    let eventsProcessed: Int
    let windowsEmitted: Int
    let bufferSize: Int
    let droppedEvents: Int
}

// MARK: - Stream

/// High-level stream API with fluent interface
actor Stream<T: Sendable> {
    private let source: AsyncStream<Event<T>>
    private let processor: StreamProcessor<T>
    
    init(source: AsyncStream<Event<T>>, processor: StreamProcessor<T>) {
        self.source = source
        self.processor = processor
    }
    
    /// Map events to a new type
    func map<U: Sendable>(_ transform: @escaping @Sendable (T) -> U) -> Stream<U> {
        let (stream, continuation) = AsyncStream<Event<U>>.makeStream()
        let newProcessor = StreamProcessor<U>()
        
        Task {
            for await event in source {
                let mapped = Event(data: transform(event.data), timestamp: event.timestamp)
                continuation.yield(mapped)
                try? await processor.ingest(event)
            }
            continuation.finish()
        }
        
        return Stream<U>(source: stream, processor: newProcessor)
    }
    
    /// Filter events
    func filter(_ predicate: @escaping @Sendable (T) -> Bool) -> Stream<T> {
        let (stream, continuation) = AsyncStream<Event<T>>.makeStream()
        let newProcessor = StreamProcessor<T>()
        
        Task {
            for await event in source {
                if predicate(event.data) {
                    continuation.yield(event)
                }
                try? await processor.ingest(event)
            }
            continuation.finish()
        }
        
        return Stream(source: stream, processor: newProcessor)
    }
    
    /// Window events
    func window(type: WindowType) -> AsyncStream<Window<T>> {
        let (stream, continuation) = AsyncStream<Window<T>>.makeStream()
        let windowOp = WindowOperator<T>(windowType: type)
        
        Task {
            for await event in source {
                let windows = await windowOp.process(event)
                for window in windows {
                    continuation.yield(window)
                    try? await processor.emitWindow(window)
                }
                try? await processor.ingest(event)
            }
            
            // Flush remaining windows
            let finalWindows = await windowOp.flush()
            for window in finalWindows {
                continuation.yield(window)
                try? await processor.emitWindow(window)
            }
            
            continuation.finish()
        }
        
        return stream
    }
    
    /// Collect events into array
    func collect() async -> [Event<T>] {
        var results: [Event<T>] = []
        for await event in source {
            results.append(event)
            try? await processor.ingest(event)
        }
        return results
    }
    
    func getStatistics() async -> ProcessorStatistics {
        return await processor.getStatistics()
    }
}

// MARK: - Stream Builder

/// Builder for creating streams from various sources
struct StreamBuilder {
    
    /// Create stream from array
    static func from<T: Sendable>(_ values: [T]) -> Stream<T> {
        let (stream, continuation) = AsyncStream<Event<T>>.makeStream()
        let processor = StreamProcessor<T>()
        
        Task {
            for value in values {
                continuation.yield(Event(data: value))
            }
            continuation.finish()
        }
        
        return Stream(source: stream, processor: processor)
    }
    
    /// Create stream from async sequence
    static func from<S: AsyncSequence, T: Sendable>(_ sequence: S) -> Stream<T> where S.Element == T {
        let (stream, continuation) = AsyncStream<Event<T>>.makeStream()
        let processor = StreamProcessor<T>()
        
        Task {
            for try await value in sequence {
                continuation.yield(Event(data: value))
            }
            continuation.finish()
        }
        
        return Stream(source: stream, processor: processor)
    }
    
    /// Create stream that generates values at intervals
    static func interval<T: Sendable>(
        _ interval: Duration,
        generator: @escaping @Sendable (Int) -> T
    ) -> Stream<T> {
        let (stream, continuation) = AsyncStream<Event<T>>.makeStream()
        let processor = StreamProcessor<T>()
        
        Task {
            var index = 0
            while true {
                continuation.yield(Event(data: generator(index)))
                index += 1
                try? await Task.sleep(for: interval)
            }
        }
        
        return Stream(source: stream, processor: processor)
    }
}

// MARK: - Example Data Types

struct SensorReading: Sendable {
    let sensorId: String
    let temperature: Double
    let humidity: Double
}

struct Transaction: Sendable {
    let userId: String
    let amount: Double
    let category: String
}

// MARK: - Main Demo

@main
struct RealTimeSystem {
    static func main() async {
        print("=== Real-Time Stream Processing System ===\n")
        
        // Demo 1: Basic stream operations
        print("1. Basic Stream Operations\n")
        
        let numbers = StreamBuilder.from([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        
        let evenNumbers = numbers
            .filter { $0 % 2 == 0 }
            .map { $0 * 2 }
        
        let results = await evenNumbers.collect()
        print("Original: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]")
        print("After filter(even) and map(*2): \(results.map { $0.data })")
        
        // Demo 2: Tumbling window
        print("\n2. Tumbling Window (2-second windows)\n")
        
        let stream = StreamBuilder.from(Array(1...10))
        let windows = stream.window(type: .tumbling(duration: .seconds(2)))
        
        var windowCount = 0
        for await window in windows {
            windowCount += 1
            let sum = Aggregation.sum(window.map { $0 })
            let avg = Aggregation.average(window.map { Double($0) })
            print("Window \(windowCount): \(window.map { $0 })")
            print("  Sum: \(sum), Average: \(String(format: "%.2f", avg)), Count: \(window.count)")
        }
        
        // Demo 3: Count-based window
        print("\n3. Count-Based Window (size=3)\n")
        
        let countStream = StreamBuilder.from(Array(1...10))
        let countWindows = countStream.window(type: .count(size: 3))
        
        windowCount = 0
        for await window in countWindows {
            windowCount += 1
            let values = window.map { $0 }
            let sum = Aggregation.sum(values)
            print("Window \(windowCount): \(values) -> Sum: \(sum)")
        }
        
        // Demo 4: Real-time sensor data processing
        print("\n4. Sensor Data Stream Processing\n")
        
        let sensorData = [
            SensorReading(sensorId: "sensor1", temperature: 22.5, humidity: 45.0),
            SensorReading(sensorId: "sensor2", temperature: 23.1, humidity: 48.0),
            SensorReading(sensorId: "sensor1", temperature: 24.2, humidity: 46.0),
            SensorReading(sensorId: "sensor3", temperature: 21.8, humidity: 50.0),
            SensorReading(sensorId: "sensor2", temperature: 25.0, humidity: 47.0),
        ]
        
        let sensorStream = StreamBuilder.from(sensorData)
        
        let highTemp = sensorStream
            .filter { $0.temperature > 23.0 }
            .map { reading in
                "[\(reading.sensorId)] High temp: \(reading.temperature)°C"
            }
        
        let alerts = await highTemp.collect()
        print("High temperature alerts:")
        for alert in alerts {
            print("  \(alert.data)")
        }
        
        // Demo 5: Aggregations on windowed data
        print("\n5. Window Aggregations\n")
        
        let transactions = [
            Transaction(userId: "user1", amount: 100.0, category: "food"),
            Transaction(userId: "user2", amount: 50.0, category: "transport"),
            Transaction(userId: "user1", amount: 75.0, category: "food"),
            Transaction(userId: "user3", amount: 200.0, category: "shopping"),
            Transaction(userId: "user2", amount: 30.0, category: "transport"),
            Transaction(userId: "user1", amount: 150.0, category: "shopping"),
        ]
        
        let txStream = StreamBuilder.from(transactions)
        let txWindows = txStream.window(type: .count(size: 3))
        
        windowCount = 0
        for await window in txWindows {
            windowCount += 1
            let amounts = window.map { $0.amount }
            let total = Aggregation.sum(amounts)
            let average = Aggregation.average(amounts)
            let max = Aggregation.max(amounts)!
            let min = Aggregation.min(amounts)!
            
            print("Transaction Window \(windowCount):")
            print("  Total: $\(String(format: "%.2f", total))")
            print("  Average: $\(String(format: "%.2f", average))")
            print("  Max: $\(String(format: "%.2f", max))")
            print("  Min: $\(String(format: "%.2f", min))")
            print("  Count: \(window.count)")
        }
        
        // Demo 6: Backpressure
        print("\n6. Backpressure Demo\n")
        
        let smallBufferProcessor = StreamProcessor<Int>(maxBufferSize: 3)
        
        for i in 1...10 {
            let event = Event(data: i)
            try? await smallBufferProcessor.ingest(event)
        }
        
        let stats = await smallBufferProcessor.getStatistics()
        print("Processed with small buffer (size=3):")
        print("  Events processed: \(stats.eventsProcessed)")
        print("  Events dropped: \(stats.droppedEvents)")
        print("  Buffer size: \(stats.bufferSize)")
        
        print("\n=== Demo Completed ===")
        print("\nKey Features Demonstrated:")
        print("  ✓ AsyncSequence/AsyncStream for event streaming")
        print("  ✓ Fluent API with map, filter, window")
        print("  ✓ Tumbling windows (time-based)")
        print("  ✓ Count-based windows")
        print("  ✓ Window aggregations (sum, avg, min, max)")
        print("  ✓ Backpressure handling with buffer limits")
        print("  ✓ Actor-based concurrency for thread safety")
        print("  ✓ Type-safe generic stream processing")
        print("  ✓ Event timestamping and tracking")
    }
}
