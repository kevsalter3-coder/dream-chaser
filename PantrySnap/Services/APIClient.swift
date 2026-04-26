import Foundation
import OSLog

private let logger = Logger(subsystem: "com.pantrysnap", category: "APIClient")

enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(underlying: Error)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                   return "Invalid URL."
        case .httpError(let code, _):       return "HTTP error \(code)."
        case .decodingFailed(let e):        return "Decoding failed: \(e.localizedDescription)"
        case .networkError(let e):          return "Network error: \(e.localizedDescription)"
        }
    }
}

struct APIClient {
    private let session: URLSession

    init(session: URLSession = .init(configuration: .default)) {
        self.session = session
    }

    func get<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        decoder: JSONDecoder = .init()
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await perform(request: request, decoder: decoder)
    }

    func post<Body: Encodable, Response: Decodable>(
        url: URL,
        body: Body,
        headers: [String: String] = [:],
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }

        return try await perform(request: request, decoder: decoder)
    }

    private func perform<T: Decodable>(request: URLRequest, decoder: JSONDecoder) async throws -> T {
        logger.debug("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            logger.error("HTTP \(http.statusCode) from \(request.url?.absoluteString ?? "")")
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }
}
