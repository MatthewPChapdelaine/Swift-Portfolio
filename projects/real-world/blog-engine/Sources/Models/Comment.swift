import Fluent
import Vapor

final class Comment: Model, Content {
    static let schema = "comments"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "content")
    var content: String
    
    @Field(key: "author_name")
    var authorName: String
    
    @Parent(key: "post_id")
    var post: Post
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, content: String, authorName: String, postID: UUID) {
        self.id = id
        self.content = content
        self.authorName = authorName
        self.$post.id = postID
    }
}

struct CreateComments: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("comments")
            .id()
            .field("content", .string, .required)
            .field("author_name", .string, .required)
            .field("post_id", .uuid, .required, .references("posts", "id"))
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("comments").delete()
    }
}
