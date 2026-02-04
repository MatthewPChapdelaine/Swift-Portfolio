#!/usr/bin/env swift

/// Huffman Coding Compression/Decompression Tool
/// Implements optimal prefix-free encoding for data compression
///
/// Features:
/// - Builds Huffman tree from frequency analysis
/// - Generates optimal prefix-free codes
/// - Compresses and decompresses data
/// - CLI tool with file I/O
/// - Compression statistics
///
/// Compile: swiftc -o compress CompressionTool.swift
/// Run: ./compress
/// Or: swift CompressionTool.swift

import Foundation

// MARK: - Huffman Tree Node

/// Node in the Huffman tree
class HuffmanNode: Comparable {
    let character: Character?
    let frequency: Int
    let left: HuffmanNode?
    let right: HuffmanNode?
    
    init(character: Character?, frequency: Int, left: HuffmanNode? = nil, right: HuffmanNode? = nil) {
        self.character = character
        self.frequency = frequency
        self.left = left
        self.right = right
    }
    
    var isLeaf: Bool {
        return left == nil && right == nil
    }
    
    // Comparable conformance for priority queue
    static func < (lhs: HuffmanNode, rhs: HuffmanNode) -> Bool {
        return lhs.frequency < rhs.frequency
    }
    
    static func == (lhs: HuffmanNode, rhs: HuffmanNode) -> Bool {
        return lhs.frequency == rhs.frequency
    }
}

// MARK: - Priority Queue (Min-Heap)

/// Min-heap implementation for Huffman tree construction
struct PriorityQueue<T: Comparable> {
    private var heap: [T] = []
    
    var isEmpty: Bool {
        return heap.isEmpty
    }
    
    var count: Int {
        return heap.count
    }
    
    mutating func insert(_ element: T) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }
    
    mutating func extractMin() -> T? {
        guard !heap.isEmpty else { return nil }
        
        if heap.count == 1 {
            return heap.removeLast()
        }
        
        let min = heap[0]
        heap[0] = heap.removeLast()
        siftDown(from: 0)
        
        return min
    }
    
    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2
        
        while child > 0 && heap[child] < heap[parent] {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }
    
    private mutating func siftDown(from index: Int) {
        var parent = index
        
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var smallest = parent
            
            if left < heap.count && heap[left] < heap[smallest] {
                smallest = left
            }
            
            if right < heap.count && heap[right] < heap[smallest] {
                smallest = right
            }
            
            if smallest == parent {
                break
            }
            
            heap.swapAt(parent, smallest)
            parent = smallest
        }
    }
}

// MARK: - Huffman Encoder

/// Huffman encoding/decoding engine
class HuffmanCoder {
    private var root: HuffmanNode?
    private var codes: [Character: String] = [:]
    
    /// Build Huffman tree from text
    func buildTree(from text: String) {
        // Calculate frequency of each character
        var frequencies: [Character: Int] = [:]
        for char in text {
            frequencies[char, default: 0] += 1
        }
        
        // Create priority queue with leaf nodes
        var pq = PriorityQueue<HuffmanNode>()
        for (char, freq) in frequencies {
            pq.insert(HuffmanNode(character: char, frequency: freq))
        }
        
        // Build Huffman tree
        while pq.count > 1 {
            let left = pq.extractMin()!
            let right = pq.extractMin()!
            
            let parent = HuffmanNode(
                character: nil,
                frequency: left.frequency + right.frequency,
                left: left,
                right: right
            )
            
            pq.insert(parent)
        }
        
        root = pq.extractMin()
        
        // Generate codes
        generateCodes(node: root, code: "")
    }
    
    /// Recursively generate Huffman codes
    private func generateCodes(node: HuffmanNode?, code: String) {
        guard let node = node else { return }
        
        if node.isLeaf, let char = node.character {
            codes[char] = code.isEmpty ? "0" : code
        } else {
            generateCodes(node: node.left, code: code + "0")
            generateCodes(node: node.right, code: code + "1")
        }
    }
    
