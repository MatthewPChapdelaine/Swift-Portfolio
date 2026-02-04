#!/usr/bin/env swift

/// Graph Algorithms Implementation in Swift
/// Features: BFS, DFS, Dijkstra, Topological Sort, Cycle Detection
///
/// All algorithms implemented with:
/// - Generic types
/// - Protocol-oriented design
/// - Value semantics
/// - Comprehensive documentation
///
/// Compile: swiftc -o graphs GraphAlgorithms.swift
/// Run: ./graphs
/// Or: swift GraphAlgorithms.swift

import Foundation

// MARK: - Graph Protocol

/// Generic graph protocol
protocol Graph {
    associatedtype Vertex: Hashable
    
    var vertices: Set<Vertex> { get }
    
    func neighbors(of vertex: Vertex) -> [Vertex]
    func addVertex(_ vertex: Vertex)
    func addEdge(from source: Vertex, to destination: Vertex, weight: Double)
}

// MARK: - Directed Graph

/// Directed graph with weighted edges
struct DirectedGraph<T: Hashable>: Graph {
    typealias Vertex = T
    
    private(set) var vertices: Set<T> = []
    private var adjacencyList: [T: [(vertex: T, weight: Double)]] = [:]
    
    func neighbors(of vertex: T) -> [T] {
        return adjacencyList[vertex]?.map { $0.vertex } ?? []
    }
    
    func neighborsWithWeights(of vertex: T) -> [(vertex: T, weight: Double)] {
        return adjacencyList[vertex] ?? []
    }
    
    mutating func addVertex(_ vertex: T) {
        vertices.insert(vertex)
        if adjacencyList[vertex] == nil {
            adjacencyList[vertex] = []
        }
    }
    
    mutating func addEdge(from source: T, to destination: T, weight: Double = 1.0) {
        addVertex(source)
        addVertex(destination)
        adjacencyList[source]?.append((vertex: destination, weight: weight))
    }
}

// MARK: - Undirected Graph

/// Undirected graph with weighted edges
struct UndirectedGraph<T: Hashable>: Graph {
    typealias Vertex = T
    
    private(set) var vertices: Set<T> = []
    private var adjacencyList: [T: [(vertex: T, weight: Double)]] = [:]
    
    func neighbors(of vertex: T) -> [T] {
        return adjacencyList[vertex]?.map { $0.vertex } ?? []
    }
    
    func neighborsWithWeights(of vertex: T) -> [(vertex: T, weight: Double)] {
        return adjacencyList[vertex] ?? []
    }
    
    mutating func addVertex(_ vertex: T) {
        vertices.insert(vertex)
        if adjacencyList[vertex] == nil {
            adjacencyList[vertex] = []
        }
    }
    
    mutating func addEdge(from source: T, to destination: T, weight: Double = 1.0) {
        addVertex(source)
        addVertex(destination)
        adjacencyList[source]?.append((vertex: destination, weight: weight))
        adjacencyList[destination]?.append((vertex: source, weight: weight))
    }
}

// MARK: - BFS (Breadth-First Search)

extension Graph {
    /// Performs breadth-first search from a starting vertex
    /// - Returns: Array of vertices in BFS order
    func bfs(from start: Vertex) -> [Vertex] {
        var visited: Set<Vertex> = []
        var queue: [Vertex] = [start]
        var result: [Vertex] = []
        
        visited.insert(start)
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            
            for neighbor in neighbors(of: current) {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
        
        return result
    }
    
    /// Finds shortest path using BFS (unweighted)
    func shortestPath(from start: Vertex, to end: Vertex) -> [Vertex]? {
        var visited: Set<Vertex> = []
        var queue: [(vertex: Vertex, path: [Vertex])] = [(start, [start])]
        
        visited.insert(start)
        
        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            
            if current == end {
                return path
            }
            
            for neighbor in neighbors(of: current) {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, path + [neighbor]))
                }
            }
        }
        
        return nil
    }
}

// MARK: - DFS (Depth-First Search)

