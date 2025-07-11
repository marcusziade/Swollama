import Foundation

// Advanced input handling with multi-line support and history
class InputHandler {
    private var history: [String] = []
    private var historyIndex: Int = 0
    private let maxHistorySize: Int = 100
    
    // ANSI escape codes for cursor control
    private enum ANSICode {
        static let moveUp = "\u{001B}[A"
        static let moveDown = "\u{001B}[B"
        static let moveRight = "\u{001B}[C"
        static let moveLeft = "\u{001B}[D"
        static let clearLine = "\u{001B}[2K"
        static let moveToBOL = "\u{001B}[0G"
        static let saveCursor = "\u{001B}[s"
        static let restoreCursor = "\u{001B}[u"
    }
    
    // Special key sequences
    private enum KeyCode {
        static let escape: UInt8 = 27
        static let backspace: UInt8 = 127
        static let newline: UInt8 = 10
        static let carriageReturn: UInt8 = 13
        static let ctrlC: UInt8 = 3
        static let ctrlD: UInt8 = 4
        static let ctrlL: UInt8 = 12
        static let ctrlU: UInt8 = 21
        static let ctrlK: UInt8 = 11
        static let ctrlA: UInt8 = 1
        static let ctrlE: UInt8 = 5
        static let tab: UInt8 = 9
    }
    
    // Input modes
    enum InputMode {
        case singleLine
        case multiLine
    }
    
    private var mode: InputMode = .singleLine
    private var multiLineTerminator = "```"
    
    init() {
        loadHistory()
    }
    
    deinit {
        saveHistory()
    }
    
    // MARK: - History Management
    
    private func loadHistory() {
        let historyPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".swollama_history")
        
        if let data = try? Data(contentsOf: historyPath),
           let loadedHistory = try? JSONDecoder().decode([String].self, from: data) {
            history = loadedHistory
        }
    }
    
    private func saveHistory() {
        let historyPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".swollama_history")
        
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyPath)
        }
    }
    
    private func addToHistory(_ input: String) {
        guard !input.isEmpty else { return }
        
        // Remove duplicates
        history.removeAll { $0 == input }
        
        // Add to history
        history.append(input)
        
        // Limit history size
        if history.count > maxHistorySize {
            history.removeFirst()
        }
        
        historyIndex = history.count
    }
    
    // MARK: - Terminal Configuration
    
    private func enableRawMode() {
        #if os(Linux)
        var termios = termios()
        tcgetattr(STDIN_FILENO, &termios)
        
        // Save original settings
        var originalTermios = termios
        
        // Modify settings for raw mode
        termios.c_lflag &= ~(tcflag_t(ECHO | ICANON))
        tcsetattr(STDIN_FILENO, TCSANOW, &termios)
        
        // Note: We should restore terminal settings on exit, but atexit
        // cannot capture context. This should be handled by the caller.
        #endif
    }
    
    private func disableRawMode() {
        #if os(Linux)
        var termios = termios()
        tcgetattr(STDIN_FILENO, &termios)
        termios.c_lflag |= tcflag_t(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSANOW, &termios)
        #endif
    }
    
    // MARK: - Single Line Input
    
    func readLine(prompt: String = "") -> String? {
        print(prompt, terminator: "")
        fflush(stdout)
        
        // For now, use standard readLine
        // TODO: Implement custom line editor with arrow key support
        guard let input = Swift.readLine() else {
            return nil
        }
        
        addToHistory(input)
        return input
    }
    
    // MARK: - Multi-line Input
    
    func readMultiLine(prompt: String = "", terminator: String = "```") -> String? {
        print(prompt, terminator: "")
        print(" (Enter '\(terminator)' on a new line to finish)")
        
        var lines: [String] = []
        
        while true {
            print("> ", terminator: "")
            guard let line = readLine() else {
                return lines.isEmpty ? nil : lines.joined(separator: "\n")
            }
            
            if line == terminator {
                break
            }
            
            lines.append(line)
        }
        
        let result = lines.joined(separator: "\n")
        addToHistory(result)
        return result
    }
    
    // MARK: - Auto-completion
    
    func autocomplete(partial: String, candidates: [String]) -> String? {
        let matches = candidates.filter { $0.hasPrefix(partial) }
        
        switch matches.count {
        case 0:
            return nil
        case 1:
            return matches[0]
        default:
            // Show all matches
            print()
            for match in matches {
                print("  \(match)")
            }
            return nil
        }
    }
    
    // MARK: - Confirmation Prompts
    
    func confirm(prompt: String, defaultValue: Bool = false) -> Bool {
        let defaultStr = defaultValue ? "Y/n" : "y/N"
        print("\(prompt) [\(defaultStr)] ", terminator: "")
        
        guard let input = readLine()?.lowercased() else {
            return defaultValue
        }
        
        if input.isEmpty {
            return defaultValue
        }
        
        return input == "y" || input == "yes"
    }
    
    // MARK: - Password Input
    
    func readPassword(prompt: String = "Password: ") -> String? {
        print(prompt, terminator: "")
        fflush(stdout)
        
        #if os(Linux)
        // Disable echo
        var termios = termios()
        tcgetattr(STDIN_FILENO, &termios)
        var originalTermios = termios
        termios.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &termios)
        
        defer {
            // Restore echo
            tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)
            print() // New line after password
        }
        #endif
        
        return readLine()
    }
    
    // MARK: - Selection Menu
    
    func selectOption<T>(prompt: String, options: [(String, T)]) -> T? {
        print(prompt)
        
        for (index, (label, _)) in options.enumerated() {
            print("  \(index + 1). \(label)")
        }
        
        print("\nEnter selection (1-\(options.count)): ", terminator: "")
        
        guard let input = readLine(),
              let selection = Int(input),
              selection > 0,
              selection <= options.count else {
            return nil
        }
        
        return options[selection - 1].1
    }
}