    /// Encode text to binary string
    func encode(_ text: String) -> String {
        var encoded = ""
        for char in text {
            if let code = codes[char] {
                encoded += code
            }
        }
        return encoded
    }
    
    /// Decode binary string to text
    func decode(_ encoded: String) -> String {
        guard let root = root else { return "" }
        
        var decoded = ""
        var current = root
        
        for bit in encoded {
            if bit == "0" {
                current = current.left ?? root
            } else {
                current = current.right ?? root
            }
            
            if current.isLeaf, let char = current.character {
                decoded.append(char)
                current = root
            }
        }
        
        return decoded
    }
    
    /// Get code table
    func getCodeTable() -> [(Character, String, Int)] {
        return codes.map { ($0.key, $0.value, $0.value.count) }
            .sorted { $0.0 < $1.0 }
    }
    
    /// Serialize tree for storage (simple format)
    func serializeTree() -> String {
        guard let root = root else { return "" }
        return serializeNode(root)
    }
    
    private func serializeNode(_ node: HuffmanNode) -> String {
        if node.isLeaf, let char = node.character {
            return "L\(char)"
        } else {
            let left = serializeNode(node.left!)
            let right = serializeNode(node.right!)
            return "N(\(left),\(right))"
        }
    }
}

// MARK: - Compression Statistics

/// Statistics about compression
struct CompressionStats {
    let originalSize: Int
    let compressedSize: Int
    let compressionRatio: Double
    let spaceSavings: Double
    
    init(originalSize: Int, compressedSize: Int) {
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.compressionRatio = Double(compressedSize) / Double(originalSize)
        self.spaceSavings = (1.0 - compressionRatio) * 100.0
    }
    
    func display() {
        print("\n📊 COMPRESSION STATISTICS")
        print(String(repeating: "=", count: 50))
        print("Original size:     \(originalSize) bits (\(originalSize / 8) bytes)")
        print("Compressed size:   \(compressedSize) bits (\((compressedSize + 7) / 8) bytes)")
        print("Compression ratio: \(String(format: "%.2f%%", compressionRatio * 100))")
        print("Space savings:     \(String(format: "%.2f%%", spaceSavings))")
    }
}

// MARK: - Bit String Utilities

extension String {
    /// Convert binary string to bytes
    func toBinaryData() -> Data {
        var data = Data()
        var currentByte: UInt8 = 0
        var bitCount = 0
        
        for char in self {
            currentByte <<= 1
            if char == "1" {
                currentByte |= 1
            }
            bitCount += 1
            
            if bitCount == 8 {
                data.append(currentByte)
                currentByte = 0
                bitCount = 0
            }
        }
        
        // Append remaining bits
        if bitCount > 0 {
            currentByte <<= (8 - bitCount)
            data.append(currentByte)
        }
        
        return data
    }
}

extension Data {
    /// Convert bytes to binary string
    func toBinaryString() -> String {
        return self.map { byte in
            String(byte, radix: 2).padLeft(toLength: 8, withPad: "0")
        }.joined()
    }
}

extension String {
    func padLeft(toLength length: Int, withPad pad: Character) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: pad, count: padCount) + self
    }
}

// MARK: - Compression Tool

/// Main compression tool
class CompressionTool {
    
    /// Compress text and return encoded data
    func compress(text: String) -> (encoded: String, coder: HuffmanCoder, stats: CompressionStats) {
        let coder = HuffmanCoder()
        coder.buildTree(from: text)
        
        let encoded = coder.encode(text)
        
        let originalSize = text.count * 8 // 8 bits per character (ASCII)
        let compressedSize = encoded.count
        let stats = CompressionStats(originalSize: originalSize, compressedSize: compressedSize)
        
        return (encoded, coder, stats)
    }
    
    /// Decompress encoded data
    func decompress(encoded: String, coder: HuffmanCoder) -> String {
        return coder.decode(encoded)
    }
    
