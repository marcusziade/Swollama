import Foundation

enum CLIError: LocalizedError {
    case unknownCommand(String)
    case missingArgument(String)
    case invalidArgument(String)
    case missingCommand
    case invalidCommand(String)

    var errorDescription: String? {
        switch self {
        case .unknownCommand(let cmd):
            return "Unknown command: \(cmd)"
        case .missingArgument(let msg):
            return "Missing argument: \(msg)"
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .missingCommand:
            return "No command specified"
        case .invalidCommand(let cmd):
            return "Invalid command: \(cmd)"
        }
    }
}
