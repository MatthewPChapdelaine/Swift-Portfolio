public func greet(_ name: String) -> String {
    return "Hello, \(name)!"
}

@main
struct SwiftProject {
    static func main() {
        print("Swift Project Template")
        print(greet("World"))
    }
}
