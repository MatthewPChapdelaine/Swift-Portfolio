#!/usr/bin/env swift

import Foundation

// MARK: - WebSocket Frame Types

/// WebSocket frame opcode types
enum WebSocketOpcode: UInt8 {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
    
    var isControl: Bool {
        return rawValue >= 0x8
    }
}

/// WebSocket close status codes
enum WebSocketCloseCode: UInt16 {
    case normal = 1000
    case goingAway = 1001
    case protocolError = 1002
    case unsupportedData = 1003
    case noStatusReceived = 1005
    case abnormalClosure = 1006
    case invalidFramePayloadData = 1007
    case policyViolation = 1008
    case messageTooBig = 1009
    case mandatoryExtension = 1010
    case internalServerError = 1011
}

// MARK: - WebSocket Frame

/// Represents a WebSocket frame according to RFC 6455
struct WebSocketFrame {
    let fin: Bool
    let rsv1: Bool
    let rsv2: Bool
    let rsv3: Bool
    let opcode: WebSocketOpcode
    let masked: Bool
    let payloadLength: UInt64
    let maskingKey: [UInt8]?
    let payload: Data
    
    /// Create a text frame
    static func text(_ message: String, masked: Bool = true) -> WebSocketFrame {
        let payload = message.data(using: .utf8) ?? Data()
        return WebSocketFrame(
            fin: true,
            rsv1: false, rsv2: false, rsv3: false,
            opcode: .text,
            masked: masked,
            payloadLength: UInt64(payload.count),
            maskingKey: masked ? generateMaskingKey() : nil,
            payload: payload
        )
    }
    
    /// Create a binary frame
    static func binary(_ data: Data, masked: Bool = true) -> WebSocketFrame {
        return WebSocketFrame(
            fin: true,
            rsv1: false, rsv2: false, rsv3: false,
            opcode: .binary,
            masked: masked,
            payloadLength: UInt64(data.count),
            maskingKey: masked ? generateMaskingKey() : nil,
            payload: data
        )
    }
    
    /// Create a close frame
    static func close(code: WebSocketCloseCode, reason: String = "", masked: Bool = true) -> WebSocketFrame {
        var payload = Data()
        payload.append(contentsOf: [UInt8(code.rawValue >> 8), UInt8(code.rawValue & 0xFF)])
        if let reasonData = reason.data(using: .utf8) {
            payload.append(reasonData)
        }
        
        return WebSocketFrame(
            fin: true,
            rsv1: false, rsv2: false, rsv3: false,
            opcode: .close,
            masked: masked,
            payloadLength: UInt64(payload.count),
            maskingKey: masked ? generateMaskingKey() : nil,
            payload: payload
        )
    }
    
    /// Create a ping frame
    static func ping(payload: Data = Data(), masked: Bool = true) -> WebSocketFrame {
        return WebSocketFrame(
            fin: true,
            rsv1: false, rsv2: false, rsv3: false,
            opcode: .ping,
            masked: masked,
            payloadLength: UInt64(payload.count),
            maskingKey: masked ? generateMaskingKey() : nil,
            payload: payload
        )
    }
    
    /// Create a pong frame
    static func pong(payload: Data = Data(), masked: Bool = true) -> WebSocketFrame {
        return WebSocketFrame(
            fin: true,
            rsv1: false, rsv2: false, rsv3: false,
            opcode: .pong,
            masked: masked,
            payloadLength: UInt64(payload.count),
            maskingKey: masked ? generateMaskingKey() : nil,
            payload: payload
        )
    }
    
    private static func generateMaskingKey() -> [UInt8] {
        return (0..<4).map { _ in UInt8.random(in: 0...255) }
    }
}

// MARK: - WebSocket Frame Parser

/// Parses WebSocket frames from raw data
struct WebSocketFrameParser {
    
