import Foundation

/// Parameters for chat completion requests.
public struct ChatRequest: Codable, Sendable {
    /// The model to use for chat
    public let model: String
    /// The messages in the conversation
    public let messages: [ChatMessage]
    /// Available tools for the model to use
    public let tools: [ToolDefinition]?
    /// The format to return the response in
    public let format: ResponseFormat?
    /// Additional model parameters
    public let options: ModelOptions?
    /// Whether to stream the response
    public let stream: Bool?
    /// How long to keep model loaded in memory
    public let keepAlive: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case model, messages, tools, format, options, stream
        case keepAlive = "keep_alive"
    }

    public init(
        model: String,
        messages: [ChatMessage],
        tools: [ToolDefinition]? = nil,
        format: ResponseFormat? = nil,
        options: ModelOptions? = nil,
        stream: Bool? = nil,
        keepAlive: TimeInterval? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.format = format
        self.options = options
        self.stream = stream
        self.keepAlive = keepAlive
    }
}

/// A message in a chat conversation
public struct ChatMessage: Codable, Sendable {
    /// The role of the message sender
    public let role: MessageRole
    /// The content of the message
    public let content: String
    /// Optional images for multimodal models
    /// Each string should be a base64-encoded image
    public let images: [String]?
    /// Tool calls made by the assistant
    public let toolCalls: [ToolCall]?

    private enum CodingKeys: String, CodingKey {
        case role, content, images
        case toolCalls = "tool_calls"
    }

    public init(
        role: MessageRole,
        content: String,
        images: [String]? = nil,
        toolCalls: [ToolCall]? = nil
    ) {
        self.role = role
        self.content = content
        self.images = images
        self.toolCalls = toolCalls
    }
}

/// Available message roles
public enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}
