// Sorting Algorithms - QuickSort, MergeSort, BubbleSort
//
// Run: swift sorting-algorithms.swift

import Foundation

func quickSort(_ arr: [Int]) -> [Int] {
    guard arr.count > 1 else { return arr }
    
    let pivot = arr[0]
    let left = arr.dropFirst().filter { $0 < pivot }
    let right = arr.dropFirst().filter { $0 >= pivot }
    
    return quickSort(Array(left)) + [pivot] + quickSort(Array(right))
}

func mergeSort(_ arr: [Int]) -> [Int] {
    guard arr.count > 1 else { return arr }
    
    let mid = arr.count / 2
    let left = Array(arr[..<mid])
    let right = Array(arr[mid...])
    
    return merge(mergeSort(left), mergeSort(right))
}

func merge(_ left: [Int], _ right: [Int]) -> [Int] {
    var result: [Int] = []
    var i = 0, j = 0
    
    while i < left.count && j < right.count {
        if left[i] <= right[j] {
            result.append(left[i])
            i += 1
        } else {
            result.append(right[j])
            j += 1
        }
    }
    
    result += left[i...]
    result += right[j...]
    
    return result
}

func bubbleSort(_ arr: [Int]) -> [Int] {
    var result = arr
    let n = result.count
    
    for i in 0..<n-1 {
        var swapped = false
        for j in 0..<n-i-1 {
            if result[j] > result[j+1] {
                result.swapAt(j, j+1)
                swapped = true
            }
        }
        if !swapped { break }
    }
    
    return result
}

func isSorted(_ arr: [Int]) -> Bool {
    for i in 0..<arr.count-1 {
        if arr[i] > arr[i+1] { return false }
    }
    return true
}

// Main program
print("=== Sorting Algorithms Demo ===\n")

let small = [64, 34, 25, 12, 22, 11, 90]
print("1. Small Array Test:")
print("   Original: \(small.map(String.init).joined(separator: ", "))")
print("   QuickSort: \(quickSort(small).map(String.init).joined(separator: ", "))")
print("   MergeSort: \(mergeSort(small).map(String.init).joined(separator: ", "))")
print("   BubbleSort: \(bubbleSort(small).map(String.init).joined(separator: ", "))")

print("\n✓ Sorting demo complete")
