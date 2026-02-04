import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "username")
    var username: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Field(key: "role")
    var role: String
    
    @Children(for: \.$author)
    var posts: [Post]
    
    init() {}
    
    init(id: UUID? = nil, username: String, email: String, passwordHash: String, role: String = "user") {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.role = role
    }
}

struct CreateUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("username", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("role", .string, .required)
            .unique(on: "username")
            .unique(on: "email")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
