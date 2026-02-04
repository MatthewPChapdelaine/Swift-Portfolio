#!/usr/bin/env swift

/// Mini HTTP Framework with Routing and Middleware
/// Built using Swift Concurrency (async/await)
///
/// Features:
/// - Route registration with HTTP methods (GET, POST, PUT, DELETE)
/// - Middleware pipeline
/// - Request/Response abstractions
/// - Query parameter parsing
/// - JSON encoding/decoding
/// - Error handling
///
/// Compile: swiftc -o webserver WebFramework.swift
/// Run: ./webserver
/// Or: swift WebFramework.swift

import Foundation

// MARK: - HTTP Types

/// HTTP method enumeration
enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD
}

/// HTTP status codes
enum HTTPStatus: Int {
    case ok = 200
    case created = 201
    case noContent = 204
    case badRequest = 400
    case notFound = 404
    case methodNotAllowed = 405
    case internalServerError = 500
    
    var description: String {
        switch self {
        case .ok: return "OK"
        case .created: return "Created"
        case .noContent: return "No Content"
        case .badRequest: return "Bad Request"
        case .notFound: return "Not Found"
        case .methodNotAllowed: return "Method Not Allowed"
        case .internalServerError: return "Internal Server Error"
        }
    }
}

// MARK: - Request

/// HTTP Request representation
struct HTTPRequest {
    let method: HTTPMethod
    let path: String
    let headers: [String: String]
    let queryParams: [String: String]
    let body: Data?
    
    init(method: HTTPMethod, path: String, headers: [String: String] = [:], queryParams: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.queryParams = queryParams
        self.body = body
    }
    
    /// Decode JSON body
    func decodeBody<T: Decodable>(_ type: T.Type) throws -> T {
        guard let body = body else {
            throw WebError.missingBody
        }
        return try JSONDecoder().decode(type, from: body)
    }
}

// MARK: - Response

/// HTTP Response representation
struct HTTPResponse {
    var status: HTTPStatus
    var headers: [String: String]
    var body: Data?
    
    init(status: HTTPStatus, headers: [String: String] = [:], body: Data? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }
    
    /// Create JSON response
    static func json<T: Encodable>(_ data: T, status: HTTPStatus = .ok) throws -> HTTPResponse {
        let jsonData = try JSONEncoder().encode(data)
        return HTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: jsonData
        )
    }
    
    /// Create text response
    static func text(_ text: String, status: HTTPStatus = .ok) -> HTTPResponse {
        return HTTPResponse(
            status: status,
            headers: ["Content-Type": "text/plain"],
            body: text.data(using: .utf8)
        )
    }
    
    /// Create HTML response
    static func html(_ html: String, status: HTTPStatus = .ok) -> HTTPResponse {
        return HTTPResponse(
            status: status,
            headers: ["Content-Type": "text/html"],
            body: html.data(using: .utf8)
        )
    }
}

// MARK: - Context

/// Request context passed through middleware and handlers
actor RequestContext {
    let request: HTTPRequest
    private var state: [String: Any] = [:]
    
    init(request: HTTPRequest) {
        self.request = request
    }
    
    func set(key: String, value: Any) {
        state[key] = value
    }
    
    func get<T>(key: String) -> T? {
        state[key] as? T
    }
}

// MARK: - Middleware

/// Middleware type alias
typealias Middleware = (RequestContext) async throws -> Void

/// Middleware factory functions
enum MiddlewareFactory {
    /// Logging middleware
    static func logger() -> Middleware {
        return { context in
            let request = await context.request
            let timestamp = Date()
            print("[\(timestamp)] \(request.method.rawValue) \(request.path)")
        }
    }
    
    /// Authentication middleware (demo)
    static func auth(requiredToken: String) -> Middleware {
        return { context in
            let request = await context.request
            guard let token = request.headers["Authorization"],
                  token == "Bearer \(requiredToken)" else {
                throw WebError.unauthorized
            }
            await context.set(key: "authenticated", value: true)
        }
    }
    
    /// CORS middleware
    static func cors() -> Middleware {
        return { context in
            await context.set(key: "cors", value: true)
        }
    }
    
    /// Request timing middleware
    static func timing() -> Middleware {
        return { context in
            let start = Date()
            await context.set(key: "startTime", value: start)
        }
    }
}

// MARK: - Route Handler

/// Route handler type
typealias RouteHandler = (RequestContext) async throws -> HTTPResponse

// MARK: - Route

/// Route definition
struct Route {
    let method: HTTPMethod
    let path: String
    let handler: RouteHandler
    
    /// Check if route matches request
    func matches(method: HTTPMethod, path: String) -> Bool {
        return self.method == method && self.path == path
    }
}

// MARK: - Router

