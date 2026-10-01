import Foundation
import SwiftUI

public struct FerriteUnderstanding: Identifiable, Equatable {
    public let id = UUID()
    public let phrase: String
    public let intent: String
    public let domain: String
    public let confidence: Int
    public let rawOutput: String
    public let timestamp: Date = Date()
}

public struct FerriteManifestInfo: Codable, Equatable {
    public let binSha256: String
    public let elfSha256: String
    public let flashBase: Int
    public let flashBytes: Int
    public let flashLimitBytes: Int
    public let ramLimitBytes: Int
    public let ramHeadroomBytes: Int
    public let replacesStockBootloader: Bool
    public let target: String
    
    public var flashPercentage: Double {
        guard flashLimitBytes > 0 else { return 0 }
        return Double(flashBytes) / Double(flashLimitBytes) * 100.0
    }
}

@MainActor
@Observable
public final class FerriteOSService {
    public static let shared = FerriteOSService()
    
    public let workspacePath: String = "/Users/josaum/projects/FerriteOS"
    public let binaryPath: String = "/Users/josaum/projects/FerriteOS/target/debug/ferrite-console"
    public let firmwareDir: String = "/Users/josaum/projects/FerriteOS/firmware"
    public let firmwareBinPath: String = "/Users/josaum/projects/FerriteOS/firmware/ferrite-fw.bin"
    public let firmwareAppBinPath: String = "/Users/josaum/projects/FerriteOS/firmware/ferrite-app.bin"
    public let firmwareElfPath: String = "/Users/josaum/projects/FerriteOS/firmware/target/thumbv7em-none-eabihf/release/ferrite-fw"
    public let firmwareManifestPath: String = "/Users/josaum/projects/FerriteOS/firmware/ferrite-fw.manifest.json"
    public let firmwareAppManifestPath: String = "/Users/josaum/projects/FerriteOS/firmware/ferrite-app.manifest.json"
    public let dfuUtilPath: String = "/opt/homebrew/bin/dfu-util"
    public let probeRsPath: String = "/Users/josaum/.cargo/bin/probe-rs"
    
    public var isAvailable: Bool = false
    public var isWorkspacePresent: Bool = false
    public var isFirmwareBinPresent: Bool = false
    public var isDfuUtilPresent: Bool = false
    public var isProbeRsPresent: Bool = false
    public var isFerriteOS: Bool { FlipperConnectionManager.shared.isFerriteOS }
    
    public var manifestInfo: FerriteManifestInfo?
    public var lastUnderstanding: FerriteUnderstanding?
    public var recentOutputs: [FerriteUnderstanding] = []
    
    public var isExecuting: Bool = false
    public var isPreflightRunning: Bool = false
    public var isTestRunning: Bool = false
    public var isBuilding: Bool = false
    public var isFlashingDfu: Bool = false
    
    public var lastPreflightOutput: String = ""
    public var preflightPassed: Bool? = nil
    public var lastTestOutput: String = ""
    public var testPassed: Bool? = nil
    public var dfuScanOutput: String = ""
    public var probeScanOutput: String = ""
    public var buildLog: String = ""
    public var executionLogs: [String] = []
    
    public init() {
        checkAvailability()
        loadManifest()
    }
    
    public func checkAvailability() {
        let fm = FileManager.default
        self.isWorkspacePresent = fm.fileExists(atPath: workspacePath)
        self.isAvailable = fm.fileExists(atPath: binaryPath)
        self.isFirmwareBinPresent = fm.fileExists(atPath: firmwareAppBinPath) || fm.fileExists(atPath: firmwareBinPath)
        self.isDfuUtilPresent = fm.fileExists(atPath: dfuUtilPath)
        self.isProbeRsPresent = fm.fileExists(atPath: probeRsPath)
    }
    
    public func loadManifest() {
        let fm = FileManager.default
        let path = fm.fileExists(atPath: firmwareAppManifestPath) ? firmwareAppManifestPath : firmwareManifestPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        let irMem = json["infrared_memory"] as? [String: Any] ?? [:]
        let headroom = irMem["ram_headroom_bytes"] as? Int ?? 0
        
        self.manifestInfo = FerriteManifestInfo(
            binSha256: json["bin_sha256"] as? String ?? "",
            elfSha256: json["elf_sha256"] as? String ?? "",
            flashBase: json["flash_base"] as? Int ?? 0x08008000,
            flashBytes: json["flash_bytes"] as? Int ?? 0,
            flashLimitBytes: json["flash_limit_bytes"] as? Int ?? 262144,
            ramLimitBytes: json["ram_limit_bytes"] as? Int ?? 196608,
            ramHeadroomBytes: headroom,
            replacesStockBootloader: json["replaces_stock_bootloader"] as? Bool ?? false,
            target: json["target"] as? String ?? "thumbv7em-none-eabihf"
        )
    }
    
