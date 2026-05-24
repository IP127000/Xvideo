import Foundation

protocol HTTPClient: Sendable {
    func data(from url: URL, headers: [String: String]) async throws -> Data
    func get<T: Decodable>(_ url: URL, headers: [String: String]) async throws -> T
}

extension HTTPClient {
    func get<T: Decodable>(_ url: URL, headers: [String: String]) async throws -> T {
        let data = try await data(from: url, headers: headers)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    func data(from url: URL, headers: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse
        }

        return data
    }
}
