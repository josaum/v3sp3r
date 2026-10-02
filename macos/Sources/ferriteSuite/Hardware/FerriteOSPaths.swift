import Foundation

/// Resolves where the FerriteOS coprocessor workspace and its toolchain live.
///
/// These used to be hardcoded absolute paths under one developer's home
/// directory, which meant the FerriteOS integration could not find its
/// workspace, firmware, or tools on any other machine.
///
/// Resolution order for the workspace root:
/// 1. `FERRITEOS_WORKSPACE` environment variable
/// 2. the `ferriteOSWorkspace` user default (settable in-app)
/// 3. a `FerriteOS` directory next to the app bundle's Resources
/// 4. `~/projects/FerriteOS`
/// 5. `~/Developer/FerriteOS`
enum FerriteOSPaths {
    static let workspaceEnvVar = "FERRITEOS_WORKSPACE"
    static let workspaceDefaultsKey = "ferriteOSWorkspace"

    /// The workspace root. Every other path in this type is derived from it, so
    /// pointing the app at a different checkout only requires changing this.
    static var workspace: String {
        let fm = FileManager.default
        let fmHome = fm.homeDirectoryForCurrentUser

        if let env = ProcessInfo.processInfo.environment[workspaceEnvVar],
           !env.isEmpty, exists(env) {
            return env
        }
        if let saved = UserDefaults.standard.string(forKey: workspaceDefaultsKey),
           !saved.isEmpty, exists(saved) {
            return saved
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("FerriteOS", isDirectory: true).path,
           exists(bundled) {
            return bundled
        }
        for candidate in [fmHome.appendingPathComponent("projects/FerriteOS").path,
                          fmHome.appendingPathComponent("Developer/FerriteOS").path] where exists(candidate) {
            return candidate
        }
        // Nothing found: return the conventional location so the UI can show a
        // clear "workspace not found" state instead of a bogus path.
        return fmHome.appendingPathComponent("projects/FerriteOS").path
    }

    /// `~/...`-style expansion, so configured paths may use `~`.
    static func expandTilde(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        return (path as NSString).expandingTildeInPath
    }

    static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: expandTilde(path))
    }

    /// First existing path from the candidates, else the first candidate.
    static func resolve(_ candidates: [String]) -> String {
        candidates.first(where: exists) ?? candidates[0]
    }

    static var consoleBinary: String {
        resolve([
            "\(workspace)/target/debug/ferrite-console",
            "\(workspace)/target/release/ferrite-console",
        ])
    }

    static var firmwareDir: String { "\(workspace)/firmware" }

    static var firmwareBin: String { "\(firmwareDir)/ferrite-fw.bin" }
    static var firmwareAppBin: String { "\(firmwareDir)/ferrite-app.bin" }
    static var firmwareElf: String {
        "\(firmwareDir)/target/thumbv7em-none-eabihf/release/ferrite-fw"
    }
    static var firmwareManifest: String { "\(firmwareDir)/ferrite-fw.manifest.json" }
    static var firmwareAppManifest: String { "\(firmwareDir)/ferrite-app.manifest.json" }

    /// Host tools, resolved on `PATH` with the usual Homebrew fallbacks.
    static var dfuUtil: String { tool("dfu-util") }
    static var probeRs: String { tool("probe-rs") }

    static var rfTestDataDir: String { "\(workspace)/crates/ferrite-rf/testdata" }

    private static func tool(_ name: String) -> String {
        let fm = FileManager.default
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        var candidates = pathDirs.map { "\($0)/\(name)" }
        let home = fm.homeDirectoryForCurrentUser.path
        candidates += [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(home)/.cargo/bin/\(name)",
        ]
        return resolve(candidates)
    }
}
