# Blog Engine - Swift Edition

Modern blogging platform with Swift's async/await and Vapor framework.

## Features

- **Swift Concurrency**: async/await for modern async code
- **Vapor Framework**: Fast, type-safe web framework
- **Fluent ORM**: Type-safe database queries
- **SQLite**: Embedded database
- **Codable**: Automatic JSON serialization
- **Strong Types**: Compile-time safety

## Build & Run

```bash
swift build
swift run
```

Server: `http://localhost:4000`

## API Usage

**List Posts**
```bash
curl http://localhost:4000/api/posts
```

**Create Post**
```bash
curl -X POST http://localhost:4000/api/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"New Post","content":"Content here","published":true}'
```

**Register User**
```bash
curl -X POST http://localhost:4000/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com","passwordHash":"hash"}'
```

## Project Structure

```
Sources/
├── BlogEngine/
│   └── main.swift          # App entry point
├── Models/
│   ├── User.swift          # User model
│   ├── Post.swift          # Post model
│   └── Comment.swift       # Comment model
├── Database/               # Database migrations
└── Server/                 # Route handlers
```

## Architecture

- **Async/Await**: Native concurrency
- **Protocol-Oriented**: Swift's protocol system
- **Value Types**: Structs over classes
- **Optionals**: Safe null handling

## License

MIT
