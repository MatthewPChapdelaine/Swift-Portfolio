import Fluent
import Vapor

final class Post: Model, Content {
    static let schema = "posts"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "slug")
    var slug: String
    
    @Field(key: "content")
    var content: String
    
    @Field(key: "published")
    var published: Bool
    
    @Parent(key: "author_id")
    var author: User
    
    @Children(for: \.$post)
    var comments: [Comment]
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, title: String, slug: String, content: String, published: Bool = false, authorID: UUID) {
        self.id = id
        self.title = title
        self.slug = slug
        self.content = content
        self.published = published
        self.$author.id = authorID
    }
}

struct CreatePosts: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("posts")
            .id()
            .field("title", .string, .required)
            .field("slug", .string, .required)
            .field("content", .string, .required)
            .field("published", .bool, .required)
            .field("author_id", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .unique(on: "slug")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("posts").delete()
    }
}
