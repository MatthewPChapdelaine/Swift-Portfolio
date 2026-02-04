// Data Structures - Linked List, Binary Search Tree, Hash Map
//
// Run: swift data-structures.swift

import Foundation

// Linked List
class LinkedList<T: Equatable> {
    private class Node {
        var value: T
        var next: Node?
        
        init(_ value: T) {
            self.value = value
        }
    }
    
    private var head: Node?
    
    func append(_ value: T) {
        let newNode = Node(value)
        guard let head = head else {
            self.head = newNode
            return
        }
        
        var current = head
        while current.next != nil {
            current = current.next!
        }
        current.next = newNode
    }
    
    func prepend(_ value: T) {
        let newNode = Node(value)
        newNode.next = head
        head = newNode
    }
    
    func find(_ value: T) -> Bool {
        var current = head
        while current != nil {
            if current!.value == value {
                return true
            }
            current = current!.next
        }
        return false
    }
    
    func toArray() -> [T] {
        var result: [T] = []
        var current = head
        while current != nil {
            result.append(current!.value)
            current = current!.next
        }
        return result
    }
}

// Binary Search Tree
class BinarySearchTree<T: Comparable> {
    private class Node {
        var value: T
        var left: Node?
        var right: Node?
        
        init(_ value: T) {
            self.value = value
        }
    }
    
    private var root: Node?
    
    func insert(_ value: T) {
        root = insertNode(root, value)
    }
    
    private func insertNode(_ node: Node?, _ value: T) -> Node {
        guard let node = node else {
            return Node(value)
        }
        
        if value < node.value {
            node.left = insertNode(node.left, value)
        } else if value > node.value {
            node.right = insertNode(node.right, value)
        }
        
        return node
    }
    
    func search(_ value: T) -> Bool {
        return searchNode(root, value)
    }
    
    private func searchNode(_ node: Node?, _ value: T) -> Bool {
        guard let node = node else { return false }
        
        if value == node.value {
            return true
        } else if value < node.value {
            return searchNode(node.left, value)
        } else {
            return searchNode(node.right, value)
        }
    }
    
    func inorderTraversal() -> [T] {
        var result: [T] = []
        inorder(root, &result)
        return result
    }
    
    private func inorder(_ node: Node?, _ result: inout [T]) {
        guard let node = node else { return }
        inorder(node.left, &result)
        result.append(node.value)
        inorder(node.right, &result)
    }
}

// Main program
print("=== Data Structures Demo ===\n")

// Linked List
print("1. Linked List:")
let list = LinkedList<Int>()
list.append(10)
list.append(20)
list.append(30)
list.prepend(5)
print("   List: \(list.toArray().map(String.init).joined(separator: " -> "))")
print("   Find 20: \(list.find(20) ? "Found" : "Not found")\n")

// BST
print("2. Binary Search Tree:")
let bst = BinarySearchTree<Int>()
let values = [50, 30, 70, 20, 40, 60, 80]
values.forEach { bst.insert($0) }
print("   Inserted: \(values.map(String.init).joined(separator: ", "))")
print("   Inorder: \(bst.inorderTraversal().map(String.init).joined(separator: ", "))")
print("   Search 40: \(bst.search(40) ? "Found" : "Not found")\n")

// HashMap (using Swift's Dictionary)
print("3. Hash Map:")
var map: [String: String] = [:]
map["name"] = "Alice"
map["age"] = "28"
map["city"] = "New York"
print("   Size: \(map.count)")
print("   Get 'name': \(map["name"] ?? "nil")")
map.removeValue(forKey: "age")
print("   After remove, size: \(map.count)")

print("\n✓ Demo complete")