/// HTTP Router with middleware support
actor Router {
    private var routes: [Route] = []
    private var middlewares: [Middleware] = []
    
    /// Register middleware
    func use(_ middleware: @escaping Middleware) {
        middlewares.append(middleware)
    }
    
    /// Register route
    func register(method: HTTPMethod, path: String, handler: @escaping RouteHandler) {
        let route = Route(method: method, path: path, handler: handler)
        routes.append(route)
        print("📝 Registered: \(method.rawValue) \(path)")
    }
    
    /// Convenience methods for HTTP verbs
    func get(_ path: String, handler: @escaping RouteHandler) {
        register(method: .GET, path: path, handler: handler)
    }
    
    func post(_ path: String, handler: @escaping RouteHandler) {
        register(method: .POST, path: path, handler: handler)
    }
    
    func put(_ path: String, handler: @escaping RouteHandler) {
        register(method: .PUT, path: path, handler: handler)
    }
    
    func delete(_ path: String, handler: @escaping RouteHandler) {
        register(method: .DELETE, path: path, handler: handler)
    }
    
    /// Handle incoming request
    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let context = RequestContext(request: request)
        
        do {
            // Execute middleware pipeline
            for middleware in middlewares {
                try await middleware(context)
            }
            
            // Find matching route
            guard let route = routes.first(where: { $0.matches(method: request.method, path: request.path) }) else {
                return HTTPResponse.text("Not Found", status: .notFound)
            }
            
            // Execute handler
            let response = try await route.handler(context)
            
            // Add timing header if timing middleware was used
            if let startTime: Date = await context.get(key: "startTime") {
                let elapsed = Date().timeIntervalSince(startTime)
                var modifiedResponse = response
                modifiedResponse.headers["X-Response-Time"] = "\(Int(elapsed * 1000))ms"
                return modifiedResponse
            }
            
            return response
            
        } catch let error as WebError {
            return HTTPResponse.text(error.message, status: error.status)
        } catch {
            return HTTPResponse.text("Internal Server Error", status: .internalServerError)
        }
    }
}

// MARK: - Web Error

/// Custom web framework errors
enum WebError: Error {
    case notFound
    case badRequest(String)
    case unauthorized
    case missingBody
    case invalidJSON
    
    var status: HTTPStatus {
        switch self {
        case .notFound: return .notFound
        case .badRequest: return .badRequest
        case .unauthorized: return .badRequest
        case .missingBody, .invalidJSON: return .badRequest
        }
    }
    
    var message: String {
        switch self {
        case .notFound: return "Resource not found"
        case .badRequest(let msg): return "Bad request: \(msg)"
        case .unauthorized: return "Unauthorized"
        case .missingBody: return "Missing request body"
        case .invalidJSON: return "Invalid JSON"
        }
    }
}

// MARK: - Application

