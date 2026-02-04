#!/usr/bin/env swift

import Foundation

// MARK: - Job Protocol

/// Protocol defining a job that can be executed
protocol Job: Codable, Identifiable where ID == UUID {
    var id: UUID { get }
    var priority: Int { get }
    var maxRetries: Int { get }
    var createdAt: Date { get }
    
    func execute() async throws
}

// MARK: - Job Status

/// Represents the current status of a job
enum JobStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case deadLetter
}

// MARK: - Job Wrapper

/// Internal wrapper for jobs with metadata
struct JobWrapper: Codable, Identifiable {
    let id: UUID
    var status: JobStatus
    let priority: Int
    var retryCount: Int
    let maxRetries: Int
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var lastError: String?
    let jobType: String
    let jobData: Data
    
    init<T: Job>(job: T) throws {
        self.id = job.id
        self.status = .pending
        self.priority = job.priority
        self.retryCount = 0
        self.maxRetries = job.maxRetries
        self.createdAt = job.createdAt
        self.jobType = String(describing: T.self)
        self.jobData = try JSONEncoder().encode(job)
    }
    
    func decode<T: Job>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: jobData)
    }
}

// MARK: - Priority Queue

/// Thread-safe priority queue implementation
actor PriorityQueue<Element: Identifiable> where Element.ID: Hashable {
    private var heap: [Element] = []
    private var indexMap: [Element.ID: Int] = [:]
    private let comparator: (Element, Element) -> Bool
    
    init(comparator: @escaping (Element, Element) -> Bool) {
        self.comparator = comparator
    }
    
    var isEmpty: Bool {
        return heap.isEmpty
    }
    
    var count: Int {
        return heap.count
    }
    
    func enqueue(_ element: Element) {
        heap.append(element)
        let index = heap.count - 1
        indexMap[element.id] = index
        siftUp(index)
    }
    
    func dequeue() -> Element? {
        guard !heap.isEmpty else { return nil }
        
        if heap.count == 1 {
            let element = heap.removeLast()
            indexMap.removeValue(forKey: element.id)
            return element
        }
        
        let element = heap[0]
        indexMap.removeValue(forKey: element.id)
        
        heap[0] = heap.removeLast()
        indexMap[heap[0].id] = 0
        siftDown(0)
        
        return element
    }
    
    func peek() -> Element? {
        return heap.first
    }
    
    func remove(id: Element.ID) -> Element? {
        guard let index = indexMap[id] else { return nil }
        
        let element = heap[index]
        indexMap.removeValue(forKey: id)
        
        if index == heap.count - 1 {
            heap.removeLast()
            return element
        }
        
        heap[index] = heap.removeLast()
        indexMap[heap[index].id] = index
        
        siftDown(index)
        siftUp(index)
        
        return element
    }
    
    private func siftUp(_ index: Int) {
        var child = index
        var parent = (child - 1) / 2
        
        while child > 0 && comparator(heap[child], heap[parent]) {
            heap.swapAt(child, parent)
            indexMap[heap[child].id] = child
            indexMap[heap[parent].id] = parent
            
            child = parent
            parent = (child - 1) / 2
        }
    }
    
    private func siftDown(_ index: Int) {
        var parent = index
        
        while true {
            let leftChild = 2 * parent + 1
            let rightChild = 2 * parent + 2
            var candidate = parent
            
            if leftChild < heap.count && comparator(heap[leftChild], heap[candidate]) {
                candidate = leftChild
            }
            
            if rightChild < heap.count && comparator(heap[rightChild], heap[candidate]) {
                candidate = rightChild
            }
            
            if candidate == parent { break }
            
            heap.swapAt(parent, candidate)
            indexMap[heap[parent].id] = parent
            indexMap[heap[candidate].id] = candidate
            
            parent = candidate
        }
    }
    
    func toArray() -> [Element] {
        return heap
    }
}

// MARK: - Job Storage

