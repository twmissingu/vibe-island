import Foundation

public final class NetworkClient: Sendable {
    private let session: URLSession
    private let timeout: TimeInterval = 15

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
    }

    public func request(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let requestURL = URL(string: url) else {
            throw QuotaError.networkError("Invalid URL: \(url)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuotaError.networkError("No HTTP response")
            }
            return (data, httpResponse)
        } catch let error as QuotaError {
            throw error
        } catch {
            throw QuotaError.networkError(error.localizedDescription)
        }
    }

    public func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw QuotaError.unknown("JSON decode error: \(error.localizedDescription)")
        }
    }

    public func errorFromResponse(statusCode: Int, data: Data) -> QuotaError {
        switch statusCode {
        case 401, 403: return .invalidKey
        case 429:
            let retry = parseRetryAfter(from: data)
            return .rateLimited(retryAfter: retry)
        default:
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
            return .networkError(message)
        }
    }

    private func parseRetryAfter(from data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["retry_after"] as? Int ?? json["Retry-After"] as? Int
    }

    public static func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))***\(key.suffix(4))"
    }
}