    /// Parse a frame from data
    static func parse(from data: Data) throws -> (frame: WebSocketFrame, bytesConsumed: Int) {
        guard data.count >= 2 else {
            throw WebSocketError.invalidFrame("Frame too short")
        }
        
        var index = 0
        
        // First byte: FIN, RSV, Opcode
        let byte0 = data[index]
        index += 1
        
        let fin = (byte0 & 0x80) != 0
        let rsv1 = (byte0 & 0x40) != 0
        let rsv2 = (byte0 & 0x20) != 0
        let rsv3 = (byte0 & 0x10) != 0
        let opcodeValue = byte0 & 0x0F
        
        guard let opcode = WebSocketOpcode(rawValue: opcodeValue) else {
            throw WebSocketError.invalidFrame("Unknown opcode: \(opcodeValue)")
        }
        
        // Second byte: Mask, Payload length
        let byte1 = data[index]
        index += 1
        
        let masked = (byte1 & 0x80) != 0
        var payloadLength = UInt64(byte1 & 0x7F)
        
        // Extended payload length
        if payloadLength == 126 {
            guard data.count >= index + 2 else {
                throw WebSocketError.invalidFrame("Incomplete extended payload length")
            }
            payloadLength = UInt64(data[index]) << 8 | UInt64(data[index + 1])
            index += 2
        } else if payloadLength == 127 {
            guard data.count >= index + 8 else {
                throw WebSocketError.invalidFrame("Incomplete extended payload length")
            }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = (payloadLength << 8) | UInt64(data[index + i])
            }
            index += 8
        }
        
        // Masking key
        var maskingKey: [UInt8]?
        if masked {
            guard data.count >= index + 4 else {
                throw WebSocketError.invalidFrame("Incomplete masking key")
            }
            maskingKey = Array(data[index..<index + 4])
            index += 4
        }
        
        // Payload
        guard data.count >= index + Int(payloadLength) else {
            throw WebSocketError.invalidFrame("Incomplete payload")
        }
        
        var payload = data[index..<index + Int(payloadLength)]
        
        // Unmask if needed
        if let key = maskingKey {
            var unmasked = Data(count: payload.count)
            for (i, byte) in payload.enumerated() {
                unmasked[i] = byte ^ key[i % 4]
            }
            payload = unmasked
        }
        
        index += Int(payloadLength)
        
        let frame = WebSocketFrame(
            fin: fin,
            rsv1: rsv1, rsv2: rsv2, rsv3: rsv3,
            opcode: opcode,
            masked: masked,
            payloadLength: payloadLength,
            maskingKey: maskingKey,
            payload: Data(payload)
        )
        
        return (frame, index)
    }
    
    /// Serialize a frame to data
    static func serialize(_ frame: WebSocketFrame) -> Data {
        var data = Data()
        
        // First byte: FIN, RSV, Opcode
        var byte0: UInt8 = frame.opcode.rawValue
        if frame.fin { byte0 |= 0x80 }
        if frame.rsv1 { byte0 |= 0x40 }
        if frame.rsv2 { byte0 |= 0x20 }
        if frame.rsv3 { byte0 |= 0x10 }
        data.append(byte0)
        
        // Second byte: Mask, Payload length
        var byte1: UInt8 = 0
        if frame.masked { byte1 |= 0x80 }
        
        let length = frame.payloadLength
        if length < 126 {
            byte1 |= UInt8(length)
            data.append(byte1)
        } else if length <= UInt16.max {
            byte1 |= 126
            data.append(byte1)
            data.append(UInt8(length >> 8))
            data.append(UInt8(length & 0xFF))
        } else {
            byte1 |= 127
            data.append(byte1)
            for i in stride(from: 56, through: 0, by: -8) {
                data.append(UInt8((length >> i) & 0xFF))
            }
        }
        
        // Masking key
        if let key = frame.maskingKey {
            data.append(contentsOf: key)
        }
        
        // Payload (masked if needed)
        if let key = frame.maskingKey {
            for (i, byte) in frame.payload.enumerated() {
                data.append(byte ^ key[i % 4])
            }
        } else {
            data.append(frame.payload)
        }
        
        return data
    }
}

