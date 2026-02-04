// File Processor - Process CSV/text files and calculate statistics
//
// Run: swift file-processor.swift

import Foundation

struct Stats {
    let count: Int
    let sum: Double
    let mean: Double
    let median: Double
    let min: Double
    let max: Double
    let stdDev: Double
}

func calculateStats(_ values: [Double]) -> Stats? {
    guard !values.isEmpty else { return nil }
    
    let sorted = values.sorted()
    let n = values.count
    let sum = values.reduce(0, +)
    let mean = sum / Double(n)
    
    let median: Double
    if n % 2 == 0 {
        median = (sorted[n/2 - 1] + sorted[n/2]) / 2
    } else {
        median = sorted[n/2]
    }
    
    let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(n)
    let stdDev = sqrt(variance)
    
    return Stats(
        count: n,
        sum: sum,
        mean: mean,
        median: median,
        min: sorted.first!,
        max: sorted.last!,
        stdDev: stdDev
    )
}

func generateReport(_ title: String, _ stats: Stats?) -> String {
    let line = String(repeating: "=", count: 50)
    var report = "\n\(line)\n"
    report += String(repeating: " ", count: (50 - title.count) / 2) + title + "\n"
    report += "\(line)\n\n"
    
    if let s = stats {
        report += String(format: "  Count:              %d\n", s.count)
        report += String(format: "  Sum:                %.2f\n", s.sum)
        report += String(format: "  Mean:               %.2f\n", s.mean)
        report += String(format: "  Median:             %.2f\n", s.median)
        report += String(format: "  Min:                %.2f\n", s.min)
        report += String(format: "  Max:                %.2f\n", s.max)
        report += String(format: "  Standard Deviation: %.2f\n", s.stdDev)
    } else {
        report += "No data available\n"
    }
    
    report += "\n\(line)\n"
    return report
}

// Main program
print("=== File Processor Demo ===\n")

let salesData: [[String: Any]] = [
    ["date": "2024-01-01", "product": "Widget", "quantity": 5, "total": 99.95],
    ["date": "2024-01-02", "product": "Gadget", "quantity": 3, "total": 89.97],
    ["date": "2024-01-03", "product": "Widget", "quantity": 8, "total": 159.92]
]

print("Processing \(salesData.count) records\n")

// Calculate statistics
let quantities = salesData.compactMap { $0["quantity"] as? Int }.map(Double.init)
let qStats = calculateStats(quantities)
print(generateReport("Quantity Statistics", qStats))

let totals = salesData.compactMap { $0["total"] as? Double }
let tStats = calculateStats(totals)
print(generateReport("Sales Total Statistics", tStats))

print("\n✓ Processing demo complete")