/// Persistent storage for jobs using Codable
actor JobStorage {
    private let fileURL: URL
    private var jobs: [UUID: JobWrapper] = [:]
    
    init(storageURL: URL) {
        self.fileURL = storageURL
        loadJobs()
    }
    
    func save(job: JobWrapper) async {
        jobs[job.id] = job
        persistJobs()
    }
    
    func get(id: UUID) -> JobWrapper? {
        return jobs[id]
    }
    
    func getAll() -> [JobWrapper] {
        return Array(jobs.values)
    }
    
    func update(id: UUID, transform: (inout JobWrapper) -> Void) async {
        guard var job = jobs[id] else { return }
        transform(&job)
        jobs[id] = job
        persistJobs()
    }
    
    func delete(id: UUID) async {
        jobs.removeValue(forKey: id)
        persistJobs()
    }
    
    private func loadJobs() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            jobs = try decoder.decode([UUID: JobWrapper].self, from: data)
        } catch {
            print("Failed to load jobs: \(error)")
        }
    }
    
    private func persistJobs() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(jobs)
            try data.write(to: fileURL)
        } catch {
            print("Failed to persist jobs: \(error)")
        }
    }
}

// MARK: - Worker

/// Worker that processes jobs from the queue
actor Worker {
    let id: Int
    private(set) var isProcessing = false
    private(set) var currentJobId: UUID?
    private(set) var jobsProcessed = 0
    private(set) var jobsFailed = 0
    
    func process<T: Job>(job: T, wrapper: JobWrapper, storage: JobStorage) async -> Result<Void, Error> {
        isProcessing = true
        currentJobId = wrapper.id
        defer {
            isProcessing = false
            currentJobId = nil
        }
        
        await storage.update(id: wrapper.id) { job in
            job.status = .running
            job.startedAt = Date()
        }
        
        do {
            try await job.execute()
            
            await storage.update(id: wrapper.id) { job in
                job.status = .completed
                job.completedAt = Date()
            }
            
            jobsProcessed += 1
            return .success(())
        } catch {
            jobsFailed += 1
            
            await storage.update(id: wrapper.id) { job in
                job.lastError = error.localizedDescription
                job.retryCount += 1
            }
            
            return .failure(error)
        }
    }
}

// MARK: - Task Queue