// MARK: - WebSocket Message

/// High-level message type
enum WebSocketMessage {
    case text(String)
    case binary(Data)
    case ping(Data)
    case pong(Data)
    case close(code: WebSocketCloseCode, reason: String)
}

// MARK: - WebSocket Connection State

enum WebSocketState {
    case connecting
    case open
    case closing
    case closed
}

// MARK: - WebSocket Connection

/// WebSocket connection handling
actor WebSocketConnection {
    private var state: WebSocketState = .closed
    private var fragmentedMessage: Data?
    private var fragmentedOpcode: WebSocketOpcode?
    
    var onMessage: ((WebSocketMessage) async -> Void)?
    var onError: ((Error) async -> Void)?
    
    // Statistics
    private(set) var messagesSent = 0
    private(set) var messagesReceived = 0
    private(set) var bytesSent = 0
    private(set) var bytesReceived = 0
    
    init() {
        self.state = .connecting
    }
    
    /// Perform WebSocket handshake
    func performHandshake(request: URLRequest) async throws -> URLResponse {
        // In a real implementation, this would:
        // 1. Generate Sec-WebSocket-Key
        // 2. Send HTTP upgrade request
        // 3. Validate Sec-WebSocket-Accept response
        // 4. Transition to open state
        
        state = .open
        
        // Simulate handshake response
        let url = request.url!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 101,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Accept": "simulated-accept-key"
            ]
        )!
        
        return response
    }
    
    /// Send a message
    func send(message: WebSocketMessage) throws -> Data {
        guard state == .open else {
            throw WebSocketError.notConnected
        }
        
        let frame: WebSocketFrame
        
        switch message {
        case .text(let string):
            frame = .text(string, masked: true)
        case .binary(let data):
            frame = .binary(data, masked: true)
        case .ping(let data):
            frame = .ping(payload: data, masked: true)
        case .pong(let data):
            frame = .pong(payload: data, masked: true)
        case .close(let code, let reason):
            frame = .close(code: code, reason: reason, masked: true)
            state = .closing
        }
        
        let data = WebSocketFrameParser.serialize(frame)
        messagesSent += 1
        bytesSent += data.count
        
        return data
    }
    
    /// Receive and process data
    func receive(data: Data) async throws {
        bytesReceived += data.count
        
        var offset = 0
        while offset < data.count {
            let remaining = data.subdata(in: offset..<data.count)
            let (frame, bytesConsumed) = try WebSocketFrameParser.parse(from: remaining)
            offset += bytesConsumed
            
            try await processFrame(frame)
        }
    }
    
    private func processFrame(_ frame: WebSocketFrame) async throws {
        // Handle control frames
        if frame.opcode.isControl {
            guard frame.fin else {
                throw WebSocketError.invalidFrame("Control frames must not be fragmented")
            }
            
            switch frame.opcode {
            case .close:
                state = .closing
                let code = extractCloseCode(from: frame.payload)
                let reason = extractCloseReason(from: frame.payload)
                await onMessage?(.close(code: code, reason: reason))
                state = .closed
                
            case .ping:
                await onMessage?(.ping(frame.payload))
                // In a real implementation, automatically send pong
                
            case .pong:
                await onMessage?(.pong(frame.payload))
                
            default:
                break
            }
            
            return
        }
        
        // Handle data frames
        if frame.opcode != .continuation {
            // Start of new message
            fragmentedOpcode = frame.opcode
            fragmentedMessage = frame.payload
        } else {
            // Continuation frame
            guard fragmentedMessage != nil else {
                throw WebSocketError.invalidFrame("Continuation frame without start")
            }
            fragmentedMessage?.append(frame.payload)
        }
        
        // If this is the final frame, dispatch message
        if frame.fin {
            guard let opcode = fragmentedOpcode, let payload = fragmentedMessage else {
                throw WebSocketError.invalidFrame("Invalid fragmented message")
            }
            
            messagesReceived += 1
            
            switch opcode {
            case .text:
                if let string = String(data: payload, encoding: .utf8) {
                    await onMessage?(.text(string))
                } else {
                    throw WebSocketError.invalidFrame("Invalid UTF-8 in text frame")
                }
                
            case .binary:
                await onMessage?(.binary(payload))
                
            default:
                break
            }
            
            // Reset fragmentation state
            fragmentedMessage = nil
            fragmentedOpcode = nil
        }
    }
    
    /// Close the connection
    func close(code: WebSocketCloseCode = .normal, reason: String = "") async throws {
        guard state == .open else { return }
        
        let closeMessage = WebSocketMessage.close(code: code, reason: reason)
        _ = try send(message: closeMessage)
        
        // Wait a bit for close frame to be sent
        try? await Task.sleep(for: .milliseconds(100))
        
        state = .closed
    }
    
    func getState() -> WebSocketState {
        return state
    }
    
    func getStatistics() -> (sent: Int, received: Int, bytesSent: Int, bytesReceived: Int) {
        return (messagesSent, messagesReceived, bytesSent, bytesReceived)
    }
    
    private func extractCloseCode(from payload: Data) -> WebSocketCloseCode {
        guard payload.count >= 2 else {
            return .noStatusReceived
        }
        let code = UInt16(payload[0]) << 8 | UInt16(payload[1])
        return WebSocketCloseCode(rawValue: code) ?? .abnormalClosure
    }
    
    private func extractCloseReason(from payload: Data) -> String {
        guard payload.count > 2 else {
            return ""
        }
        let reasonData = payload.subdata(in: 2..<payload.count)
        return String(data: reasonData, encoding: .utf8) ?? ""
    }
}

