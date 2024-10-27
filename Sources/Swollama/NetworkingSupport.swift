//
//  NetworkingSupport.swift
//  Swollama
//
//  Created by Marcus Ziadé on 10/27/24.
//


#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

/// Platform abstraction for networking functionality
struct NetworkingSupport {
    /// Creates a URLSession with the given configuration
    static func createSession(configuration: URLSessionConfiguration) -> URLSession {
        return URLSession(configuration: configuration)
    }
    
    /// Creates a default URLSessionConfiguration
    static func createDefaultConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        #if !os(Linux)
        // These properties are only available on Apple platforms
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        #endif
        return config
    }
    
    /// Platform-agnostic data task implementation
    static func dataTask(
        session: URLSession,
        for request: URLRequest
    ) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        // Linux implementation
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
        #else
        // Native async/await on Apple platforms
        return try await session.data(for: request)
        #endif
    }
    
    /// Platform-agnostic bytes task implementation
    static func bytesTask(
        session: URLSession,
        for request: URLRequest
    ) async throws -> (AsyncBytes, URLResponse) {
        let (data, response) = try await dataTask(session: session, for: request)
        return (AsyncBytes(data), response)
    }
}

/// Cross-platform AsyncBytes implementation
struct AsyncBytes: AsyncSequence {
    typealias Element = UInt8
    
    let data: Data
    
    init(_ data: Data) {
        self.data = data
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(data: data)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        private let data: Data
        private var index: Data.Index
        
        init(data: Data) {
            self.data = data
            self.index = data.startIndex
        }
        
        mutating func next() async throws -> UInt8? {
            guard index < data.endIndex else { return nil }
            let byte = data[index]
            index = data.index(after: index)
            return byte
        }
    }
}
