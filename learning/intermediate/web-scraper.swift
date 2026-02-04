// Web Scraper - Make HTTP requests and parse HTML/JSON responses
//
// Run: swift web-scraper.swift

import Foundation

struct Response {
    let status: Int
    let body: String
}

class WebScraper {
    func get(_ urlString: String) -> Response {
        print("  → Making request to \(urlString)")
        return simulateResponse(urlString)
    }
    
    private func simulateResponse(_ url: String) -> Response {
        let body: String
        if url.contains("jsonplaceholder") && url.contains("/users/") {
            body = #"{"id":1,"name":"Leanne Graham","email":"sincere@april.biz"}"#
        } else if url.contains("jsonplaceholder") && url.contains("/posts") {
            body = #"[{"id":1,"title":"Sample Post","userId":1}]"#
        } else if url.contains("example.com") {
            body = "<html><head><title>Example Domain</title></head><body><h1>Example</h1></body></html>"
        } else {
            body = "<html><body>Not found</body></html>"
        }
        return Response(status: 200, body: body)
    }
    
    func extractTitle(_ html: String) -> String? {
        let pattern = "<title[^>]*>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else {
            return nil
        }
        guard let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[titleRange])
    }
    
    func extractLinks(_ html: String) -> [(url: String, text: String)] {
        let pattern = #"<a\s+[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        return matches.compactMap { match in
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                return nil
            }
            return (String(html[urlRange]), String(html[textRange]).trimmingCharacters(in: .whitespaces))
        }
    }
}

// Main program
print("=== Web Scraper Demo ===")
print("Note: Using simulated responses\n")

let scraper = WebScraper()

// Example 1: Fetch JSON
print("1. Fetching JSON from API:")
let resp1 = scraper.get("https://jsonplaceholder.typicode.com/users/1")
print("   Status: \(resp1.status)")
let preview = String(resp1.body.prefix(50))
print("   Body: \(preview)...\n")

// Example 2: Fetch HTML
print("2. Fetching HTML page:")
let resp2 = scraper.get("https://example.com")
if let title = scraper.extractTitle(resp2.body) {
    print("   Title: \(title)")
}

let links = scraper.extractLinks(resp2.body)
print("   Found \(links.count) links")

print("\n✓ Scraping demo complete")