    // MARK: - Natural Language & Signal Decoding
    
    public func understandPhrase(_ phrase: String) async throws -> FerriteUnderstanding {
        guard isAvailable else {
            throw NSError(
                domain: "FerriteOSService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "FerriteOS console binary not found at \(binaryPath)."]
            )
        }
        
        self.isExecuting = true
        defer { self.isExecuting = false }
        
        let output = try await runCommand(executable: binaryPath, args: [phrase], cwd: workspacePath)
        let parsed = parseFerriteOutput(phrase: phrase, output: output)
        
        self.lastUnderstanding = parsed
        self.recentOutputs.insert(parsed, at: 0)
        if self.recentOutputs.count > 20 {
            self.recentOutputs.removeLast()
        }
        
        VesperMemoryStore.shared.addMemory(
            category: .ferritePlan,
            title: "FerriteOS: \(parsed.intent) on \(parsed.domain)",
            content: "Phrase: '\(phrase)'\nConfidence: \(parsed.confidence)\nResult:\n\(parsed.rawOutput)"
        )
        
        return parsed
    }
    
    public func decodeCapture(filePath: String, phrase: String = "what is this") async throws -> String {
        guard isAvailable else {
            throw NSError(
                domain: "FerriteOSService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "FerriteOS console binary not found at \(binaryPath)."]
            )
        }
        
        self.isExecuting = true
        defer { self.isExecuting = false }
        
        let output = try await runCommand(executable: binaryPath, args: [phrase, filePath], cwd: workspacePath)
        return output
    }
    
    public func inspectSubGhz(filePath: String, decoderFlag: String? = nil) async throws -> String {
        var args = ["run", "-p", "ferrite-rf", "--example", "inspect_subghz", "--"]
        if let flag = decoderFlag, !flag.isEmpty {
            args.append(flag)
        }
        args.append(filePath)
        
        let cargoPath = "/Users/josaum/.cargo/bin/cargo"
        return try await runCommand(executable: cargoPath, args: args, cwd: workspacePath)
    }
    
    public func inspectNfc(filePath: String, flag: String = "--pages") async throws -> String {
        let args = ["run", "-p", "ferrite-rf", "--example", "inspect_nfc", "--", flag, filePath]
        let cargoPath = "/Users/josaum/.cargo/bin/cargo"
        return try await runCommand(executable: cargoPath, args: args, cwd: workspacePath)
    }
    
    // MARK: - Firmware Pre-flight, Build & Verification
    
    public func runPreflightCheck(preferApp: Bool = true) async -> (success: Bool, output: String) {
        self.isPreflightRunning = true
        defer { self.isPreflightRunning = false }
        
        let fm = FileManager.default
        let isApp = preferApp && fm.fileExists(atPath: firmwareAppBinPath) && fm.fileExists(atPath: firmwareAppManifestPath)
        let binPath = isApp ? firmwareAppBinPath : firmwareBinPath
        let manifestPath = isApp ? firmwareAppManifestPath : firmwareManifestPath
        
        let pythonPath = "/usr/bin/python3"
        let scriptPath = "\(firmwareDir)/check_image.py"
        var args = [
            scriptPath,
            "--elf", firmwareElfPath,
            "--bin", binPath,
            "--manifest", manifestPath
        ]
        if isApp {
            args.append(contentsOf: ["--flash-base", "0x08008000"])
        }
        
        do {
            let output = try await runCommand(executable: pythonPath, args: args, cwd: firmwareDir)
            let passed = output.contains("PASS") || output.contains("image preflight: PASS")
            self.lastPreflightOutput = output
            self.preflightPassed = passed
            loadManifest()
            return (passed, output)
        } catch {
            let err = error.localizedDescription
            self.lastPreflightOutput = "Preflight check failed: \(err)"
            self.preflightPassed = false
            return (false, err)
        }
    }
    
    public func runUnitTests() async -> (success: Bool, output: String) {
        self.isTestRunning = true
        defer { self.isTestRunning = false }
        
        let pythonPath = "/usr/bin/python3"
        let args = ["-m", "unittest", "test_build"]
        
        do {
            let output = try await runCommand(executable: pythonPath, args: args, cwd: firmwareDir)
            let passed = output.contains("OK") && !output.contains("FAILED")
            self.lastTestOutput = output
            self.testPassed = passed
            return (passed, output)
        } catch {
            let err = error.localizedDescription
            self.lastTestOutput = "Test suite execution error: \(err)"
            self.testPassed = false
            return (false, err)
        }
    }
    