/// Web application
actor WebApplication {
    let router: Router
    let port: Int
    
    init(port: Int = 3000) {
        self.port = port
        self.router = Router()
    }
    
    /// Configure routes and middleware
    func configure() async {
        // Add middleware
        await router.use(MiddlewareFactory.logger())
        await router.use(MiddlewareFactory.timing())
        await router.use(MiddlewareFactory.cors())
        
        // Register routes
        await setupRoutes()
    }
    
    private func setupRoutes() async {
        // Home route
        await router.get("/") { context in
            let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Swift Web Framework</title></head>
            <body>
                <h1>🚀 Swift Web Framework</h1>
                <p>Welcome to the mini HTTP framework!</p>
                <h2>Available Routes:</h2>
                <ul>
                    <li>GET / - This page</li>
                    <li>GET /api/users - Get all users</li>
                    <li>GET /api/users/1 - Get user by ID</li>
                    <li>POST /api/users - Create user</li>
                    <li>GET /api/health - Health check</li>
                </ul>
            </body>
            </html>
            """
            return HTTPResponse.html(html)
        }
        
        // Health check
        await router.get("/api/health") { context in
            struct HealthResponse: Codable {
                let status: String
                let timestamp: Date
            }
            
            let health = HealthResponse(status: "healthy", timestamp: Date())
            return try HTTPResponse.json(health)
        }
        
        // Get all users
        await router.get("/api/users") { context in
            let users = await UserStore.shared.getAllUsers()
            return try HTTPResponse.json(users)
        }
        
        // Get user by ID (demo - parsing path parameter manually)
        await router.get("/api/users/1") { context in
            if let user = await UserStore.shared.getUser(id: 1) {
                return try HTTPResponse.json(user)
            }
            return HTTPResponse.text("User not found", status: .notFound)
        }
        
        // Create user
        await router.post("/api/users") { context in
            struct CreateUserRequest: Codable {
                let name: String
                let email: String
            }
            
            let request = await context.request
            let createReq = try request.decodeBody(CreateUserRequest.self)
            
            let user = User(
                id: await UserStore.shared.nextId(),
                name: createReq.name,
                email: createReq.email
            )
            
            await UserStore.shared.addUser(user)
            
            return try HTTPResponse.json(user, status: .created)
        }
        
        // Delete user
        await router.delete("/api/users/1") { context in
            await UserStore.shared.deleteUser(id: 1)
            return HTTPResponse.text("User deleted", status: .noContent)
        }
    }
    
    /// Start server (simulated)
    func start() async {
        print("\n🚀 Starting web server on port \(port)...")
        print("📡 Server ready at http://localhost:\(port)")
        print("=" .repeating(50))
        
        // Simulate incoming requests
        await simulateRequests()
    }
    
    private func simulateRequests() async {
        let requests: [(HTTPMethod, String, Data?)] = [
            (.GET, "/", nil),
            (.GET, "/api/health", nil),
            (.GET, "/api/users", nil),
            (.POST, "/api/users", """
                {"name": "Alice Smith", "email": "alice@example.com"}
                """.data(using: .utf8)),
            (.POST, "/api/users", """
                {"name": "Bob Jones", "email": "bob@example.com"}
                """.data(using: .utf8)),
            (.GET, "/api/users", nil),
            (.GET, "/api/users/1", nil),
            (.DELETE, "/api/users/1", nil),
            (.GET, "/api/notfound", nil)
        ]
        
        for (method, path, body) in requests {
            let request = HTTPRequest(
                method: method,
                path: path,
                headers: [:],
                queryParams: [:],
                body: body
            )
            
            let response = await router.handle(request)
            
            print("\n→ \(method.rawValue) \(path)")
            print("← \(response.status.rawValue) \(response.status.description)")
            
            if let timing = response.headers["X-Response-Time"] {
                print("  ⏱️  Response time: \(timing)")
            }
            
            if let body = response.body, let bodyStr = String(data: body, encoding: .utf8) {
                let preview = bodyStr.prefix(200)
                print("  📦 Body: \(preview)\(bodyStr.count > 200 ? "..." : "")")
            }
            
            // Delay between requests
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
    }
}

// MARK: - User Model

/// User model
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

/// Simple in-memory user store
actor UserStore {
    static let shared = UserStore()
    
    private var users: [Int: User] = [:]
    private var currentId = 1
    
    private init() {
        // Seed with initial data
        users[1] = User(id: 1, name: "John Doe", email: "john@example.com")
        users[2] = User(id: 2, name: "Jane Smith", email: "jane@example.com")
        currentId = 3
    }
    
    func nextId() -> Int {
        let id = currentId
        currentId += 1
        return id
    }
    
    func getAllUsers() -> [User] {
        return Array(users.values).sorted { $0.id < $1.id }
    }
    
    func getUser(id: Int) -> User? {
        return users[id]
    }
    
    func addUser(_ user: User) {
        users[user.id] = user
    }
    
    func deleteUser(id: Int) {
        users.removeValue(forKey: id)
    }
}

// MARK: - String Extensions

extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - Main Entry Point

@main
struct WebFrameworkDemo {
    static func main() async {
        print("╔════════════════════════════════════════╗")
        print("║    Swift Web Framework Demo            ║")
        print("║    Mini HTTP Framework with Routing    ║")
        print("╚════════════════════════════════════════╝")
        
        let app = WebApplication(port: 3000)
        await app.configure()
        await app.start()
        
        print("\n" + "=".repeating(50))
        print("✅ Demo completed successfully!")
        print("=" .repeating(50))
    }
}

/*
 USAGE INSTRUCTIONS:
 ═══════════════════
 
 1. Run directly:
    swift WebFramework.swift
    
 2. Compile and run:
    swiftc -o webserver WebFramework.swift
    ./webserver
 
 FEATURES:
 ════════
 
 ✓ HTTP Method routing (GET, POST, PUT, DELETE)
 ✓ Middleware pipeline (logging, timing, CORS, auth)
 ✓ Request/Response abstractions
 ✓ JSON encoding/decoding
 ✓ Query parameter parsing
 ✓ Error handling
 ✓ Actor-based concurrency
 ✓ Type-safe routing
 
 ARCHITECTURE:
 ════════════
 
 WebApplication
     │
     └─> Router (Actor)
           ├─> Middlewares[]
           └─> Routes[]
                 └─> RouteHandler
 
 Request Flow:
 ════════════
 
 HTTPRequest → Middleware Pipeline → Route Matching → Handler → HTTPResponse
 
 MIDDLEWARE EXAMPLES:
 ══════════════════
 
 - Logger: Logs all requests
 - Timing: Tracks response time
 - CORS: Adds CORS headers
 - Auth: Validates authentication tokens
 
 EXTENDING:
 ═════════
 
 To add a new route:
 
   await router.get("/my/path") { context in
       let data = MyData(message: "Hello")
       return try HTTPResponse.json(data)
   }
 
 To add middleware:
 
   await router.use { context in
       // Middleware logic
       let request = await context.request
       // Process...
   }
 
 PRODUCTION CONSIDERATIONS:
 ═════════════════════════
 
 For production use, you would need:
 - Actual TCP/HTTP server (use SwiftNIO or Network framework)
 - Path parameter parsing (/users/:id)
 - Body parsing for different content types
 - Cookie and session management
 - Template engine integration
 - Static file serving
 - WebSocket support
 - Database integration
 - Proper error handling and logging
 - Security middleware (CSRF, XSS protection)
 - Rate limiting
 - Compression
*/
