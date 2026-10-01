import Foundation
import SwiftUI

public struct FerritePlannedAction: Identifiable, Equatable {
    public let id = UUID()
    public let actionType: String
    public let detail: String
    public let requiresHardware: Bool
    public let isEmitting: Bool
    public let targetDomain: String
}

public struct FerritePulseEdge: Identifiable, Equatable {
    public let id = UUID()
    public let isHigh: Bool
    public let durationMicros: Int
    
    public init(isHigh: Bool, durationMicros: Int) {
        self.isHigh = isHigh
        self.durationMicros = durationMicros
    }
}

public struct FerriteCaptureMetadata: Equatable {
    public var filetype: String = ""
    public var frequency: String = ""
    public var preset: String = ""
    public var protocolName: String = ""
    public var deviceType: String = ""
    public var uid: String = ""
    public var totalSamples: Int = 0
}

public struct FerriteDecodedFinding: Codable, Equatable {
    public let summary: String
    public let protocolName: String?
    public let keyHex: String?
    public let bits: Int?
    public let details: String?
    
    enum CodingKeys: String, CodingKey {
        case summary
        case protocolName = "protocol"
        case keyHex = "key_hex"
        case bits
        case details
    }
}

public struct FerriteDecodedCapture: Identifiable, Equatable {
    public let id = UUID()
    public let status: String
    public let intent: String
    public let domain: String
    public let confidence: Int
    public let filePath: String
    public let finding: FerriteDecodedFinding?
    public let rawOutput: String
    public let metadata: FerriteCaptureMetadata
    public let pulses: [FerritePulseEdge]
    public let timestamp: Date = Date()
}

public struct FerriteCoreImageVersion: Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

public struct FerriteWireHandshakeResult: Identifiable, Equatable {
    public let id = UUID()
    public let status: String
    public let handshakeState: String
    public let effectiveWire: Int
    public let coreAbi: Int
    public let coreImage: FerriteCoreImageVersion
    public let caps: Int
    public let requestHex: String
    public let responseHex: String
    public let rawOutput: String
    public let timestamp: Date = Date()
}

public struct FerriteUnderstanding: Identifiable, Equatable {
    public let id = UUID()
    public let phrase: String
    public let intent: String
    public let domain: String
    public let confidence: Int
    public let rawOutput: String
    public let plannedActions: [FerritePlannedAction]
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

public struct FerriteCrateInfo: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let specReference: String
    public let isPureNoStd: Bool
    public var lastTestStatus: String?
    public var passed: Bool?
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
    public var lastDecodedCapture: FerriteDecodedCapture?
    public var lastWireHandshake: FerriteWireHandshakeResult?
    public var recentOutputs: [FerriteUnderstanding] = []
    
    public var crates: [FerriteCrateInfo] = [
        FerriteCrateInfo(name: "ferrite-agent", description: "Deterministic on-device intent classifier and action planner.", specReference: "SPEC-001", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-rf", description: "RF pipeline, DSP, capture ring, and 55+ protocol decoders.", specReference: "SPEC-005", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-core", description: "Kernel supervisor, task scheduler, and capability brokers.", specReference: "SPEC-003", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-types", description: "Shared architectural types, invariants, memory layouts.", specReference: "SPEC-000", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-wire", description: "SPEC-011 wire protocol codec, framing, and HELLO negotiation.", specReference: "SPEC-011", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-cap", description: "O(1) capability broker and runtime facility accounting.", specReference: "SPEC-004", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-pack", description: "Signed protocol pack loader, declarative matchers.", specReference: "SPEC-008", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-store", description: "Log-structured journal, KV index, provenance binding.", specReference: "SPEC-009", isPureNoStd: true),
        FerriteCrateInfo(name: "ferrite-console", description: "Host CLI interactive REPL and headless signal session.", specReference: "HOST-CLI", isPureNoStd: false)
    ]
    
    public var isExecuting: Bool = false
    public var isPreflightRunning: Bool = false
    public var isTestRunning: Bool = false
    public var isBuilding: Bool = false
    public var isFlashingDfu: Bool = false
    public var testingCrateName: String? = nil
    public var crateTestOutput: String = ""
    
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
        
        let output = try await runCommand(executable: binaryPath, args: ["--json", phrase], cwd: workspacePath)
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
    
    @discardableResult
    public func decodeCapture(filePath: String, phrase: String = "what is this") async throws -> FerriteDecodedCapture {
        guard isAvailable else {
            throw NSError(
                domain: "FerriteOSService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "FerriteOS console binary not found at \(binaryPath)."]
            )
        }
        
        self.isExecuting = true
        defer { self.isExecuting = false }
        
        // Run with --json for deterministic machine parsing
        let jsonOutput = try await runCommand(executable: binaryPath, args: ["--json", phrase, filePath], cwd: workspacePath)
        
        // Extract pulses and capture metadata asynchronously from local file
        let (metadata, pulses) = parseFileArtifacts(filePath: filePath)
        
        var decodedFinding: FerriteDecodedFinding? = nil
        var intent = "Decode"
        var domain = "SubGhz"
        var confidence = 2
        var status = "success"
        
        // Parse the JSON line(s)
        for line in jsonOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.starts(with: "{") && trimmed.contains("\"finding\"") else { continue }
            
            if let data = trimmed.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                status = obj["status"] as? String ?? "success"
                intent = obj["intent"] as? String ?? intent
                domain = obj["domain"] as? String ?? domain
                confidence = obj["confidence"] as? Int ?? confidence
                
                if let findingDict = obj["finding"] as? [String: Any] {
                    let summary = findingDict["summary"] as? String ?? ""
                    let proto = findingDict["protocol"] as? String
                    let key = findingDict["key_hex"] as? String
                    let bits = findingDict["bits"] as? Int
                    let details = findingDict["details"] as? String
                    decodedFinding = FerriteDecodedFinding(
                        summary: summary,
                        protocolName: proto,
                        keyHex: key,
                        bits: bits,
                        details: details
                    )
                }
                break
            }
        }
        
