// JSON Parser - Parse, manipulate, validate and write JSON data
//
// Compile: swiftc json-parser.swift -o json-parser
// Run: ./json-parser
// Or run directly: swift json-parser.swift

import Foundation

struct User: Codable {
    var id: Int
    var name: String
    var email: String
    var age: Int
}

func validateEmail(_ email: String) -> Bool {
    return email.contains("@") && email.contains(".")
}

func validateUser(_ user: User) -> String? {
    if user.id <= 0 { return "Invalid user ID" }
    if user.name.isEmpty { return "Name cannot be empty" }
    if !validateEmail(user.email) { return "Invalid email format" }
    if user.age < 0 { return "Invalid age" }
    return nil
}

func usersToJSON(_ users: [User]) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(users) else { return nil }
    return String(data: data, encoding: .utf8)
}

func manipulateData(_ users: inout [User]) -> (sorted: [User], filtered: [User]) {
    // Add new user
    users.append(User(id: 4, name: "Diana", email: "diana@example.com", age: 31))
    
    // Update existing user
    if let index = users.firstIndex(where: { $0.id == 2 }) {
        users[index].age = 36
    }
    
    // Filter users over 30
    let filtered = users.filter { $0.age > 30 }
    
    // Sort by age
    let sorted = users.sorted { $0.age < $1.age }
    
    return (sorted, filtered)
}

// Main program
print("=== JSON Parser Demo ===\n")

var users = [
    User(id: 1, name: "Alice", email: "alice@example.com", age: 28),
    User(id: 2, name: "Bob", email: "bob@example.com", age: 35),
    User(id: 3, name: "Charlie", email: "charlie@example.com", age: 42)
]

// Validate users
print("Validating users:")
for user in users {
    if let error = validateUser(user) {
        print("  ✗ User \(user.id): \(error)")
    } else {
        print("  ✓ User \(user.id): Valid")
    }
}
print()

// Show JSON
print("JSON representation:")
if let json = usersToJSON(users) {
    print(json)
}
print()

// Manipulate data
print("Manipulating data...")
let (sorted, filtered) = manipulateData(&users)
print("✓ Data manipulated\n")

// Show results
print("Users over 30:")
for user in filtered {
    print("  - \(user.name) (age: \(user.age))")
}
print()

print("Sorted by age:")
for user in sorted {
    print("  - \(user.name) (\(user.age))")
}

print("\n✓ Demo complete")
