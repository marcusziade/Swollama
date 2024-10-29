#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

/// A client for interacting with the Ollama API
public actor OllamaClient: OllamaProtocol {
    public let baseURL: URL
    public let configuration: OllamaConfiguration

    private let session: URLSession
    let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL = URL(string: "http://localhost:11434")!, configuration: OllamaConfiguration = .default) {
        self.baseURL = baseURL
        self.configuration = configuration

        let config = NetworkingSupport.createDefaultConfiguration()
        config.timeoutIntervalForRequest = configuration.timeoutInterval

        self.session = NetworkingSupport.createSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    /// Makes a request to the Ollama API with retry support
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: HTTP method
    ///   - body: Optional request body
    /// - Returns: Data from the response
    /// - Throws: OllamaError if the request fails
    func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let url = baseURL.appendingPathComponent("/api").appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        var lastError: Error?
        for attempt in 0...configuration.maxRetries {
            do {
                let (data, response) = try await NetworkingSupport.dataTask(session: session, for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OllamaError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 404:
                    throw OllamaError.modelNotFound
                case 400:
                    if let errorMessage = String(data: data, encoding: .utf8) {
                        throw OllamaError.invalidParameters(errorMessage)
                    }
                    throw OllamaError.invalidParameters("Unknown error")
                case 500...599:
                    if let errorMessage = String(data: data, encoding: .utf8) {
                        throw OllamaError.serverError(errorMessage)
                    }
                    throw OllamaError.serverError("Unknown server error")
                default:
                    throw OllamaError.unexpectedStatusCode(httpResponse.statusCode)
                }
            } catch {
                lastError = error
                if attempt < configuration.maxRetries {
                    try await Task.sleep(for: .seconds(configuration.retryDelay))
                    continue
                }
                throw OllamaError.networkError(error)
            }
        }

        throw OllamaError.networkError(lastError ?? URLError(.unknown))
    }

    /// Creates an async sequence from a streaming response
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: HTTP method
    ///   - body: Request body
    ///   - type: The type to decode responses as
    /// - Returns: An async sequence of decoded responses
    func streamRequest<T: Decodable>(
        endpoint: String,
        method: String = "POST",
        body: Data?,
        as type: T.Type
    ) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent("/api").appendingPathComponent(endpoint)
                    var request = URLRequest(url: url)
                    request.httpMethod = method
                    request.httpBody = body
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let (bytes, response) = try await NetworkingSupport.bytesTask(session: session, for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OllamaError.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw OllamaError.unexpectedStatusCode(httpResponse.statusCode)
                    }

                    var buffer = Data()

                    for try await byte in bytes {
                        buffer.append(byte)

                        if byte == UInt8(ascii: "\n") {
                            if let decoded = try? decoder.decode(T.self, from: buffer) {
                                continuation.yield(decoded)
                            }
                            buffer.removeAll()
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Encodes a request body
    /// - Parameter value: The value to encode
    /// - Returns: Encoded data
    /// - Throws: OllamaError if encoding fails
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw OllamaError.invalidParameters("Failed to encode request: \(error.localizedDescription)")
        }
    }

    /// Decodes a response body
    /// - Parameters:
    ///   - data: The data to decode
    ///   - type: The type to decode as
    /// - Returns: Decoded value
    /// - Throws: OllamaError if decoding fails
    public func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw OllamaError.decodingError(error)
        }
    }
}