extension Graph {
    /// Performs depth-first search from a starting vertex
    /// - Returns: Array of vertices in DFS order
    func dfs(from start: Vertex) -> [Vertex] {
        var visited: Set<Vertex> = []
        var result: [Vertex] = []
        
        func dfsRecursive(_ vertex: Vertex) {
            visited.insert(vertex)
            result.append(vertex)
            
            for neighbor in neighbors(of: vertex) {
                if !visited.contains(neighbor) {
                    dfsRecursive(neighbor)
                }
            }
        }
        
        dfsRecursive(start)
        return result
    }
    
    /// DFS iterative implementation
    func dfsIterative(from start: Vertex) -> [Vertex] {
        var visited: Set<Vertex> = []
        var stack: [Vertex] = [start]
        var result: [Vertex] = []
        
        while !stack.isEmpty {
            let current = stack.removeLast()
            
            if !visited.contains(current) {
                visited.insert(current)
                result.append(current)
                
                // Add neighbors in reverse order to maintain left-to-right traversal
                for neighbor in neighbors(of: current).reversed() {
                    if !visited.contains(neighbor) {
                        stack.append(neighbor)
                    }
                }
            }
        }
        
        return result
    }
}

// MARK: - Dijkstra's Algorithm

extension DirectedGraph {
    /// Finds shortest paths from source to all vertices using Dijkstra's algorithm
    /// - Returns: Dictionary of vertex to (distance, previous vertex)
    func dijkstra(from source: Vertex) -> [Vertex: (distance: Double, previous: Vertex?)] {
        var distances: [Vertex: Double] = [:]
        var previous: [Vertex: Vertex?] = [:]
        var unvisited = Set(vertices)
        
        // Initialize distances
        for vertex in vertices {
            distances[vertex] = .infinity
            previous[vertex] = nil
        }
        distances[source] = 0
        
        while !unvisited.isEmpty {
            // Find vertex with minimum distance
            guard let current = unvisited.min(by: { distances[$0]! < distances[$1]! }),
                  let currentDistance = distances[current],
                  currentDistance != .infinity else {
                break
            }
            
            unvisited.remove(current)
            
            // Update distances to neighbors
            for (neighbor, weight) in neighborsWithWeights(of: current) {
                let alternativeDistance = currentDistance + weight
                
                if alternativeDistance < distances[neighbor]! {
                    distances[neighbor] = alternativeDistance
                    previous[neighbor] = current
                }
            }
        }
        
        // Combine results
        var result: [Vertex: (distance: Double, previous: Vertex?)] = [:]
        for vertex in vertices {
            result[vertex] = (distances[vertex]!, previous[vertex]!)
        }
        
        return result
    }
    
    /// Reconstructs shortest path from Dijkstra results
    func path(to destination: Vertex, from dijkstraResult: [Vertex: (distance: Double, previous: Vertex?)]) -> [Vertex]? {
        guard dijkstraResult[destination]?.distance != .infinity else {
            return nil
        }
        
        var path: [Vertex] = []
        var current: Vertex? = destination
        
        while let vertex = current {
            path.insert(vertex, at: 0)
            current = dijkstraResult[vertex]?.previous
        }
        
        return path
    }
}

// MARK: - Topological Sort

extension DirectedGraph {
    /// Performs topological sort using DFS
    /// - Returns: Topologically sorted array of vertices, or nil if cycle exists
    func topologicalSort() -> [Vertex]? {
        var visited: Set<Vertex> = []
        var tempMark: Set<Vertex> = []
        var result: [Vertex] = []
        
        func visit(_ vertex: Vertex) -> Bool {
            if tempMark.contains(vertex) {
                return false // Cycle detected
            }
            
            if visited.contains(vertex) {
                return true
            }
            
            tempMark.insert(vertex)
            
            for neighbor in neighbors(of: vertex) {
                if !visit(neighbor) {
                    return false
                }
            }
            
            tempMark.remove(vertex)
            visited.insert(vertex)
            result.insert(vertex, at: 0)
            
            return true
        }
        
        for vertex in vertices {
            if !visited.contains(vertex) {
                if !visit(vertex) {
                    return nil // Cycle detected
                }
            }
        }
        
        return result
    }
}

