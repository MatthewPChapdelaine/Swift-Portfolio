import Foundation
import Yams

struct Package: Codable {
    let name: String
    let version: String
    var dependencies: [String: String] = [:]
}

struct PackageManager {
    let registry: [String: Package] = [
        "Vapor": Package(name: "Vapor", version: "4.0.0", dependencies: ["SwiftNIO": "^2.0.0"]),
        "SwiftNIO": Package(name: "SwiftNIO", version: "2.50.0", dependencies: [:]),
        "Yams": Package(name: "Yams", version: "5.0.0", dependencies: [:]),
    ]
    
    func parseManifest(_ path: String) -> Package? {
        guard let data = try? String(contentsOfFile: path) else { return nil }
        return try? YAMLDecoder().decode(Package.self, from: data)
    }
    
    func resolve(dependencies: [String: String]) -> [Package] {
        var resolved: [Package] = []
        var visited: Set<String> = []
        
        func resolvePackage(_ name: String) {
            guard !visited.contains(name) else { return }
            visited.insert(name)
            
            if let pkg = registry[name] {
                resolved.append(pkg)
                for (dep, _) in pkg.dependencies {
                    resolvePackage(dep)
                }
            }
        }
        
        for (name, _) in dependencies {
            resolvePackage(name)
        }
        
        return resolved
    }
    
    func install(_ packages: [Package]) {
        print("📥 Installing \(packages.count) packages...")
        for pkg in packages {
            print("  ⬇  \(pkg.name) @ \(pkg.version)")
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    func generateLock(_ packages: [Package]) {
        let lock = packages.reduce(into: [:]) { $0[$1.name] = $1.version }
        if let data = try? JSONEncoder().encode(lock) {
            try? data.write(to: URL(fileURLWithPath: "Package.lock"))
            print("📝 Generated Package.lock")
        }
    }
    
    func visualizeGraph(_ dependencies: [String: String]) {
        print("\n🌳 Dependency Graph:")
        var visited: Set<String> = []
        
        func printDeps(_ name: String, indent: String = "") {
            guard !visited.contains(name) else { return }
            visited.insert(name)
            
            print("\(indent)\(name)")
            if let pkg = registry[name] {
                for (dep, _) in pkg.dependencies {
                    printDeps(dep, indent: indent + "  └─ ")
                }
            }
        }
        
        for (name, _) in dependencies {
            printDeps(name)
        }
    }
}

@main
struct CLI {
    static func main() {
        let args = CommandLine.arguments
        let command = args.count > 1 ? args[1] : "help"
        
        let pm = PackageManager()
        
        switch command {
        case "install":
            print("📦 Reading Package.yaml...")
            if let manifest = pm.parseManifest("Package.yaml") {
                print("🔍 Resolving dependencies...")
                let resolved = pm.resolve(dependencies: manifest.dependencies)
                print("✓ Resolved \(resolved.count) packages")
                pm.install(resolved)
                pm.generateLock(resolved)
                print("✓ Installation complete!")
            } else {
                print("❌ Failed to read manifest")
            }
            
        case "graph":
            if let manifest = pm.parseManifest("Package.yaml") {
                pm.visualizeGraph(manifest.dependencies)
            }
            
        default:
            print("""
            PackageManager - Swift Dependency Management
            
            Usage:
              package-manager install    Install dependencies
              package-manager graph      Show dependency graph
            """)
        }
    }
}
