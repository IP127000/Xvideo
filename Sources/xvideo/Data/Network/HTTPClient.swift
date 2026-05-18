import Foundation

protocol HTTPClient: Sendable {
    func get<T: Decodable>(_ url: URL, headers: [String: String]) async throws -> T
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession
    private let decoder = JSONDecoder()

    func get<T: Decodable>(_ url: URL, headers: [String: String]) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 35
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse
        }

        return try decoder.decode(T.self, from: data)
    }
}