// MARK: - Input Validation

extension InputHandler {
    func readValidatedInput(
        prompt: String,
        validator: (String) -> Bool,
        errorMessage: String = "Invalid input. Please try again."
    ) -> String? {
        while true {
            guard let input = readLine(prompt: prompt) else {
                return nil
            }
            
            if validator(input) {
                return input
            }
            
            print("\(EnhancedTerminalStyle.red)\(errorMessage)\(EnhancedTerminalStyle.reset)")
        }
    }
    
    func readInteger(prompt: String, range: ClosedRange<Int>? = nil) -> Int? {
        let validator: (String) -> Bool = { input in
            guard let value = Int(input) else { return false }
            if let range = range {
                return range.contains(value)
            }
            return true
        }
        
        let errorMessage = range != nil ?
            "Please enter a number between \(range!.lowerBound) and \(range!.upperBound)" :
            "Please enter a valid number"
        
        guard let input = readValidatedInput(
            prompt: prompt,
            validator: validator,
            errorMessage: errorMessage
        ) else {
            return nil
        }
        
        return Int(input)
    }
}

// MARK: - Progress Indicators

class ProgressIndicator {
    private let message: String
    private var isRunning = false
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0
    
    init(message: String) {
        self.message = message
    }
    
    func start() {
        isRunning = true
        Task {
            while isRunning {
                print("\r\(EnhancedTerminalStyle.neonBlue)\(frames[currentFrame])\(EnhancedTerminalStyle.reset) \(message)", terminator: "")
                fflush(stdout)
                currentFrame = (currentFrame + 1) % frames.count
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            print("\r\(String(repeating: " ", count: message.count + 4))\r", terminator: "")
            fflush(stdout)
        }
    }
    
    func stop() {
        isRunning = false
    }
}

// MARK: - Terminal Utilities

struct Terminal {
    static func getSize() -> (width: Int, height: Int) {
        #if os(Linux)
        var winsize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) == 0 {
            return (Int(winsize.ws_col), Int(winsize.ws_row))
        }
        #endif
        return (80, 24) // Default size
    }
    
    static func clear() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
    }
    
    static func moveCursor(row: Int, col: Int) {
        print("\u{001B}[\(row);\(col)H", terminator: "")
    }
    
    static func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }
    
    static func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }
    
    static func saveScreen() {
        print("\u{001B}[?47h", terminator: "")
    }
    
    static func restoreScreen() {
        print("\u{001B}[?47l", terminator: "")
    }
}

// MARK: - Text Formatting

struct TextFormatter {
    static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [text] }
        
        var lines: [String] = []
        var currentLine = ""
        
        for word in text.split(separator: " ") {
            let wordStr = String(word)
            
            if currentLine.isEmpty {
                currentLine = wordStr
            } else if currentLine.count + 1 + wordStr.count <= width {
                currentLine += " " + wordStr
            } else {
                lines.append(currentLine)
                currentLine = wordStr
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
    
    static func center(_ text: String, width: Int) -> String {
        guard text.count < width else { return text }
        let padding = (width - text.count) / 2
        return String(repeating: " ", count: padding) + text
    }
    
    static func rightAlign(_ text: String, width: Int) -> String {
        guard text.count < width else { return text }
        let padding = width - text.count
        return String(repeating: " ", count: padding) + text
    }
}