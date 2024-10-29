#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

extension OllamaClient {
    /// Generates text from a prompt
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     guard let model = OllamaModelName.parse("llama2") else {
    ///         throw CLIError.invalidArgument("Invalid model name format")
    ///     }
    ///
    ///     // Basic usage with default options
    ///     let stream = try await client.generateText(
    ///         prompt: "Tell me a story",
    ///         model: model
    ///     )
    ///
    ///     // Advanced usage with custom options
    ///     let options = GenerationOptions(
    ///         modelOptions: ModelOptions(temperature: 0.7),
    ///         systemPrompt: "You are a creative storyteller",
    ///         keepAlive: 300
    ///     )
    ///     let customStream = try await client.generateText(
    ///         prompt: "Tell me a story",
    ///         model: model,
    ///         options: options
    ///     )
    ///
    ///     // Process the streaming responses
    ///     for try await response in customStream {
    ///         if !response.response.isEmpty {
    ///             print(response.response, terminator: "")
    ///         }
    ///     }
    /// } catch {
    ///     print("Error generating text: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: The prompt to generate from
    ///   - model: The model to use
    ///   - options: Additional generation options
    /// - Returns: An async sequence of generation responses
    public func generateText(
        prompt: String,
        model: OllamaModelName,
        options: GenerationOptions = .default
    ) async throws -> AsyncThrowingStream<GenerateResponse, Error> {
        let request = GenerateRequest(
            model: model.fullName,
            prompt: prompt,
            suffix: options.suffix,
            images: options.images,
            format: options.format,
            options: options.modelOptions,
            system: options.systemPrompt,
            template: options.template,
            context: options.context,
            stream: true,
            raw: options.raw,
            keepAlive: options.keepAlive ?? configuration.defaultKeepAlive
        )

        return streamRequest(
            endpoint: "generate",
            method: "POST",
            body: try encode(request),
            as: GenerateResponse.self
        )
    }

    /// Generates chat completions
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     guard let model = OllamaModelName.parse("llama2") else {
    ///         throw CLIError.invalidArgument("Invalid model name format")
    ///     }
    ///
    ///     // Create conversation messages
    ///     var messages: [ChatMessage] = [
    ///         ChatMessage(role: .system, content: "You are a helpful assistant"),
    ///         ChatMessage(role: .user, content: "Hello! Can you help me?")
    ///     ]
    ///
    ///     // Advanced usage with custom options
    ///     let options = ChatOptions(
    ///         modelOptions: ModelOptions(temperature: 0.7),
    ///         keepAlive: 300
    ///     )
    ///
    ///     // Start chat stream
    ///     let responses = try await client.chat(
    ///         messages: messages,
    ///         model: model,
    ///         options: options
    ///     )
    ///
    ///     // Process the streaming responses
    ///     var fullResponse = ""
    ///     for try await response in responses {
    ///         if !response.message.content.isEmpty {
    ///             print(response.message.content, terminator: "")
    ///             fullResponse += response.message.content
    ///         }
    ///
    ///         if response.done {
    ///             messages.append(ChatMessage(role: .assistant, content: fullResponse))
    ///         }
    ///     }
    /// } catch {
    ///     print("Error in chat: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - model: The model to use
    ///   - options: Additional chat options
    /// - Returns: An async sequence of chat responses
    public func chat(
        messages: [ChatMessage],
        model: OllamaModelName,
        options: ChatOptions = .default
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let request = ChatRequest(
            model: model.fullName,
            messages: messages,
            tools: options.tools,
            format: options.format,
            options: options.modelOptions,
            stream: true,
            keepAlive: options.keepAlive ?? configuration.defaultKeepAlive
        )

        return streamRequest(
            endpoint: "chat",
            method: "POST",
            body: try encode(request),
            as: ChatResponse.self
        )
    }

    /// Generates embeddings for text
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     guard let model = OllamaModelName.parse("llama2") else {
    ///         throw CLIError.invalidArgument("Invalid model name format")
    ///     }
    ///
    ///     // Generate embeddings for a single text
    ///     let response = try await client.generateEmbeddings(
    ///         input: .single("What is machine learning?"),
    ///         model: model
    ///     )
    ///     print("Embeddings: \(response.embeddings)")
    ///
    ///     // Generate embeddings for multiple texts
    ///     let batchResponse = try await client.generateEmbeddings(
    ///         input: .multiple([
    ///             "What is machine learning?",
    ///             "How do neural networks work?"
    ///         ]),
    ///         model: model,
    ///         options: EmbeddingOptions(truncate: true)
    ///     )
    ///     print("Batch embeddings: \(batchResponse.embeddings)")
    /// } catch {
    ///     print("Error generating embeddings: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: Text to generate embeddings for
    ///   - model: The model to use
    ///   - options: Additional embedding options
    /// - Returns: The generated embeddings
    public func generateEmbeddings(
        input: EmbeddingInput,
        model: OllamaModelName,
        options: EmbeddingOptions = .default
    ) async throws -> EmbeddingResponse {
        let request = EmbeddingRequest(
            model: model.fullName,
            input: input,
            truncate: options.truncate,
            options: options.modelOptions,
            keepAlive: options.keepAlive ?? configuration.defaultKeepAlive
        )

        let data = try await makeRequest(
            endpoint: "embeddings",
            method: "POST",
            body: try encode(request)
        )

        return try decode(data, as: EmbeddingResponse.self)
    }
}