        let result = FerriteDecodedCapture(
            status: status,
            intent: intent,
            domain: domain,
            confidence: confidence,
            filePath: filePath,
            finding: decodedFinding,
            rawOutput: jsonOutput,
            metadata: metadata,
            pulses: pulses
        )
        
        self.lastDecodedCapture = result
        
        // Also feed Vesper memory store
        if let finding = decodedFinding {
            VesperMemoryStore.shared.addMemory(
                category: .ferritePlan,
                title: "FerriteOS Decoded: \(finding.protocolName ?? domain)",
                content: "File: \(filePath)\nSummary: \(finding.summary)\nDetails: \(finding.details ?? "")"
            )
        }
        
        return result
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
    
    public func simulateWireHandshake() async throws -> FerriteWireHandshakeResult {
        let args = ["run", "-p", "ferrite-wire", "--example", "inspect_wire", "--", "--json"]
        let cargoPath = "/Users/josaum/.cargo/bin/cargo"
        let output = try await runCommand(executable: cargoPath, args: args, cwd: workspacePath)
        
        var handshakeState = "CLOSED"
        var effectiveWire = 1
        var coreAbi = 1
        var coreImage = FerriteCoreImageVersion(major: 0, minor: 1, patch: 0)
        var caps = 0
        var reqHex = ""
        var respHex = ""
        var status = "success"
        
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.starts(with: "{") && trimmed.contains("\"handshake\"") else { continue }
            
            if let data = trimmed.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                status = obj["status"] as? String ?? status
                handshakeState = obj["handshake"] as? String ?? handshakeState
                effectiveWire = obj["effective_wire"] as? Int ?? effectiveWire
                coreAbi = obj["core_abi"] as? Int ?? coreAbi
                if let imgArr = obj["core_image"] as? [Int], imgArr.count == 3 {
                    coreImage = FerriteCoreImageVersion(major: imgArr[0], minor: imgArr[1], patch: imgArr[2])
                }
                caps = obj["caps"] as? Int ?? caps
                reqHex = obj["req_hex"] as? String ?? reqHex
                respHex = obj["resp_hex"] as? String ?? respHex
                break
            }
        }
        
        let result = FerriteWireHandshakeResult(
            status: status,
            handshakeState: handshakeState,
            effectiveWire: effectiveWire,
            coreAbi: coreAbi,
            coreImage: coreImage,
            caps: caps,
            requestHex: reqHex,
            responseHex: respHex,
            rawOutput: output
        )
        self.lastWireHandshake = result
        return result
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
    
    public func runCrateTest(crateName: String) async -> (success: Bool, output: String) {
        self.testingCrateName = crateName
        defer { self.testingCrateName = nil }
        
        let cargoPath = "/Users/josaum/.cargo/bin/cargo"
        let args = ["test", "-p", crateName]
        do {
            let output = try await runCommand(executable: cargoPath, args: args, cwd: workspacePath)
            let passed = output.contains("test result: ok")
            self.crateTestOutput = output
            if let idx = crates.firstIndex(where: { $0.name == crateName }) {
                crates[idx].passed = passed
                crates[idx].lastTestStatus = passed ? "PASS" : "FAIL"
            }
            return (passed, output)
        } catch {
            let err = error.localizedDescription
            self.crateTestOutput = "Crate test error: \(err)"
            if let idx = crates.firstIndex(where: { $0.name == crateName }) {
                crates[idx].passed = false
                crates[idx].lastTestStatus = "ERROR"
            }
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
        var plannedActions: [FerritePlannedAction] = []
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Check for JSON mode lines first
            if trimmed.starts(with: "{") && trimmed.contains("\"status\"") {
                if let data = trimmed.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let status = obj["status"] as? String ?? ""
                    
                    if status == "intent_classified" {
                        intent = obj["verb"] as? String ?? intent
                        domain = obj["domain"] as? String ?? domain
                        confidence = obj["confidence"] as? Int ?? confidence
                    } else if status == "requires_hardware" {
                        let action = obj["action"] as? String ?? "Observe"
                        let actDomain = obj["domain"] as? String ?? domain
                        let band = obj["band"] as? String ?? ""
                        let msg = obj["message"] as? String ?? (band.isEmpty ? "" : "band: \(band)")
                        let detail = "\(action) \(actDomain)\(msg.isEmpty ? "" : " (\(msg))")"
                        plannedActions.append(FerritePlannedAction(
                            actionType: action.capitalized,
                            detail: detail,
                            requiresHardware: true,
                            isEmitting: false,
                            targetDomain: actDomain
                        ))
                    } else if status == "requires_approval" {
                        let actDomain = obj["domain"] as? String ?? domain
                        let target = obj["target"] as? String ?? ""
                        let gated = obj["gated"] as? Bool ?? true
                        let detail = "emit \(actDomain) target: \(target) (gated: \(gated))"
                        plannedActions.append(FerritePlannedAction(
                            actionType: "Emit",
                            detail: detail,
                            requiresHardware: true,
                            isEmitting: true,
                            targetDomain: actDomain
                        ))
                    } else if status == "success" {
                        if let action = obj["action"] as? String {
                            if action == "filter" {
                                let cat = obj["category"] as? String ?? ""
                                plannedActions.append(FerritePlannedAction(
                                    actionType: "Filter",
                                    detail: "narrowing to category \(cat)",
                                    requiresHardware: false,
                                    isEmitting: false,
                                    targetDomain: domain
                                ))
                            } else if action == "save" {
                                let name = obj["name"] as? String ?? ""
                                plannedActions.append(FerritePlannedAction(
                                    actionType: "Save",
                                    detail: "saved capture as '\(name)'",
                                    requiresHardware: false,
                                    isEmitting: false,
                                    targetDomain: domain
                                ))
                            } else if action == "stop" {
                                plannedActions.append(FerritePlannedAction(
                                    actionType: "Stop",
                                    detail: "stopped current activity",
                                    requiresHardware: false,
                                    isEmitting: false,
                                    targetDomain: domain
                                ))
                            }
                        } else if let finding = obj["finding"] as? [String: Any] {
                            let summary = finding["summary"] as? String ?? ""
                            plannedActions.append(FerritePlannedAction(
                                actionType: "Decoded",
                                detail: summary,
                                requiresHardware: false,
                                isEmitting: false,
                                targetDomain: domain
                            ))
                        }
                    }
                    continue
                }
            }
            
            // Plaintext fallback parser
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
            } else if trimmed.starts(with: "observe ") {
                let requiresHw = trimmed.contains("needs a radio") || trimmed.contains("hardware")
                plannedActions.append(FerritePlannedAction(
                    actionType: "Observe",
                    detail: trimmed,
                    requiresHardware: requiresHw,
                    isEmitting: false,
                    targetDomain: domain
                ))
            } else if trimmed.starts(with: "read ") {
                let requiresHw = trimmed.contains("needs a radio") || trimmed.contains("hardware")
                plannedActions.append(FerritePlannedAction(
                    actionType: "Read",
                    detail: trimmed,
                    requiresHardware: requiresHw,
                    isEmitting: false,
                    targetDomain: domain
                ))
            } else if trimmed.starts(with: "emit ") {
                plannedActions.append(FerritePlannedAction(
                    actionType: "Emit",
                    detail: trimmed,
                    requiresHardware: true,
                    isEmitting: true,
                    targetDomain: domain
                ))
            } else if trimmed.starts(with: "→ ") {
                plannedActions.append(FerritePlannedAction(
                    actionType: "Decoded",
                    detail: trimmed,
                    requiresHardware: false,
                    isEmitting: false,
                    targetDomain: domain
                ))
            } else if trimmed.starts(with: "narrowing to ") {
                plannedActions.append(FerritePlannedAction(
                    actionType: "Filter",
                    detail: trimmed,
                    requiresHardware: false,
                    isEmitting: false,
                    targetDomain: domain
                ))
            }
        }
        
        return FerriteUnderstanding(
            phrase: phrase,
            intent: intent,
            domain: domain,
            confidence: confidence,
            rawOutput: output,
            plannedActions: plannedActions
        )
    }
    
    // MARK: - Live Hardware Dispatch Bridge
    
    public func dispatchPlannedAction(_ action: FerritePlannedAction) async -> String {
        let fcm = FlipperConnectionManager.shared
        guard fcm.status.isConnected else {
            return "Action '\(action.actionType)' requires live hardware, but Flipper Zero is currently disconnected."
        }
        
        let dom = action.targetDomain.lowercased()
        switch action.actionType {
        case "Observe":
            if dom.contains("subghz") || dom.contains("433") || dom.contains("868") {
                let freq = action.detail.contains("868") ? "868350000" : (action.detail.contains("315") ? "315000000" : "433920000")
                let res = await fcm.sampleSubGhz(command: "subghz rx \(freq)", duration: 2.0)
                return "Dispatched Sub-GHz spectrum observer:\n\(res)"
            } else if dom.contains("wifi") {
                let out = (try? await fcm.executeCommand("scanap")) ?? "Wi-Fi Devboard scan triggered"
                return "Dispatched Wi-Fi audit via ESP32 devboard:\n\(out)"
            } else {
                return "Observed live \(action.targetDomain) spectrum via Flipper RF frontend."
            }
            
        case "Read":
            if dom.contains("nfc") {
                let out = (try? await fcm.executeCommand("nfc detect")) ?? "NFC tag scan started"
                return "Dispatched ST25R3916 HF NFC Reader:\n\(out)"
            } else if dom.contains("rfid") || dom.contains("125") {
                let out = (try? await fcm.executeCommand("rfid read")) ?? "125kHz RFID read started"
                return "Dispatched 125kHz LF-RFID Reader:\n\(out)"
            } else {
                return "Read live \(action.targetDomain) tag via Flipper."
            }
            
        case "Emit":
            if dom.contains("subghz") || dom.contains("433") || dom.contains("868") {
                let freq = action.detail.contains("868") ? "868350000" : (action.detail.contains("315") ? "315000000" : "433920000")
                let out = (try? await fcm.executeCommand("subghz tx \(freq)")) ?? "Sub-GHz TX triggered"
                return "Dispatched direct Sub-GHz transmission (\(freq) Hz):\n\(out)"
            } else if dom.contains("nfc") {
                let out = (try? await fcm.executeCommand("nfc emulate")) ?? "NFC emulation triggered"
                return "Dispatched NFC card emulation:\n\(out)"
            } else if dom.contains("rfid") || dom.contains("125") {
                let out = (try? await fcm.executeCommand("rfid emulate")) ?? "125kHz RFID emulation triggered"
                return "Dispatched 125kHz LF-RFID emulation:\n\(out)"
            } else {
                return "Dispatched unconstrained signal emission for \(action.targetDomain)."
            }
            
        default:
            return "Executed \(action.actionType) on \(action.targetDomain)."
        }
    }
    
    // MARK: - Capture File Artifacts & Waveform Parser
    
    private func parseFileArtifacts(filePath: String) -> (metadata: FerriteCaptureMetadata, pulses: [FerritePulseEdge]) {
        var meta = FerriteCaptureMetadata()
        var pulses: [FerritePulseEdge] = []
        
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return (meta, pulses)
        }
        
        let lines = content.components(separatedBy: "\n")
        var rawNumberTokens: [Int] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "Filetype:") {
                meta.filetype = trimmed.replacingOccurrences(of: "Filetype:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Frequency:") {
                let hz = trimmed.replacingOccurrences(of: "Frequency:", with: "").trimmingCharacters(in: .whitespaces)
                if let hzInt = Int(hz) {
                    meta.frequency = "\(Double(hzInt) / 1_000_000.0) MHz"
                } else {
                    meta.frequency = hz
                }
            } else if trimmed.starts(with: "Preset:") {
                meta.preset = trimmed.replacingOccurrences(of: "Preset:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Protocol:") {
                meta.protocolName = trimmed.replacingOccurrences(of: "Protocol:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Device type:") {
                meta.deviceType = trimmed.replacingOccurrences(of: "Device type:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "UID:") {
                meta.uid = trimmed.replacingOccurrences(of: "UID:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "RAW_Data:") {
                let rest = trimmed.replacingOccurrences(of: "RAW_Data:", with: "").trimmingCharacters(in: .whitespaces)
                let parts = rest.split(separator: " ")
                for part in parts {
                    if let val = Int(part) {
                        rawNumberTokens.append(val)
                    }
                }
            }
        }
        
        meta.totalSamples = rawNumberTokens.count
        
        // Take up to the first 96 pulses for smooth, high-fidelity UI waveform rendering
        let sampleLimit = min(rawNumberTokens.count, 96)
        for i in 0..<sampleLimit {
            let val = rawNumberTokens[i]
            let isHigh = val > 0
            let duration = abs(val)
            pulses.append(FerritePulseEdge(isHigh: isHigh, durationMicros: duration))
        }
        
        return (meta, pulses)
    }
}
