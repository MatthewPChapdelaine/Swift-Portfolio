import XCTest
@testable import SwiftProject

final class SwiftProjectTests: XCTestCase {
    func testGreet() {
        XCTAssertEqual(greet("Alice"), "Hello, Alice!")
        XCTAssertEqual(greet("Bob"), "Hello, Bob!")
    }
    
    func testGreetEmpty() {
        XCTAssertEqual(greet(""), "Hello, !")
    }
}
