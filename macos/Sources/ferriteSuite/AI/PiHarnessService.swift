import Foundation
import SwiftUI

/// Information about the host's Pi Coding Agent configuration.
public struct PiHostConfig: Equatable, Sendable {
    public let configDir: String
    public let defaultProvider: String
    public let defaultModel: String
    public let defaultThinkingLevel: String
    public let packages: [String]
    public let isConfigPresent: Bool
}

/// Service that executes and manages the embedded Pi Agent Harness (`pi`)
/// using the host's existing configuration (`~/.pi/agent`).
@MainActor
@Observable
public final class PiHarnessService {
    public static let shared = PiHarnessService()
    
    public var isAvailable: Bool = false
    public var executablePath: String = ""
    public var version: String = ""
    public var hostConfig: PiHostConfig?
    public var isExecuting: Bool = false
    public var lastError: String?
    
    private var defaultSearchPaths: [String] { HostTools.piCandidates }
    
    public init() {
        refreshStatus()
    }
    
    /// Re-scan host environment for `pi` binary and host configuration files.
    public func refreshStatus() {
        self.executablePath = locatePiBinary()
        self.isAvailable = !self.executablePath.isEmpty && FileManager.default.isExecutableFile(atPath: self.executablePath)
        
        if isAvailable {
            self.version = queryVersion()
        } else {
            self.version = ""
        }
        
        self.hostConfig = loadHostConfig()
    }
    
    /// Locate `pi` executable on host system.
    private func locatePiBinary() -> String {
        let custom = AppSettings.shared.customPiBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty && FileManager.default.isExecutableFile(atPath: custom) {
            return custom
        }
        
        let fm = FileManager.default
        for path in defaultSearchPaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try searching PATH via `which pi`
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["pi"]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = HostTools.subprocessPath
        whichProcess.environment = env
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        
        if (try? whichProcess.run()) != nil {
            whichProcess.waitUntilExit()
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !out.isEmpty {
                    return out
                }
            }
        }
        