// MARK: - WebSocket Client

/// High-level WebSocket client
actor WebSocketClient {
    private let url: URL
    private var connection: WebSocketConnection?
    private var receiveTask: Task<Void, Never>?
    
    init(url: URL) {
        self.url = url
    }
    
    /// Connect to the WebSocket server
    func connect() async throws {
        let connection = WebSocketConnection()
        self.connection = connection
        
        var request = URLRequest(url: url)
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        
        let response = try await connection.performHandshake(request: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 101 else {
            throw WebSocketError.handshakeFailed
        }
        
        print("✓ WebSocket connected to \(url)")
    }
    
    /// Send a text message
    func send(text: String) async throws {
        guard let connection = connection else {
            throw WebSocketError.notConnected
        }
        
        let message = WebSocketMessage.text(text)
        let data = try await connection.send(message: message)
        print("→ Sent text message: \"\(text)\" (\(data.count) bytes)")
    }
    
    /// Send binary data
    func send(data: Data) async throws {
        guard let connection = connection else {
            throw WebSocketError.notConnected
        }
        
        let message = WebSocketMessage.binary(data)
        let frameData = try await connection.send(message: message)
        print("→ Sent binary message: \(data.count) bytes (\(frameData.count) bytes framed)")
    }
    
    /// Set message handler
    func onMessage(_ handler: @escaping (WebSocketMessage) async -> Void) async {
        await connection?.onMessage = handler
    }
    
    /// Disconnect
    func disconnect() async throws {
        try await connection?.close()
        receiveTask?.cancel()
        receiveTask = nil
        connection = nil
        print("✓ WebSocket disconnected")
    }
    
    /// Get connection statistics
    func getStatistics() async -> (sent: Int, received: Int, bytesSent: Int, bytesReceived: Int)? {
        return await connection?.getStatistics()
    }
}

// MARK: - Errors

enum WebSocketError: Error, CustomStringConvertible {
    case notConnected
    case handshakeFailed
    case invalidFrame(String)
    case connectionClosed
    
    var description: String {
        switch self {
        case .notConnected:
            return "WebSocket not connected"
        case .handshakeFailed:
            return "WebSocket handshake failed"
        case .invalidFrame(let msg):
            return "Invalid frame: \(msg)"
        case .connectionClosed:
            return "WebSocket connection closed"
        }
    }
}

// MARK: - Main Demo

@main
struct ProtocolImplementation {
    static func main() async {
        print("=== WebSocket Protocol Implementation ===\n")
        
        // Demo 1: Frame parsing and serialization
        print("1. Frame Parsing & Serialization Demo\n")
        
        let textFrame = WebSocketFrame.text("Hello, WebSocket!", masked: true)
        let serialized = WebSocketFrameParser.serialize(textFrame)
        print("Serialized text frame: \(serialized.count) bytes")
        print("Frame details:")
        print("  - FIN: \(textFrame.fin)")
        print("  - Opcode: \(textFrame.opcode)")
        print("  - Masked: \(textFrame.masked)")
        print("  - Payload length: \(textFrame.payloadLength)")
        
        do {
            let (parsed, _) = try WebSocketFrameParser.parse(from: serialized)
            if let message = String(data: parsed.payload, encoding: .utf8) {
                print("  - Parsed message: \"\(message)\"")
            }
        } catch {
            print("Parse error: \(error)")
        }
        
        // Demo 2: WebSocket client simulation
        print("\n2. WebSocket Client Demo\n")
        
        let client = WebSocketClient(url: URL(string: "ws://example.com/socket")!)
        
        do {
            // Connect
            try await client.connect()
            
            // Set up message handler
            await client.onMessage { message in
                switch message {
                case .text(let text):
                    print("← Received text: \"\(text)\"")
                case .binary(let data):
                    print("← Received binary: \(data.count) bytes")
                case .ping(let data):
                    print("← Received ping: \(data.count) bytes")
                case .pong(let data):
                    print("← Received pong: \(data.count) bytes")
                case .close(let code, let reason):
                    print("← Received close: \(code) - \(reason)")
                }
            }
            
            // Send messages
            try await client.send(text: "Hello, Server!")
            try await client.send(text: "How are you?")
            
            let binaryData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
            try await client.send(data: binaryData)
            
            // Simulate receiving messages
            print("\n(Simulating server responses...)")
            if let connection = await client.connection {
                let responseFrame = WebSocketFrame.text("Hello, Client!", masked: false)
                let responseData = WebSocketFrameParser.serialize(responseFrame)
                try await connection.receive(data: responseData)
            }
            
            // Get statistics
            if let stats = await client.getStatistics() {
                print("\nConnection Statistics:")
                print("  - Messages sent: \(stats.sent)")
                print("  - Messages received: \(stats.received)")
                print("  - Bytes sent: \(stats.bytesSent)")
                print("  - Bytes received: \(stats.bytesReceived)")
            }
            
            // Disconnect
            try await client.disconnect()
            
        } catch {
            print("Error: \(error)")
        }
        
        // Demo 3: Control frames
        print("\n3. Control Frames Demo\n")
        
        let pingFrame = WebSocketFrame.ping(payload: Data([0x01, 0x02]), masked: true)
        let pingData = WebSocketFrameParser.serialize(pingFrame)
        print("Ping frame: \(pingData.count) bytes")
        
        let closeFrame = WebSocketFrame.close(code: .normal, reason: "Goodbye", masked: true)
        let closeData = WebSocketFrameParser.serialize(closeFrame)
        print("Close frame: \(closeData.count) bytes")
        
        print("\n=== Demo Completed ===")
        print("\nKey Features Demonstrated:")
        print("  ✓ WebSocket frame parsing (RFC 6455)")
        print("  ✓ Frame serialization with masking")
        print("  ✓ Fragmentation handling")
        print("  ✓ Control frames (ping, pong, close)")
        print("  ✓ Text and binary message support")
        print("  ✓ WebSocket handshake simulation")
        print("  ✓ Actor-based connection management")
        print("  ✓ Async/await message handling")
        print("  ✓ Connection statistics tracking")
    }
}