    public func buildFirmware(forApp: Bool = true) async -> (success: Bool, output: String) {
        self.isBuilding = true
        defer { self.isBuilding = false }
        
        let bashPath = "/bin/bash"
        let script = forApp ? "build-app.sh" : "build.sh"
        let scriptPath = "\(firmwareDir)/\(script)"
        
        do {
            let output = try await runCommand(executable: bashPath, args: [scriptPath], cwd: firmwareDir)
            self.buildLog = output
            checkAvailability()
            loadManifest()
            _ = await runPreflightCheck(preferApp: forApp)
            return (true, output)
        } catch {
            let err = error.localizedDescription
            self.buildLog = "Build failed: \(err)"
            return (false, err)
        }
    }
    
    // MARK: - Hardware Diagnostics & Scanning
    
    public func scanDfuDevices() async -> String {
        guard isDfuUtilPresent else { return "dfu-util is not installed at \(dfuUtilPath)" }
        do {
            let out = try await runCommand(executable: dfuUtilPath, args: ["--list"], cwd: firmwareDir)
            self.dfuScanOutput = out
            return out
        } catch {
            let err = "DFU scan error: \(error.localizedDescription)"
            self.dfuScanOutput = err
            return err
        }
    }
    
    public func scanProbeDevices() async -> String {
        guard isProbeRsPresent else { return "probe-rs is not installed at \(probeRsPath)" }
        do {
            let out = try await runCommand(executable: probeRsPath, args: ["list"], cwd: firmwareDir)
            self.probeScanOutput = out
            return out
        } catch {
            let err = "SWD probe scan error: \(error.localizedDescription)"
            self.probeScanOutput = err
            return err
        }
    }
    
    // MARK: - Flashing FerriteOS
    
    public func flashFirmwareDfu(forApp: Bool = true) async throws -> String {
        guard isDfuUtilPresent else {
            throw NSError(domain: "FerriteOSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "dfu-util binary not found"])
        }
        
        let targetBin = forApp && FileManager.default.fileExists(atPath: firmwareAppBinPath) ? firmwareAppBinPath : firmwareBinPath
        let targetBase = forApp && FileManager.default.fileExists(atPath: firmwareAppBinPath) ? "0x08008000" : "0x08000000"
        
        guard FileManager.default.fileExists(atPath: targetBin) else {
            throw NSError(domain: "FerriteOSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(targetBin) not found"])
        }
        
        self.isFlashingDfu = true
        defer { self.isFlashingDfu = false }
        
        // 1. Run preflight
        let preflight = await runPreflightCheck(preferApp: forApp)
        guard preflight.success else {
            throw NSError(domain: "FerriteOSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firmware preflight check failed. Aborting write to \(targetBase)."])
        }
        
        // 2. Command dfu-util: write at targetBase and leave
        let args = ["-a", "0", "-s", "\(targetBase):leave", "-D", targetBin]
        let output = try await runCommand(executable: dfuUtilPath, args: args, cwd: firmwareDir)
        return output
    }
    
    // MARK: - Process Execution Helper
    
    private func runCommand(executable: String, args: [String], cwd: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
                
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/Users/josaum/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                process.environment = env
                
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let outStr = String(data: data, encoding: .utf8) ?? ""
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    
                    let combined = outStr.isEmpty ? errStr : (errStr.isEmpty ? outStr : "\(outStr)\n\(errStr)")
                    continuation.resume(returning: combined.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseFerriteOutput(phrase: String, output: String) -> FerriteUnderstanding {
        var intent = "Unknown"
        var domain = "Any"
        var confidence = 1
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(" on ") && trimmed.contains("confidence") {
                let parts = trimmed.components(separatedBy: " on ")
                if parts.count >= 2 {
                    intent = parts[0].trimmingCharacters(in: .whitespaces)
                    let rest = parts[1]
                    if let openParen = rest.firstIndex(of: "("), let closeParen = rest.firstIndex(of: ")") {
                        domain = String(rest[..<openParen]).trimmingCharacters(in: .whitespaces)
                        let confStr = String(rest[rest.index(after: openParen)..<closeParen])
                            .replacingOccurrences(of: "confidence", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        confidence = Int(confStr) ?? 1
                    } else {
                        domain = rest
                    }
                }
            }
        }
        
        return FerriteUnderstanding(
            phrase: phrase,
            intent: intent,
            domain: domain,
            confidence: confidence,
            rawOutput: output
        )
    }
}