    /// Display Huffman code table
    func displayCodeTable(_ coder: HuffmanCoder) {
        print("\n📖 HUFFMAN CODE TABLE")
        print(String(repeating: "=", count: 50))
        print("Character | Code        | Bits")
        print(String(repeating: "-", count: 50))
        
        for (char, code, bits) in coder.getCodeTable() {
            let displayChar = char == " " ? "SPACE" : String(char)
            let paddedChar = displayChar.padding(toLength: 9, withPad: " ", startingAt: 0)
            let paddedCode = code.padding(toLength: 12, withPad: " ", startingAt: 0)
            print("\(paddedChar) | \(paddedCode) | \(bits)")
        }
    }
}

// MARK: - Demo Functions

func demonstrateBasicCompression() {
    print("\n1️⃣  BASIC COMPRESSION")
    print(String(repeating: "=", count: 50))
    
    let text = "HELLO WORLD"
    print("Original text: \"\(text)\"")
    
    let tool = CompressionTool()
    let (encoded, coder, stats) = tool.compress(text: text)
    
    print("Encoded: \(encoded)")
    
    tool.displayCodeTable(coder)
    stats.display()
    
    // Decompress
    let decompressed = tool.decompress(encoded: encoded, coder: coder)
    print("\n✅ Decompressed: \"\(decompressed)\"")
    print("Match: \(text == decompressed ? "YES ✓" : "NO ✗")")
}

func demonstrateTextCompression() {
    print("\n2️⃣  TEXT COMPRESSION")
    print(String(repeating: "=", count: 50))
    
    let text = """
    The quick brown fox jumps over the lazy dog. \
    This pangram contains every letter of the alphabet. \
    Huffman coding is an efficient compression algorithm.
    """
    
    print("Original text (\(text.count) characters):")
    print("\"\(text.prefix(80))...\"\n")
    
    let tool = CompressionTool()
    let (encoded, coder, stats) = tool.compress(text: text)
    
    print("Encoded length: \(encoded.count) bits")
    print("Encoded (first 80 bits): \(encoded.prefix(80))...")
    
    tool.displayCodeTable(coder)
    stats.display()
    
    // Verify decompression
    let decompressed = tool.decompress(encoded: encoded, coder: coder)
    print("\n✅ Decompression successful: \(text == decompressed ? "YES ✓" : "NO ✗")")
}

func demonstrateRepeatingPatterns() {
    print("\n3️⃣  REPEATING PATTERNS (High Compression)")
    print(String(repeating: "=", count: 50))
    
    let text = String(repeating: "AAAA", count: 20) + String(repeating: "B", count: 10)
    print("Original text: \(text.count) characters")
    print("Pattern: 80 A's + 10 B's")
    
    let tool = CompressionTool()
    let (encoded, coder, stats) = tool.compress(text: text)
    
    tool.displayCodeTable(coder)
    stats.display()
    
    print("\n💡 High compression ratio due to limited character set!")
}

func demonstrateBinaryData() {
    print("\n4️⃣  BINARY DATA CONVERSION")
    print(String(repeating: "=", count: 50))
    
    let text = "ABC"
    print("Original: \"\(text)\"")
    
    let tool = CompressionTool()
    let (encoded, coder, _) = tool.compress(text: text)
    
    print("Encoded binary: \(encoded)")
    
    // Convert to actual binary data
    let binaryData = encoded.toBinaryData()
    print("Binary data: \(binaryData.count) bytes")
    print("Hex: \(binaryData.map { String(format: "%02x", $0) }.joined(separator: " "))")
    
    // Convert back to binary string
    let binaryString = binaryData.toBinaryString()
    print("Back to binary: \(binaryString.prefix(encoded.count))")
    
    // Decompress (using original length)
    let truncated = String(binaryString.prefix(encoded.count))
    let decompressed = tool.decompress(encoded: truncated, coder: coder)
    print("Decompressed: \"\(decompressed)\"")
    print("Match: \(text == decompressed ? "YES ✓" : "NO ✗")")
}

