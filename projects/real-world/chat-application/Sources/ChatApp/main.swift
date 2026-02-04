import Vapor
import WebSocketKit

actor RoomManager {
    private var rooms: [String: [WebSocket]] = [:]
    
    func createRoom(_ name: String) {
        if rooms[name] == nil {
            rooms[name] = []
            print("✓ Created room: \(name)")
        }
    }
    
    func join(room: String, socket: WebSocket) {
        if rooms[room] == nil {
            createRoom(room)
        }
        rooms[room]?.append(socket)
    }
    
    func leave(room: String, socket: WebSocket) {
        rooms[room]?.removeAll { $0 === socket }
    }
    
    func broadcast(to room: String, message: String) {
        guard let sockets = rooms[room] else { return }
        for socket in sockets {
            socket.send(message)
        }
    }
}

@main
struct ChatApp {
    static func main() throws {
        let app = Application()
        defer { app.shutdown() }
        
        let roomManager = RoomManager()
        
        app.get { req in
            """
            <!DOCTYPE html>
            <html>
            <head><title>Swift Chat App</title>
            <style>body{font-family:Arial;max-width:800px;margin:0 auto;padding:20px;}h1{color:#f05138;}</style>
            </head>
            <body>
            <h1>💬 Swift Chat Application</h1>
            <p>Real-time chat with Swift actors and WebSockets</p>
            <h2>Features</h2>
            <ul>
            <li>Actor-based concurrency</li>
            <li>WebSocket real-time messaging</li>
            <li>Multiple chat rooms</li>
            <li>Thread-safe state management</li>
            <li>Swift structured concurrency</li>
            </ul>
            <p>WebSocket endpoint: <code>ws://localhost:4001/ws</code></p>
            </body>
            </html>
            """
        }
        
        app.webSocket("ws") { req, ws in
            Task {
                await roomManager.join(room: "general", socket: ws)
                
                ws.onText { ws, text in
                    Task {
                        await roomManager.broadcast(to: "general", message: text)
                    }
                }
                
                ws.onClose.whenComplete { _ in
                    Task {
                        await roomManager.leave(room: "general", socket: ws)
                    }
                }
            }
        }
        
        print("💬 Swift Chat running on http://localhost:4001")
        try app.run()
    }
}