        return ""
    }
    
    /// Query version of the installed `pi` binary.
    private func queryVersion() -> String {
        guard !executablePath.isEmpty else { return "" }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = ["--version"]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = HostTools.subprocessPath
        proc.environment = env
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
    
    /// Inspect host's `~/.pi/agent/settings.json` to reflect current host configuration.
    private func loadHostConfig() -> PiHostConfig {
        let home = NSHomeDirectory()
        let configDir = "\(home)/.pi/agent"
        let settingsPath = "\(configDir)/settings.json"
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: settingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return PiHostConfig(
                configDir: configDir,
                defaultProvider: "unknown",
                defaultModel: "unknown",
                defaultThinkingLevel: "unknown",
                packages: [],
                isConfigPresent: false
            )
        }
        
        let provider = json["defaultProvider"] as? String ?? "kimi-coder"
        let model = json["defaultModel"] as? String ?? "kimi-k3"
        let thinking = json["defaultThinkingLevel"] as? String ?? "high"
        let packages = json["packages"] as? [String] ?? []
        
        return PiHostConfig(
            configDir: configDir,
            defaultProvider: provider,
            defaultModel: model,
            defaultThinkingLevel: thinking,
            packages: packages,
            isConfigPresent: true
        )
    }
    
    /// Test execution of the host Pi harness.
    public func testHarness() async -> (success: Bool, message: String) {
        refreshStatus()
        guard isAvailable else {
            let searched = HostTools.searchedLocations("pi")
            return (false, "Pi harness executable not found on host. Checked \(searched).")
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = ["-p", "--no-session", "--no-tools", "Respond with exact text: V3SP3R_PI_ONLINE"]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = HostTools.subprocessPath
        proc.environment = env
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let ok = proc.terminationStatus == 0 && out.contains("V3SP3R_PI_ONLINE")
                    continuation.resume(returning: (ok, ok ? "Pi Harness operational: \(out)" : "Execution finished with status \(proc.terminationStatus): \(out)"))
                } catch {
                    continuation.resume(returning: (false, "Process error: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    /// Stream prompt execution through the Pi Agent Harness using host configurations.
    /// Emits `StreamChunk` deltas identical to OpenRouter streaming so the UI and tool executor remain unified.
    public func streamPrompt(
        prompt: String,
        systemPrompt: String = FerriteSuitePrompts.systemPrompt,
        model: String? = nil,
        onDelta: @escaping @MainActor (StreamChunk) -> Void
    ) async throws {
        refreshStatus()
        guard isAvailable else {
            throw NSError(
                domain: "PiHarnessService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Pi harness binary not found on host at \(executablePath)."]
            )
        }
        
        self.isExecuting = true
        defer { self.isExecuting = false }
        
        var args = ["-p", "--mode", "json", "--no-session", "--no-tools"]
        
        // Append system prompt with tool execution guidelines
        let extendedSystemPrompt = """
\(systemPrompt)

## PI HARNESS TOOL CALL PROTOCOL
When you decide to execute a tool or hardware action, output a JSON block matching:
```json
{
  "action": "<action_name>",
  "parameters": {
    "<key>": "<value>"
  }
}
```
Or use the short form:
ACTION: <action_name> PARAMS: {"<key>": "<value>"}
"""
        args.append(contentsOf: ["--append-system-prompt", extendedSystemPrompt])
        
        // Use custom model override if provided, else check AppSettings, else rely on host default from ~/.pi/agent/settings.json
        let customModel = AppSettings.shared.piHarnessModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetModel = (model != nil && !model!.isEmpty) ? model! : customModel
        if !targetModel.isEmpty {
            args.append(contentsOf: ["--model", targetModel])
        }
        
        args.append(prompt)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = HostTools.subprocessPath
        proc.environment = env
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        
        try proc.run()
        
        var accumulatedText = ""
        let fileHandle = stdoutPipe.fileHandleForReading
        
        // Asynchronously read stdout line by line
        for try await line in fileHandle.bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let type = json["type"] as? String ?? ""
                
                if type == "message_update" {
                    if let event = json["assistantMessageEvent"] as? [String: Any] {
                        let evType = event["type"] as? String ?? ""
                        if evType == "text_delta", let delta = event["delta"] as? String {
                            accumulatedText += delta
                            onDelta(StreamChunk(textDelta: delta, toolCallDelta: nil, isFinished: false))
                        }
                    }
                } else if type == "turn_end" || type == "message_end" || type == "agent_end" {
                    // Check if accumulated response contains a structured action call
                    if let toolCall = parseToolCallFromText(accumulatedText) {
                        onDelta(StreamChunk(
                            textDelta: nil,
                            toolCallDelta: (id: UUID().uuidString, name: toolCall.action, args: toolCall.argsJson),
                            isFinished: false
                        ))
                    }
                }
            }
        }
        
        proc.waitUntilExit()
        
        // Final completion marker
        onDelta(StreamChunk(textDelta: nil, toolCallDelta: nil, isFinished: true))
    }
    
    /// Parse JSON action block from accumulated agent text.
    private func parseToolCallFromText(_ text: String) -> (action: String, argsJson: String)? {
        // 1. Look for ```json { "action": ... } ``` block
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            let block = String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = block.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let action = json["action"] as? String {
                let params = json["parameters"] as? [String: Any] ?? [:]
                let paramsData = (try? JSONSerialization.data(withJSONObject: params)) ?? Data()
                let paramsStr = String(data: paramsData, encoding: .utf8) ?? "{}"
                return (action, paramsStr)
            }
        }
        
        // 2. Look for raw {"action": ..., "parameters": ...} anywhere in text
        if let start = text.range(of: "{\"action\""),
           let end = text.range(of: "}", options: .backwards, range: start.lowerBound..<text.endIndex) {
            let rawJson = String(text[start.lowerBound...end.lowerBound])
            if let data = rawJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let action = json["action"] as? String {
                let params = json["parameters"] as? [String: Any] ?? [:]
                let paramsData = (try? JSONSerialization.data(withJSONObject: params)) ?? Data()
                let paramsStr = String(data: paramsData, encoding: .utf8) ?? "{}"
                return (action, paramsStr)
            }
        }
        
        return nil
    }
    
    /// Query list of available models from installed `pi` binary.
    public func fetchAvailableModels() async -> [String] {
        refreshStatus()
        guard isAvailable else { return [] }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = ["--list-models"]
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = HostTools.subprocessPath
        proc.environment = env
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let text = String(data: data, encoding: .utf8) else {
                        continuation.resume(returning: [])
                        return
                    }
                    var models: [String] = []
                    let lines = text.components(separatedBy: .newlines)
                    for (idx, line) in lines.enumerated() {
                        if idx == 0 { continue } // skip header line
                        let parts = line.split(whereSeparator: \.isWhitespace)
                        if parts.count >= 2 {
                            let provider = String(parts[0])
                            let modelName = String(parts[1])
                            models.append("\(provider)/\(modelName)")
                        }
                    }
                    continuation.resume(returning: models)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