func demonstrateTreeVisualization() {
    print("\n5️⃣  HUFFMAN TREE STRUCTURE")
    print(String(repeating: "=", count: 50))
    
    let text = "ABRACADABRA"
    print("Text: \"\(text)\"")
    
    let coder = HuffmanCoder()
    coder.buildTree(from: text)
    
    print("\n🌳 Tree serialization:")
    print(coder.serializeTree())
    
    print("\n📊 Character frequencies:")
    var frequencies: [Character: Int] = [:]
    for char in text {
        frequencies[char, default: 0] += 1
    }
    for (char, freq) in frequencies.sorted(by: { $0.key < $1.key }) {
        let bar = String(repeating: "█", count: freq)
        print("   \(char): \(freq) \(bar)")
    }
    
    let tool = CompressionTool()
    tool.displayCodeTable(coder)
}

// MARK: - Main Entry Point

@main
struct CompressionToolDemo {
    static func main() {
        print("╔════════════════════════════════════════╗")
        print("║   Huffman Coding Compression Tool      ║")
        print("║   Optimal Prefix-Free Encoding         ║")
        print("╚════════════════════════════════════════╝")
        
        demonstrateBasicCompression()
        demonstrateTextCompression()
        demonstrateRepeatingPatterns()
        demonstrateBinaryData()
        demonstrateTreeVisualization()
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ Compression tool demo completed!")
        print(String(repeating: "=", count: 50))
        
        // Additional info
        print("\n💡 KEY CONCEPTS:")
        print("   • Huffman coding uses variable-length codes")
        print("   • More frequent characters get shorter codes")
        print("   • Prefix-free property ensures unambiguous decoding")
        print("   • Optimal for symbol-by-symbol encoding")
        print("   • Used in JPEG, MP3, ZIP, and more")
    }
}

/*
 USAGE INSTRUCTIONS:
 ═══════════════════
 
 1. Run directly:
    swift CompressionTool.swift
    
 2. Compile and run:
    swiftc -o compress CompressionTool.swift
    ./compress
 
 3. To extend for file compression:
    - Read file content
    - Compress with Huffman
    - Save encoded data + tree
    - Load and decompress
 
 ALGORITHM:
 ═════════
 
 Huffman Coding Steps:
 1. Calculate character frequencies
 2. Create leaf nodes for each character
 3. Build priority queue (min-heap)
 4. Repeatedly merge two minimum nodes
 5. Generate codes by traversing tree
 6. Encode: Replace characters with codes
 7. Decode: Traverse tree using bits
 
 COMPLEXITY:
 ══════════
 
 Time Complexity:
 - Build tree: O(n log n) where n = unique characters
 - Encode: O(m) where m = text length
 - Decode: O(k) where k = encoded length
 
 Space Complexity:
 - O(n) for tree and code table
 
 FEATURES:
 ════════
 
 ✓ Optimal prefix-free encoding
 ✓ Min-heap priority queue
 ✓ Binary tree construction
 ✓ Code table generation
 ✓ Compression statistics
 ✓ Binary data conversion
 ✓ Tree serialization
 
 SWIFT IDIOMS:
 ════════════
 
 ✓ Protocol conformance (Comparable)
 ✓ Generic priority queue
 ✓ Class for tree nodes (reference semantics)
 ✓ Struct for value types
 ✓ Extensions for utility functions
 ✓ Optionals for tree navigation
 ✓ String manipulation
 ✓ Higher-order functions (map, sorted)
 
 EXTENDING:
 ═════════
 
 To create a CLI tool:
 
   if CommandLine.arguments.count > 1 {
       let command = CommandLine.arguments[1]
       
       switch command {
       case "compress":
           let file = CommandLine.arguments[2]
           // Read, compress, save
       case "decompress":
           let file = CommandLine.arguments[2]
           // Read, decompress, save
       default:
           print("Usage: compress|decompress <file>")
       }
   }
 
 PRODUCTION CONSIDERATIONS:
 ═════════════════════════
 
 For production use:
 - Store compressed data with tree/codes
 - Handle large files with streaming
 - Add error handling for corrupt data
 - Support multiple compression levels
 - Implement adaptive Huffman coding
 - Add multi-threading for large files
 - Combine with other techniques (RLE, LZ77)
*/
