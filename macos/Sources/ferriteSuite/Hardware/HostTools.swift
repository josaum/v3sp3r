import Foundation

/// Resolution for host CLI tools the app shells out to (`cargo`, `pi`,
/// `probe-rs`, `dfu-util`, ...).
///
/// These were hardcoded to one developer's home directory, so they resolved to
/// nothing on any other machine. Everything now resolves on `PATH` first, with
/// the common install locations as fallbacks.
enum HostTools {
    /// Directories searched for host tools, in priority order.
    static var searchDirs: [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let fromEnv = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        return fromEnv + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "\(home)/.cargo/bin",
            "\(home)/.local/bin",
            "\(home)/bin",
        ]
    }

    /// Absolute path to `name`, or nil when it is not installed.
    static func find(_ name: String) -> String? {
        // An absolute or explicitly relative path is used as-is.
        if name.hasPrefix("/") || name.hasPrefix("~") {
            let expanded = (name as NSString).expandingTildeInPath
            return FileManager.default.isExecutableFile(atPath: expanded) ? expanded : nil
        }
        return searchDirs
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Absolute path to `name`, falling back to the first candidate so callers
    /// still get a plausible path to show in the UI when it is missing.
    static func path(_ name: String) -> String {
        find(name) ?? searchDirs.map { "\($0)/\(name)" }.first { FileManager.default.fileExists(atPath: $0) }
            ?? "/usr/bin/\(name)"
    }

    static var cargo: String { path("cargo") }
    static var probeRs: String { path("probe-rs") }
    static var dfuUtil: String { path("dfu-util") }

    /// Candidate locations for the `pi` coding agent, in priority order.
    static var piCandidates: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/pi", "\(home)/bin/pi", "/opt/homebrew/bin/pi", "/usr/local/bin/pi"]
    }

    /// Resolved `pi` executable, or nil when not installed.
    static var pi: String? {
        piCandidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? find("pi")
    }

    /// A `PATH` value for `Process` environments. Subprocesses inherit the app's
    /// environment, so toolchains like `~/.cargo/bin` and Homebrew are included
    /// explicitly rather than assuming the launcher's `PATH`.
    static var subprocessPath: String {
        var dirs = searchDirs
        // Preserve any extra dirs the user already had.
        for dir in (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        where !dirs.contains(dir) {
            dirs.append(dir)
        }
        return dirs.joined(separator: ":")
    }

    /// Human-readable list of where a tool was looked for, for error messages.
    static func searchedLocations(_ name: String) -> String {
        (["\(name) on PATH"] + searchDirs.prefix(4).map { "\($0)/\(name)" }).joined(separator: ", ")
    }
}
