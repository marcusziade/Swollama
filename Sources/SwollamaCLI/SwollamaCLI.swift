#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation
import Swollama

@main
struct SwollamaCLI {
    static func main() async throws {
        // Get command line arguments
        var arguments = CommandLine.arguments
        // Remove the executable name
        arguments.removeFirst()

        // Parse host option first
        let baseURL: URL
        if let hostIndex = arguments.firstIndex(of: "--host"),
           hostIndex + 1 < arguments.count {
            baseURL = URL(string: arguments[hostIndex + 1])!
            // Remove the --host and its value from arguments
            arguments.removeSubrange(hostIndex...hostIndex+1)
        } else {
            baseURL = URL(string: "http://localhost:11434")!
        }

        guard !arguments.isEmpty else {
            printUsage()
            throw CLIError.missingCommand
        }

        let command = arguments[0]
        let remainingArgs = Array(arguments.dropFirst())
        let client = OllamaClient(baseURL: baseURL)

        switch command.lowercased() {
        case "list":
            try await ListModelsCommand(client: client).execute(with: remainingArgs)
        case "show":
            try await ShowModelCommand(client: client).execute(with: remainingArgs)
        case "pull":
            try await PullModelCommand(client: client).execute(with: remainingArgs)
        case "copy":
            try await CopyModelCommand(client: client).execute(with: remainingArgs)
        case "delete":
            try await DeleteModelCommand(client: client).execute(with: remainingArgs)
        case "chat":
            try await ChatCommand(client: client).execute(with: remainingArgs)
        case "generate":
            try await GenerateCommand(client: client).execute(with: remainingArgs)
        case "ps":
            try await ListRunningModelsCommand(client: client).execute(with: remainingArgs)
        case "help":
            printUsage()
        default:
            throw CLIError.invalidCommand(command)
        }
    }

    static func printUsage() {
        print("""
        Usage: swollama [options] <command> [arguments]
        
        Options:
          --host <url>            Ollama API host (default: http://localhost:11434)
        
        Commands:
          list                     List available models
          show <model>            Show model information
          pull <model>            Download a model
          copy <src> <dst>        Create a copy of a model
          delete <model>          Remove a model
          chat [model]            Start a chat session
          generate [model]        Generate text from a prompt
          ps                      List running models
          help                    Show this help message
        
        Examples:
          swollama list
          swollama --host http://remote:11434 list
          swollama chat llama2
          swollama generate codellama
          swollama pull llama2
        """)
    }
}
