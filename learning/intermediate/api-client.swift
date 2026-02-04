// API Client - REST API client with authentication and error handling
//
// Run: swift api-client.swift

import Foundation

struct Response {
    let status: Int
    let body: String
    let success: Bool
}

class APIClient {
    let baseURL: String
    private var headers: [String: String] = [:]
    var maxRetries = 3
    var retryDelay: TimeInterval = 1.0
    
    init(baseURL: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    func setAuthToken(_ token: String) {
        headers["Authorization"] = "Bearer \(token)"
    }
    
    func setAPIKey(_ key: String, header: String = "X-API-Key") {
        headers[header] = key
    }
    
    func setHeader(_ name: String, value: String) {
        headers[name] = value
    }
    
    private func request(_ method: String, _ endpoint: String, data: String? = nil) -> Response {
        let url = "\(baseURL)/\(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        print("  → \(method) \(url)")
        
        // Simulate response
        let body: String
        if url.contains("/users/") {
            body = #"{"id":1,"name":"Leanne Graham","email":"sincere@april.biz"}"#
        } else if url.contains("/posts") && method == "GET" {
            body = #"[{"id":1,"title":"Sample Post"}]"#
        } else if method == "POST" {
            body = #"{"id":101,"title":"Created"}"#
        } else if method == "PUT" {
            body = #"{"id":1,"title":"Updated"}"#
        } else if method == "DELETE" {
            body = "{}"
        } else {
            body = #"{"error":"Not found"}"#
        }
        
        return Response(status: 200, body: body, success: true)
    }
    
    func get(_ endpoint: String) -> Response {
        return request("GET", endpoint)
    }
    
    func post(_ endpoint: String, data: String) -> Response {
        return request("POST", endpoint, data: data)
    }
    
    func put(_ endpoint: String, data: String) -> Response {
        return request("PUT", endpoint, data: data)
    }
    
    func delete(_ endpoint: String) -> Response {
        return request("DELETE", endpoint)
    }
}

// Main program
print("=== API Client Demo ===")
print("Note: Using simulated responses\n")

let client = APIClient(baseURL: "https://jsonplaceholder.typicode.com")

// GET request
print("1. GET request:")
let resp1 = client.get("/users/1")
print("   Status: \(resp1.status)\n")

// POST request
print("2. POST request:")
let resp2 = client.post("/posts", data: #"{"title":"Test"}"#)
print("   Status: \(resp2.status)\n")

// PUT request
print("3. PUT request:")
let resp3 = client.put("/posts/1", data: #"{"title":"Updated"}"#)
print("   Status: \(resp3.status)\n")

// DELETE request
print("4. DELETE request:")
let resp4 = client.delete("/posts/1")
print("   Status: \(resp4.status)\n")

// With authentication
print("5. With authentication:")
client.setAuthToken("token123")
print("   ✓ Headers configured")

print("\n✓ API client demo complete")