// MARK: - Cycle Detection

extension DirectedGraph {
    /// Detects if graph contains a cycle
    func hasCycle() -> Bool {
        var visited: Set<Vertex> = []
        var recursionStack: Set<Vertex> = []
        
        func hasCycleUtil(_ vertex: Vertex) -> Bool {
            visited.insert(vertex)
            recursionStack.insert(vertex)
            
            for neighbor in neighbors(of: vertex) {
                if !visited.contains(neighbor) {
                    if hasCycleUtil(neighbor) {
                        return true
                    }
                } else if recursionStack.contains(neighbor) {
                    return true
                }
            }
            
            recursionStack.remove(vertex)
            return false
        }
        
        for vertex in vertices {
            if !visited.contains(vertex) {
                if hasCycleUtil(vertex) {
                    return true
                }
            }
        }
        
        return false
    }
}

extension UndirectedGraph {
    /// Detects if undirected graph contains a cycle
    func hasCycle() -> Bool {
        var visited: Set<Vertex> = []
        
        func hasCycleUtil(_ vertex: Vertex, parent: Vertex?) -> Bool {
            visited.insert(vertex)
            
            for neighbor in neighbors(of: vertex) {
                if !visited.contains(neighbor) {
                    if hasCycleUtil(neighbor, parent: vertex) {
                        return true
                    }
                } else if neighbor != parent {
                    return true
                }
            }
            
            return false
        }
        
        for vertex in vertices where !visited.contains(vertex) {
            if hasCycleUtil(vertex, parent: nil) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Connected Components

extension UndirectedGraph {
    /// Finds all connected components
    func connectedComponents() -> [[Vertex]] {
        var visited: Set<Vertex> = []
        var components: [[Vertex]] = []
        
        for vertex in vertices {
            if !visited.contains(vertex) {
                let component = bfs(from: vertex)
                visited.formUnion(component)
                components.append(component)
            }
        }
        
        return components
    }
}

// MARK: - Main Entry Point

@main
struct GraphAlgorithmsDemo {
    static func main() {
        print("╔════════════════════════════════════════╗")
        print("║      Graph Algorithms Demo             ║")
        print("║      Advanced Swift Implementation     ║")
        print("╚════════════════════════════════════════╝\n")
        
        demonstrateBFS()
        demonstrateDFS()
        demonstrateDijkstra()
        demonstrateTopologicalSort()
        demonstrateCycleDetection()
        demonstrateConnectedComponents()
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ All graph algorithms demonstrated!")
        print(String(repeating: "=", count: 50))
    }
    
    static func demonstrateBFS() {
        print("\n1️⃣  BREADTH-FIRST SEARCH (BFS)")
        print(String(repeating: "=", count: 50))
        
        var graph = UndirectedGraph<String>()
        
        // Create a sample graph
        //     A --- B
        //     |     |
        //     C --- D --- E
        //           |
        //           F
        
        graph.addEdge(from: "A", to: "B")
        graph.addEdge(from: "A", to: "C")
        graph.addEdge(from: "B", to: "D")
        graph.addEdge(from: "C", to: "D")
        graph.addEdge(from: "D", to: "E")
        graph.addEdge(from: "D", to: "F")
        
        let bfsResult = graph.bfs(from: "A")
        print("🔍 BFS traversal from A: \(bfsResult.joined(separator: " → "))")
        
        if let path = graph.shortestPath(from: "A", to: "F") {
            print("🎯 Shortest path from A to F: \(path.joined(separator: " → "))")
        }
    }
    
    static func demonstrateDFS() {
        print("\n2️⃣  DEPTH-FIRST SEARCH (DFS)")
        print(String(repeating: "=", count: 50))
        
        var graph = DirectedGraph<Int>()
        
        // Create a directed graph
        //     1 → 2 → 4
        //     ↓   ↓
        //     3 → 5
        
        graph.addEdge(from: 1, to: 2)
        graph.addEdge(from: 1, to: 3)
        graph.addEdge(from: 2, to: 4)
        graph.addEdge(from: 2, to: 5)
        graph.addEdge(from: 3, to: 5)
        
        let dfsRecursive = graph.dfs(from: 1)
        print("🔍 DFS (recursive) from 1: \(dfsRecursive.map(String.init).joined(separator: " → "))")
        
        let dfsIterative = graph.dfsIterative(from: 1)
        print("🔍 DFS (iterative) from 1: \(dfsIterative.map(String.init).joined(separator: " → "))")
    }
    
    static func demonstrateDijkstra() {
        print("\n3️⃣  DIJKSTRA'S SHORTEST PATH")
        print(String(repeating: "=", count: 50))
        
        var graph = DirectedGraph<String>()
        
        // Create weighted graph
        //     A -7→ B -10→ E
        //     |     |      ↑
        //     5     2      6
        //     ↓     ↓      |
        //     C -3→ D -----+
        
        graph.addEdge(from: "A", to: "B", weight: 7)
        graph.addEdge(from: "A", to: "C", weight: 5)
        graph.addEdge(from: "B", to: "D", weight: 2)
        graph.addEdge(from: "B", to: "E", weight: 10)
        graph.addEdge(from: "C", to: "D", weight: 3)
        graph.addEdge(from: "D", to: "E", weight: 6)
        
        let results = graph.dijkstra(from: "A")
        
        print("\n📊 Shortest distances from A:")
        for (vertex, (distance, _)) in results.sorted(by: { $0.key < $1.key }) {
            if distance == .infinity {
                print("   \(vertex): ∞")
            } else {
                print("   \(vertex): \(Int(distance))")
            }
        }
        
        if let path = graph.path(to: "E", from: results) {
            let distance = results["E"]!.distance
            print("\n🎯 Shortest path to E: \(path.joined(separator: " → ")) (distance: \(Int(distance)))")
        }
    }
    
    static func demonstrateTopologicalSort() {
        print("\n4️⃣  TOPOLOGICAL SORT")
        print(String(repeating: "=", count: 50))
        
        var graph = DirectedGraph<String>()
        
        // DAG representing course dependencies
        // Algorithms → AI
        // DataStructures → Algorithms
        // Math → Algorithms
        // Intro → DataStructures
        // Intro → Math
        
        graph.addEdge(from: "Intro", to: "DataStructures")
        graph.addEdge(from: "Intro", to: "Math")
        graph.addEdge(from: "DataStructures", to: "Algorithms")
        graph.addEdge(from: "Math", to: "Algorithms")
        graph.addEdge(from: "Algorithms", to: "AI")
        
        if let sorted = graph.topologicalSort() {
            print("📚 Course order (topological sort):")
            for (index, course) in sorted.enumerated() {
                print("   \(index + 1). \(course)")
            }
        } else {
            print("❌ Cannot perform topological sort (cycle detected)")
        }
    }
    
    static func demonstrateCycleDetection() {
        print("\n5️⃣  CYCLE DETECTION")
        print(String(repeating: "=", count: 50))
        
        // Directed graph without cycle
        var dag = DirectedGraph<Int>()
        dag.addEdge(from: 1, to: 2)
        dag.addEdge(from: 2, to: 3)
        dag.addEdge(from: 1, to: 3)
        
        print("\n🔍 Directed graph (1→2→3, 1→3):")
        print("   Has cycle: \(dag.hasCycle() ? "YES ⚠️" : "NO ✅")")
        
        // Directed graph with cycle
        var cyclicDag = DirectedGraph<Int>()
        cyclicDag.addEdge(from: 1, to: 2)
        cyclicDag.addEdge(from: 2, to: 3)
        cyclicDag.addEdge(from: 3, to: 1)
        
        print("\n🔍 Directed graph (1→2→3→1):")
        print("   Has cycle: \(cyclicDag.hasCycle() ? "YES ⚠️" : "NO ✅")")
        
        // Undirected graph without cycle (tree)
        var tree = UndirectedGraph<String>()
        tree.addEdge(from: "A", to: "B")
        tree.addEdge(from: "A", to: "C")
        tree.addEdge(from: "B", to: "D")
        
        print("\n🔍 Undirected tree (A-B-D, A-C):")
        print("   Has cycle: \(tree.hasCycle() ? "YES ⚠️" : "NO ✅")")
        
        // Undirected graph with cycle
        var cyclicGraph = UndirectedGraph<String>()
        cyclicGraph.addEdge(from: "A", to: "B")
        cyclicGraph.addEdge(from: "B", to: "C")
        cyclicGraph.addEdge(from: "C", to: "A")
        
        print("\n🔍 Undirected graph (A-B-C-A):")
        print("   Has cycle: \(cyclicGraph.hasCycle() ? "YES ⚠️" : "NO ✅")")
    }
    
    static func demonstrateConnectedComponents() {
        print("\n6️⃣  CONNECTED COMPONENTS")
        print(String(repeating: "=", count: 50))
        
        var graph = UndirectedGraph<Int>()
        
        // Create graph with multiple components
        // Component 1: 1-2-3
        graph.addEdge(from: 1, to: 2)
        graph.addEdge(from: 2, to: 3)
        
        // Component 2: 4-5
        graph.addEdge(from: 4, to: 5)
        
        // Component 3: 6-7-8
        graph.addEdge(from: 6, to: 7)
        graph.addEdge(from: 7, to: 8)
        
        // Component 4: 9 (isolated)
        graph.addVertex(9)
        
        let components = graph.connectedComponents()
        
        print("\n🔗 Found \(components.count) connected components:")
        for (index, component) in components.enumerated() {
            let vertices = component.map(String.init).sorted().joined(separator: ", ")
            print("   Component \(index + 1): [\(vertices)]")
        }
    }
}

/*
 USAGE INSTRUCTIONS:
 ═══════════════════
 
 1. Run directly:
    swift GraphAlgorithms.swift
    
 2. Compile and run:
    swiftc -o graphs GraphAlgorithms.swift
    ./graphs
 
 ALGORITHMS IMPLEMENTED:
 ══════════════════════
 
 1. BFS (Breadth-First Search)
    - Level-order traversal
    - Shortest path in unweighted graphs
    - Time: O(V + E)
 
 2. DFS (Depth-First Search)
    - Recursive and iterative
    - Path finding
    - Time: O(V + E)
 
 3. Dijkstra's Algorithm
    - Shortest path in weighted graphs
    - Works with non-negative weights
    - Time: O(V²) or O((V + E) log V) with heap
 
 4. Topological Sort
    - Linear ordering of DAG vertices
    - Detects cycles
    - Time: O(V + E)
 
 5. Cycle Detection
    - Directed and undirected graphs
    - Uses DFS
    - Time: O(V + E)
 
 6. Connected Components
    - Finds all disconnected subgraphs
    - Uses BFS
    - Time: O(V + E)
 
 SWIFT FEATURES USED:
 ═══════════════════
 
 ✓ Generic types with constraints (Hashable)
 ✓ Protocol-oriented programming
 ✓ Value types (struct)
 ✓ Protocol extensions
 ✓ Associated types
 ✓ Sets for O(1) lookups
 ✓ Tuples for return values
 ✓ Optionals for missing values
 ✓ Higher-order functions (map, sorted)
 
 EXTENDING:
 ═════════
 
 To add algorithms:
 
   extension DirectedGraph {
       func myAlgorithm() -> Result {
           // Implementation
       }
   }
 
 To use different vertex types:
 
   let stringGraph = DirectedGraph<String>()
   let intGraph = DirectedGraph<Int>()
   struct Node: Hashable { ... }
   let nodeGraph = DirectedGraph<Node>()
*/