/// Production-grade async task queue with priority, retry logic, and persistence
actor TaskQueue {
    private let queue: PriorityQueue<JobWrapper>
    private let deadLetterQueue: PriorityQueue<JobWrapper>
    private let storage: JobStorage
    private var workers: [Worker] = []
    private let workerCount: Int
    
    private(set) var isRunning = false
    private var processingTasks: [Task<Void, Never>] = []
    
    init(workerCount: Int = 4, storageURL: URL) {
        self.workerCount = workerCount
        self.storage = JobStorage(storageURL: storageURL)
        
        // Priority queue: higher priority first, then older jobs
        self.queue = PriorityQueue { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.createdAt < rhs.createdAt
        }
        
        self.deadLetterQueue = PriorityQueue { lhs, rhs in
            return lhs.createdAt < rhs.createdAt
        }
        
        // Initialize workers
        for i in 0..<workerCount {
            workers.append(Worker(id: i))
        }
    }
    
    /// Enqueue a new job
    func enqueue<T: Job>(_ job: T) async throws {
        let wrapper = try JobWrapper(job: job)
        await storage.save(job: wrapper)
        await queue.enqueue(wrapper)
        
        print("[Queue] Enqueued job \(job.id) with priority \(job.priority)")
    }
    
    /// Start processing jobs
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        
        print("[Queue] Starting with \(workerCount) workers")
        
        // Restore pending jobs from storage
        await restorePendingJobs()
        
        // Start worker tasks
        for worker in workers {
            let task = Task {
                await processJobs(worker: worker)
            }
            processingTasks.append(task)
        }
    }
    
    /// Stop processing jobs
    func stop() async {
        isRunning = false
        
        for task in processingTasks {
            task.cancel()
        }
        processingTasks.removeAll()
        
        print("[Queue] Stopped")
    }
    
    /// Get queue statistics
    func getStatistics() async -> QueueStatistics {
        let queueSize = await queue.count
        let deadLetterSize = await deadLetterQueue.count
        
        var totalProcessed = 0
        var totalFailed = 0
        var activeWorkers = 0
        
        for worker in workers {
            totalProcessed += await worker.jobsProcessed
            totalFailed += await worker.jobsFailed
            if await worker.isProcessing {
                activeWorkers += 1
            }
        }
        
        return QueueStatistics(
            queueSize: queueSize,
            deadLetterQueueSize: deadLetterSize,
            totalProcessed: totalProcessed,
            totalFailed: totalFailed,
            activeWorkers: activeWorkers,
            totalWorkers: workerCount
        )
    }
    
    /// Get all jobs in dead letter queue
    func getDeadLetterJobs() async -> [JobWrapper] {
        return await deadLetterQueue.toArray()
    }
    
    private func restorePendingJobs() async {
        let allJobs = await storage.getAll()
        
        for job in allJobs {
            if job.status == .pending || job.status == .running {
                await queue.enqueue(job)
            } else if job.status == .deadLetter {
                await deadLetterQueue.enqueue(job)
            }
        }
        
        let restored = allJobs.filter { $0.status == .pending || $0.status == .running }.count
        if restored > 0 {
            print("[Queue] Restored \(restored) pending jobs from storage")
        }
    }
    
    private func processJobs(worker: Worker) async {
        while isRunning {
            guard let wrapper = await queue.dequeue() else {
                // Queue is empty, wait a bit
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            
            print("[Worker \(worker.id)] Processing job \(wrapper.id)")
            
            // Decode and execute the job based on its type
            let result: Result<Void, Error>
            
            // In a real implementation, you'd have a registry of job types
            // For this demo, we'll use a simple example job
            if wrapper.jobType.contains("ExampleJob") {
                do {
                    let job = try wrapper.decode(as: ExampleJob.self)
                    result = await worker.process(job: job, wrapper: wrapper, storage: storage)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(TaskQueueError.unknownJobType(wrapper.jobType))
            }
            
            switch result {
            case .success:
                print("[Worker \(worker.id)] Job \(wrapper.id) completed successfully")
                
            case .failure(let error):
                print("[Worker \(worker.id)] Job \(wrapper.id) failed: \(error)")
                
                // Check if we should retry
                let updatedWrapper = await storage.get(id: wrapper.id)!
                
                if updatedWrapper.retryCount < updatedWrapper.maxRetries {
                    print("[Worker \(worker.id)] Retrying job \(wrapper.id) (attempt \(updatedWrapper.retryCount + 1)/\(updatedWrapper.maxRetries))")
                    
                    // Re-enqueue with exponential backoff
                    let delay = min(pow(2.0, Double(updatedWrapper.retryCount)), 60.0)
                    try? await Task.sleep(for: .seconds(Int(delay)))
                    
                    await storage.update(id: wrapper.id) { job in
                        job.status = .pending
                    }
                    await queue.enqueue(updatedWrapper)
                } else {
                    // Move to dead letter queue
                    print("[Worker \(worker.id)] Job \(wrapper.id) exceeded max retries, moving to dead letter queue")
                    
                    await storage.update(id: wrapper.id) { job in
                        job.status = .deadLetter
                    }
                    
                    let deadJob = await storage.get(id: wrapper.id)!
                    await deadLetterQueue.enqueue(deadJob)
                }
            }
        }
    }
}

// MARK: - Statistics

struct QueueStatistics {
    let queueSize: Int
    let deadLetterQueueSize: Int
    let totalProcessed: Int
    let totalFailed: Int
    let activeWorkers: Int
    let totalWorkers: Int
}

// MARK: - Errors

enum TaskQueueError: Error {
    case unknownJobType(String)
    case jobExecutionFailed(String)
}

// MARK: - Example Job Implementation

struct ExampleJob: Job, Codable {
    let id: UUID
    let priority: Int
    let maxRetries: Int
    let createdAt: Date
    let taskName: String
    let duration: TimeInterval
    let shouldFail: Bool
    
    init(taskName: String, priority: Int = 0, duration: TimeInterval = 1.0, shouldFail: Bool = false, maxRetries: Int = 3) {
        self.id = UUID()
        self.priority = priority
        self.maxRetries = maxRetries
        self.createdAt = Date()
        self.taskName = taskName
        self.duration = duration
        self.shouldFail = shouldFail
    }
    
    func execute() async throws {
        print("  → Executing task: \(taskName)")
        
        // Simulate work
        try await Task.sleep(for: .seconds(duration))
        
        if shouldFail {
            throw TaskQueueError.jobExecutionFailed("Simulated failure for \(taskName)")
        }
        
        print("  ✓ Completed task: \(taskName)")
    }
}

// MARK: - Main Demo

@main
struct AsyncTaskQueue {
    static func main() async {
        print("=== Async Task Queue with Priority & Retry ===\n")
        
        // Create storage directory
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-queue-storage.json")
        
        print("Storage location: \(storageURL.path)\n")
        
        // Create task queue
        let queue = TaskQueue(workerCount: 3, storageURL: storageURL)
        
        // Start the queue
        await queue.start()
        
        // Enqueue various jobs with different priorities
        print("=== Enqueueing Jobs ===\n")
        
        do {
            // High priority jobs
            try await queue.enqueue(ExampleJob(taskName: "Critical Task 1", priority: 10, duration: 0.5))
            try await queue.enqueue(ExampleJob(taskName: "Critical Task 2", priority: 10, duration: 0.5))
            
            // Medium priority jobs
            try await queue.enqueue(ExampleJob(taskName: "Important Task 1", priority: 5, duration: 1.0))
            try await queue.enqueue(ExampleJob(taskName: "Important Task 2", priority: 5, duration: 1.0))
            
            // Low priority jobs
            try await queue.enqueue(ExampleJob(taskName: "Normal Task 1", priority: 1, duration: 0.8))
            try await queue.enqueue(ExampleJob(taskName: "Normal Task 2", priority: 1, duration: 0.8))
            
            // Jobs that will fail and retry
            try await queue.enqueue(ExampleJob(taskName: "Flaky Task", priority: 3, duration: 0.5, shouldFail: true, maxRetries: 2))
            
        } catch {
            print("Error enqueueing jobs: \(error)")
        }
        
        print("\n=== Processing Jobs ===\n")
        
        // Let the queue process for a while
        try? await Task.sleep(for: .seconds(8))
        
        // Print statistics
        print("\n=== Queue Statistics ===\n")
        let stats = await queue.getStatistics()
        print("Queue Size: \(stats.queueSize)")
        print("Dead Letter Queue Size: \(stats.deadLetterQueueSize)")
        print("Total Processed: \(stats.totalProcessed)")
        print("Total Failed: \(stats.totalFailed)")
        print("Active Workers: \(stats.activeWorkers)/\(stats.totalWorkers)")
        
        // Show dead letter queue
        let deadLetterJobs = await queue.getDeadLetterJobs()
        if !deadLetterJobs.isEmpty {
            print("\n=== Dead Letter Queue ===\n")
            for job in deadLetterJobs {
                print("Job ID: \(job.id)")
                print("  Type: \(job.jobType)")
                print("  Retry Count: \(job.retryCount)")
                print("  Last Error: \(job.lastError ?? "None")")
            }
        }
        
        // Stop the queue
        await queue.stop()
        
        print("\n=== Demo Completed ===")
        print("\nKey Features Demonstrated:")
        print("  ✓ Priority-based job queue using heap data structure")
        print("  ✓ Async/await based worker pool")
        print("  ✓ Automatic retry with exponential backoff")
        print("  ✓ Dead letter queue for failed jobs")
        print("  ✓ Persistent storage using Codable")
        print("  ✓ Actor-based concurrency for thread safety")
        print("  ✓ Job status tracking and statistics")
        print("  ✓ Graceful shutdown and job restoration")
    }
}
