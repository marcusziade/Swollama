#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

/// Protocol for handling terminal-related operations and queries
protocol TerminalHelper {
    /// The current width of the terminal window in characters
    var terminalWidth: Int { get }
}

/// Default implementation of TerminalHelper that uses system calls to get terminal information
struct DefaultTerminalHelper: TerminalHelper {
    /// Gets the current terminal width using POSIX system calls
    /// If unable to determine the width, returns a default value of 50 characters
    ///
    /// - Returns: The width of the terminal in characters
    /// - Note: Uses the TIOCGWINSZ ioctl command to query terminal dimensions
    var terminalWidth: Int {
        var w = winsize()
        #if os(Linux)
        let result = ioctl(Int32(STDOUT_FILENO), UInt(TIOCGWINSZ), &w)
        #else
        let result = ioctl(STDOUT_FILENO, TIOCGWINSZ, &w)
        #endif

        guard result == 0 else {
            return 50 // Default fallback width
        }
        return Int(w.ws_col)
    }
}
