# Chat Application - Swift Edition

Real-time chat using Swift Actors and WebSockets.

## Features

- **Swift Actors**: Thread-safe state management
- **Structured Concurrency**: async/await patterns
- **WebSockets**: Real-time bidirectional communication
- **Type Safety**: Compile-time guarantees
- **Modern Swift**: Latest language features

## Build & Run

```bash
swift build
swift run
```

Server: `http://localhost:4001`

## WebSocket Usage

```javascript
const ws = new WebSocket('ws://localhost:4001/ws');
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'join',
    room: 'general',
    user: 'alice'
  }));
};
```

## Architecture

- **Actors**: Isolated mutable state
- **Tasks**: Structured concurrency
- **Async/Await**: Modern async patterns
- **Value Semantics**: Copy-on-write

## License

MIT
