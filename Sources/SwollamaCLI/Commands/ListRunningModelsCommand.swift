import Foundation
import Swollama

struct ListRunningModelsCommand: CommandProtocol {
    private let client: OllamaProtocol

    init(client: OllamaProtocol) {
        self.client = client
    }

    func execute(with arguments: [String]) async throws {
        print("Fetching running models...")
        let models = try await client.listRunningModels()

        if models.isEmpty {
            print("\nNo models currently running.")
            return
        }

        print("\nRunning Models:")
        print("--------------")
        for model in models {
            print("- Model: \(model.name)")
            print("  Full ID: \(model.model)")
            print("  Size: \(formatBytes(model.size))")
            print("  VRAM Usage: \(formatBytes(model.sizeVRAM))")
            print("  Expires: \(formatDate(model.expiresAt))")
            print("  Details:")
            print("    Family: \(model.details.family)")
            print("    Parameter Size: \(model.details.parameterSize)")
            print("    Quantization: \(model.details.quantizationLevel)")
            print("    Format: \(model.details.format)")
            print("")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let absoluteFormatter = DateFormatter()
        absoluteFormatter.dateStyle = .medium
        absoluteFormatter.timeStyle = .medium
        let absoluteTime = absoluteFormatter.string(from: date)

        // Calculate relative time manually since RelativeDateTimeFormatter isn't available on Linux
        let interval = date.timeIntervalSince(Date())
        let relativeTime: String

        switch abs(interval) {
        case 0..<60:
            relativeTime = "just now"
        case 60..<3600:
            let minutes = Int(abs(interval) / 60)
            relativeTime = "\(minutes) minute\(minutes == 1 ? "" : "s") \(interval < 0 ? "ago" : "from now")"
        case 3600..<86400:
            let hours = Int(abs(interval) / 3600)
            relativeTime = "\(hours) hour\(hours == 1 ? "" : "s") \(interval < 0 ? "ago" : "from now")"
        default:
            let days = Int(abs(interval) / 86400)
            relativeTime = "\(days) day\(days == 1 ? "" : "s") \(interval < 0 ? "ago" : "from now")"
        }

        return "\(relativeTime) (\(absoluteTime))"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.2f %@", value, units[unitIndex])
    }
}
