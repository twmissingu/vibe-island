import Foundation

/// CLI entry point for vibe-island hook handler.
///
/// Called by Claude Code / OpenCode hooks to track session state.
/// Reads hook event JSON from stdin and updates session files in ~/.vibe-island/sessions/.
///
/// Usage: vibe-island hook <EventType>
@main
struct VibeIslandCLI {
    static let version = "1.0.0"

    static func main() {
        let args = CommandLine.arguments

        guard args.count >= 2 else {
            printUsage()
            exit(0)
        }

        switch args[1] {
        case "--version", "-V":
            print("vibe-island \(version)")
            exit(0)
        case "--help", "-h":
            printUsage()
            exit(0)
        case "hook":
            runHook(args: Array(args.dropFirst(2)))
        default:
            printError("Unknown command '\(args[1])'")
            printUsage()
            exit(1)
        }
    }

    // MARK: - Hook Subcommand

    private static func runHook(args: [String]) {
        guard let eventName = args.first, !eventName.isEmpty else {
            printError("Missing event type argument")
            printError("Usage: vibe-island hook <EventType>")
            exit(1)
        }

        guard let stdinData = readStdin(eventName: eventName) else { exit(1) }

        let event: SessionEvent
        do {
            event = try JSONDecoder().decode(SessionEvent.self, from: stdinData)
        } catch {
            printError("Failed to parse JSON: \(error.localizedDescription)")
            exit(1)
        }

        do {
            try HookHandler.handleEvent(event)
        } catch {
            printError(error.localizedDescription)
            exit(1)
        }
    }

    // MARK: - Stdin Reading

    private static func readStdin(eventName: String) -> Data? {
        let box = ReadStdinBox()

        DispatchQueue.global().async {
            do {
                box.data = try FileHandle.standardInput.readToEnd() ?? Data()
            } catch {
                box.error = error
            }
            box.semaphore.signal()
        }

        guard box.semaphore.wait(timeout: .now() + 5) == .success else {
            printError("stdin read timed out after 5s for event '\(eventName)'")
            return nil
        }

        if let error = box.error {
            printError("Failed to read stdin: \(error.localizedDescription)")
            return nil
        }
        return box.data
    }

    // Helper class to safely share mutable state across threads
    private final class ReadStdinBox: @unchecked Sendable {
        let semaphore = DispatchSemaphore(value: 0)
        var data: Data?
        var error: Error?
    }

    // MARK: - Helpers

    private static func printError(_ message: String) {
        let data = ("Error: \(message)\n").data(using: .utf8) ?? Data()
        FileHandle.standardError.write(data)
    }

    private static func printUsage() {
        print("vibe-island \(version) -- LLM session status tracker")
        print("")
        print("USAGE:")
        print("    vibe-island hook <EventType>    Process a hook event from stdin")
        print("")
        print("EVENT TYPES:")
        for event in SessionEventName.allCases {
            let paddedName = event.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)
            print("    \(paddedName) \(event.displayName)")
        }
        print("")
        print("OPTIONS:")
        print("    -h, --help       Print this help message")
        print("    -V, --version    Print version")
    }
}
