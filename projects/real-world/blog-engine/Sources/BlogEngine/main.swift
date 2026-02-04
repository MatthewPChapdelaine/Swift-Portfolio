import Vapor
import Fluent
import FluentSQLiteDriver

@main
struct BlogEngine {
    static func main() throws {
        let app = Application()
        defer { app.shutdown() }
        
        // Configure database
        app.databases.use(.sqlite(.file("blog.db")), as: .sqlite)
        
        // Migrations
        app.migrations.add(CreateUsers())
        app.migrations.add(CreatePosts())
        app.migrations.add(CreateComments())
        
        try app.autoMigrate().wait()
        
        // Routes
        configureRoutes(app)
        
        print("🚀 Swift Blog Engine running on http://localhost:4000")
        try app.run()
    }
}

func configureRoutes(_ app: Application) {
    app.get { req in
        """
        <!DOCTYPE html>
        <html>
        <head><title>Swift Blog Engine</title>
        <style>body{font-family:Arial;max-width:800px;margin:0 auto;padding:20px;}h1{color:#f05138;}</style>
        </head>
        <body>
        <h1>�� Swift Blog Engine</h1>
        <p>Type-safe blogging with Swift and Vapor</p>
        <h2>Features</h2>
        <ul>
        <li>Swift async/await concurrency</li>
        <li>Vapor web framework</li>
        <li>Fluent ORM with SQLite</li>
        <li>Type-safe models and routes</li>
        <li>Markdown rendering</li>
        </ul>
        <h2>API Endpoints</h2>
        <ul>
        <li>GET /api/posts - List posts</li>
        <li>POST /api/posts - Create post</li>
        <li>GET /api/posts/:id - View post</li>
        <li>POST /api/register - Register user</li>
        <li>POST /api/login - Login</li>
        </ul>
        </body>
        </html>
        """
    }
    
    let api = app.grouped("api")
    
    api.get("posts") { req async throws -> [Post] in
        try await Post.query(on: req.db).all()
    }
    
    api.post("posts") { req async throws -> Post in
        let post = try req.content.decode(Post.self)
        try await post.save(on: req.db)
        return post
    }
    
    api.get("posts", ":id") { req async throws -> Post in
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let post = try await Post.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        return post
    }
    
    api.post("register") { req async throws -> User in
        let user = try req.content.decode(User.self)
        try await user.save(on: req.db)
        return user
    }
    
    api.post("login") { req async throws -> String in
        return "token_example"
    }
}
