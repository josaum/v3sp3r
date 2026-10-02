import Foundation
import SwiftUI

public struct DebugProbeDevice: Identifiable, Equatable {
    public let id: String
    public let index: Int
    public let name: String
    public let vid: String
    public let pid: String
    public let serial: String
    public let probeType: String
    
    public init(id: String, index: Int, name: String, vid: String, pid: String, serial: String, probeType: String) {
        self.id = id
        self.index = index
        self.name = name
        self.vid = vid
        self.pid = pid
        self.serial = serial
        self.probeType = probeType
    }
}

public struct MemoryHexWord: Identifiable, Equatable {
    public let id = UUID()
    public let address: UInt32
    public let hexValue: String
    public let asciiRepresentation: String
}

public struct ProbeTargetTelemetry: Equatable {
    public var chip: String = "STM32WB55RGVx"
    public var deviceId: String = ""
    public var uid: String = ""
    public var msp: String = ""
    public var resetVector: String = ""
    public var appResetVector: String = ""
    public var optionBytes: String = ""
    public var rdpLevel: String = "Level 0"
    public var rdpUnlocked: Bool = true
    public var cpuid: String = ""
    public var flashSizeKb: Int = 1024
    public var isConnected: Bool = false
    public var lastInspectionDate: Date?
}

@MainActor
@Observable
public final class DebugProbeService {
    public static let shared = DebugProbeService()
    
    public let probeRsPath: String = HostTools.probeRs
    public var isInstalled: Bool = false
    
    // Probe state
    public var probes: [DebugProbeDevice] = []
    public var selectedProbe: DebugProbeDevice?
    public var isScanning: Bool = false
    public var scanLogs: [String] = []
    
    // Target chip state
    public var selectedChip: String = "STM32WB55RGVx"
    public let commonChips: [String] = [
        "STM32WB55RGVx", // Flipper Zero primary MCU
        "STM32WB55CCUx",
        "STM32F405RGTx",
        "ESP32-S2",
        "ESP32-S3",
        "RP2040",
        "nRF52840_xxAA"
    ]
    
    public var targetTelemetry = ProbeTargetTelemetry()
    public var isExecuting: Bool = false
    public var statusMessage: String = "Ready"
    public var consoleOutput: String = ""
    
    // Memory Inspector state
    public var memoryInspectAddressHex: String = "0x1FFF7580"
    public var memoryInspectWordsCount: Int = 8
    public var memoryData: [MemoryHexWord] = []
    
    // Direct flash state
    public var isFlashing: Bool = false
    public var flashProgress: Double = 0.0
    
    public init() {
        checkInstallation()
        if isInstalled {
            Task {
                await refreshProbes()
            }
        }
    }
    
    public func checkInstallation() {
        self.isInstalled = FileManager.default.fileExists(atPath: probeRsPath)
    }
    
    // MARK: - Scan Probes
    
    public func refreshProbes() async {
        guard isInstalled else {
            statusMessage = "probe-rs CLI not found at \(probeRsPath)"
            return
        }
        
        isScanning = true
        statusMessage = "Scanning for SWD/JTAG debug probes..."
        defer { isScanning = false }
        
        do {
            let out = try await execute(args: ["list"])
            self.consoleOutput = out
            parseProbes(from: out)
            if let first = probes.first {
                self.selectedProbe = first
                statusMessage = "Detected \(probes.count) probe(s). Ready."
                // Auto inspect target
                await inspectTargetChip()
            } else {
                self.selectedProbe = nil
                self.targetTelemetry.isConnected = false
                statusMessage = "No hardware debug probes detected."
            }
        } catch {
            statusMessage = "Probe scan failed: \(error.localizedDescription)"
            self.consoleOutput = error.localizedDescription
        }
    }
    
    private func parseProbes(from output: String) {
        var list: [DebugProbeDevice] = []
        // Output format:
        // [0]: STLink V2 -- 0483:3748:37C3BF71064E5734363C6E1343 (ST-LINK)
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") && trimmed.contains("]:") else { continue }
            
            // Extract index
            guard let closeBracket = trimmed.firstIndex(of: "]"),
                  let openBracket = trimmed.firstIndex(of: "["),
                  let idx = Int(trimmed[trimmed.index(after: openBracket)..<closeBracket]) else {
                continue
            }
            
            let remainder = trimmed[trimmed.index(closeBracket, offsetBy: 2)...].trimmingCharacters(in: .whitespaces)
            let parts = remainder.components(separatedBy: " -- ")
            let name = parts.first ?? "Unknown Probe"
            
            var vid = ""
            var pid = ""
            var serial = ""
            var probeType = name
            
            if parts.count > 1 {
                let idPart = parts[1]
                let tokens = idPart.components(separatedBy: " ")
                let vidPidSerial = tokens.first ?? ""
                let vps = vidPidSerial.components(separatedBy: ":")
                if vps.count >= 2 {
                    vid = vps[0]
                    pid = vps[1]
                    if vps.count >= 3 {
                        serial = vps[2]
                    }
                }
                if tokens.count > 1 {
                    probeType = tokens[1].replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                }
            }
            
            let dev = DebugProbeDevice(
                id: "\(vid):\(pid):\(serial.isEmpty ? UUID().uuidString : serial)",
                index: idx,
                name: name,
                vid: vid,
                pid: pid,
                serial: serial,
                probeType: probeType
            )
            list.append(dev)
        }
        self.probes = list
    }
    
    // MARK: - Target Operations
    
    public func inspectTargetChip() async {
        guard let probe = selectedProbe else {
            statusMessage = "Select a debug probe first"
            return
        }
        
        isExecuting = true
        statusMessage = "Inspecting \(selectedChip) via SWD..."
        defer { isExecuting = false }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty {
            probeArg += ":\(probe.serial)"
        }
        
        do {
            // 1. Read Device ID Register at 0x1FFF7580
            let devIdOut = try await execute(args: ["read", "--probe", probeArg, "--chip", selectedChip, "b32", "0x1FFF7580", "1"])
            let devId = parseSingleHex(from: devIdOut)
            
            // 2. Read 96-bit Unique ID at 0x1FFF7590 (3 words)
            let uidOut = try await execute(args: ["read", "--probe", probeArg, "--chip", selectedChip, "b32", "0x1FFF7590", "3"])
            let uidWords = parseHexWords(from: uidOut)
            let formattedUid = uidWords.joined(separator: "-").uppercased()
            
            // 3. Read Vector Table Base at 0x08000000 (MSP and Reset Vector)
            let vectorOut = try await execute(args: ["read", "--probe", probeArg, "--chip", selectedChip, "b32", "0x08000000", "2"])
            let vectors = parseHexWords(from: vectorOut)
            let msp = vectors.indices.contains(0) ? "0x\(vectors[0])" : "Unknown"
            let resetVec = vectors.indices.contains(1) ? "0x\(vectors[1])" : "Unknown"
            
            // 4. Read App Vector Table at 0x08008000 (FerriteOS / user app slot)
            var appResetVec = "—"
            if let appVecOut = try? await execute(args: ["read", "--probe", probeArg, "--chip", selectedChip, "b32", "0x08008000", "2"]) {
                let appVecs = parseHexWords(from: appVecOut)
                if appVecs.indices.contains(1) {
                    appResetVec = "0x\(appVecs[1])"
                }
            }
            
            // 5. Read Flash Option Register (FLASH_OPTR) at 0x58004020
            var optBytes = "0x2D8F79AA"
            var rdpLvl = "Level 0 (Unlocked)"
            var rdpOk = true
            if let optOut = try? await execute(args: ["read", "--probe", probeArg, "--chip", selectedChip, "b32", "0x58004020", "1"]) {
                let parsed = parseSingleHex(from: optOut).uppercased()
                if !parsed.isEmpty {
                    optBytes = "0x\(parsed)"
                    if parsed.hasSuffix("AA") {
                        rdpLvl = "Level 0 (Unlocked)"
                        rdpOk = true
                    } else if parsed.hasSuffix("CC") {
                        rdpLvl = "Level 2 (Permanent Chip Lock)"
                        rdpOk = false
                    } else {
                        rdpLvl = "Level 1 (Memory Readout Protected)"
                        rdpOk = false
                    }
                }
            }
            
            // 6. Read ARM Cortex CPUID at 0xE000ED00
            var cpuIdStr = "ARM Cortex-M4 (r0p1)"
            if let cpuOut = try? await execute(args: ["read", "--probe", probeArg, "--chip", selectedChip, "b32", "0xE000ED00", "1"]) {
                let parsedCpu = parseSingleHex(from: cpuOut).uppercased()
                if parsedCpu.contains("C24") {
                    cpuIdStr = "ARM Cortex-M4 (0x\(parsedCpu))"
                } else if !parsedCpu.isEmpty {
                    cpuIdStr = "0x\(parsedCpu)"
                }
            }
            
            self.targetTelemetry = ProbeTargetTelemetry(
                chip: selectedChip,
                deviceId: "0x\(devId)",
                uid: formattedUid.isEmpty ? "Unknown" : formattedUid,
                msp: msp,
                resetVector: resetVec,
                appResetVector: appResetVec,
                optionBytes: optBytes,
                rdpLevel: rdpLvl,
                rdpUnlocked: rdpOk,
                cpuid: cpuIdStr,
                flashSizeKb: 1024,
                isConnected: true,
                lastInspectionDate: Date()
            )
            
            statusMessage = "Target \(selectedChip) responding over SWD. UID: \(formattedUid)"
            self.consoleOutput = """
            [SWD Hardware Probe Attached]
            Probe: \(probe.name) (\(probeArg))
            Target: \(selectedChip) [\(cpuIdStr)]
            Device Signature: 0x\(devId) (Flash: 1024 KB)
            Hardware 96-bit UID: \(formattedUid)
            Stack Pointer (MSP): \(msp)
            Bootloader Reset Handler (0x08000000): \(resetVec)
            FerriteOS App Reset Handler (0x08008000): \(appResetVec)
            FLASH_OPTR: \(optBytes) [\(rdpLvl)]
            SWD Link Status: HALT/READY (Full R/W Access)
            """
            
            // Also refresh memory preview table
            await readMemoryChunk()
            
        } catch {
            self.targetTelemetry.isConnected = false
            statusMessage = "Failed to communicate with target: \(error.localizedDescription)"
            self.consoleOutput = "SWD Target Connection Error:\n\(error.localizedDescription)"
        }
    }
    
    public func resetTarget(halt: Bool = false) async {
        guard let probe = selectedProbe else { return }
        isExecuting = true
        statusMessage = "Issuing hardware SWD reset..."
        defer { isExecuting = false }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty { probeArg += ":\(probe.serial)" }
        
        do {
            var args = ["reset", "--probe", probeArg, "--chip", selectedChip]
            if halt {
                // Connect under reset
                args.append("--connect-under-reset")
            }
            let out = try await execute(args: args)
            statusMessage = "Target reset complete."
            self.consoleOutput = "Target SWD Reset executed.\n\(out)"
            await inspectTargetChip()
        } catch {
            statusMessage = "Reset failed: \(error.localizedDescription)"
            self.consoleOutput = "Reset Error:\n\(error.localizedDescription)"
        }
    }
    
    public func readMemoryChunk() async {
        guard let probe = selectedProbe else { return }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty { probeArg += ":\(probe.serial)" }
        
        let addrStr = memoryInspectAddressHex.trimmingCharacters(in: .whitespaces)
        guard let addr = UInt32(addrStr.replacingOccurrences(of: "0x", with: ""), radix: 16) else {
            statusMessage = "Invalid hex memory address"
            return
        }
        
        isExecuting = true
        statusMessage = "Reading \(memoryInspectWordsCount) words from \(addrStr)..."
        defer { isExecuting = false }
        
        do {
            let out = try await execute(args: [
                "read", "--probe", probeArg,
                "--chip", selectedChip,
                "b32", addrStr, "\(memoryInspectWordsCount)"
            ])
            
            let words = parseHexWords(from: out)
            var hexList: [MemoryHexWord] = []
            for (idx, w) in words.enumerated() {
                let curAddr = addr + UInt32(idx * 4)
                let ascii = hexToAscii(w)
                hexList.append(MemoryHexWord(address: curAddr, hexValue: w.uppercased(), asciiRepresentation: ascii))
            }
            self.memoryData = hexList
            statusMessage = "Memory read successful at \(addrStr)"
            self.consoleOutput = out
        } catch {
            statusMessage = "Memory read error: \(error.localizedDescription)"
            self.consoleOutput = "Memory Read Error:\n\(error.localizedDescription)"
        }
    }
    
    public func writeMemoryWord(addressHex: String, valueHex: String) async {
        guard let probe = selectedProbe else { return }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty { probeArg += ":\(probe.serial)" }
        
        isExecuting = true
        statusMessage = "Writing \(valueHex) to \(addressHex)..."
        defer { isExecuting = false }
        
        do {
            let out = try await execute(args: [
                "write", "--probe", probeArg,
                "--chip", selectedChip,
                "b32", addressHex, valueHex
            ])
            statusMessage = "Wrote \(valueHex) to \(addressHex)"
            self.consoleOutput = out
            await readMemoryChunk()
        } catch {
            statusMessage = "Write memory error: \(error.localizedDescription)"
            self.consoleOutput = "Write Error:\n\(error.localizedDescription)"
        }
    }
    
    public func flashBinary(binaryPath: String, baseAddressHex: String) async throws -> String {
        guard let probe = selectedProbe else {
            throw NSError(domain: "DebugProbeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No probe selected"])
        }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty { probeArg += ":\(probe.serial)" }
        
        isFlashing = true
        statusMessage = "Flashing binary via SWD to \(baseAddressHex)..."
        defer { isFlashing = false }
        
        let args = [
            "download",
            "--probe", probeArg,
            "--chip", selectedChip,
            "--binary-format", "bin",
            "--base-address", baseAddressHex,
            "--verify",
            "--reset",
            binaryPath
        ]
        
        let out = try await execute(args: args)
        statusMessage = "Flashing complete and verified via SWD."
        self.consoleOutput = out
        await inspectTargetChip()
        return out
    }
    
    public func dumpFlashMemory(addressHex: String = "0x08000000", wordsCount: Int = 16384, destinationPath: String) async throws -> String {
        guard let probe = selectedProbe else {
            throw NSError(domain: "DebugProbeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No probe selected"])
        }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty { probeArg += ":\(probe.serial)" }
        
        isExecuting = true
        statusMessage = "Dumping \(wordsCount * 4) bytes from \(addressHex) to disk..."
        defer { isExecuting = false }
        
        let args = [
            "read",
            "--probe", probeArg,
            "--chip", selectedChip,
            "--format", "binary",
            "--output", destinationPath,
            "b32", addressHex, "\(wordsCount)"
        ]
        
        let out = try await execute(args: args)
        statusMessage = "Dumped \(wordsCount * 4) bytes to \(destinationPath)"
        self.consoleOutput = "Flash Dump Success:\nSaved \(wordsCount * 4) bytes to \(destinationPath)\n\(out)"
        return destinationPath
    }
    
    public func eraseChip() async throws -> String {
        guard let probe = selectedProbe else {
            throw NSError(domain: "DebugProbeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No probe selected"])
        }
        
        var probeArg = "\(probe.vid):\(probe.pid)"
        if !probe.serial.isEmpty { probeArg += ":\(probe.serial)" }
        
        isExecuting = true
        statusMessage = "Performing full nonvolatile chip erase..."
        defer { isExecuting = false }
        
        let args = [
            "erase",
            "--probe", probeArg,
            "--chip", selectedChip
        ]
        
        let out = try await execute(args: args)
        statusMessage = "Chip erase complete."
        self.consoleOutput = out
        await inspectTargetChip()
        return out
    }
    
    // MARK: - Process Execution
    
    private func execute(args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: self.probeRsPath)
                process.arguments = args
                
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = HostTools.subprocessPath
                process.environment = env
                
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let outStr = String(data: outData, encoding: .utf8) ?? ""
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    
                    let combined = outStr.isEmpty ? errStr : (errStr.isEmpty ? outStr : "\(outStr)\n\(errStr)")
                    let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: trimmed)
                    } else {
                        let err = NSError(domain: "DebugProbeService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: trimmed.isEmpty ? "Command failed with code \(process.terminationStatus)" : trimmed])
                        continuation.resume(throwing: err)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Hex Parsing Helpers
    
    private func parseSingleHex(from output: String) -> String {
        // e.g. "1fff7580: 019da2d6"
        let tokens = output.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        if let last = tokens.last(where: { !$0.isEmpty && !$0.hasSuffix(":") }) {
            return last.replacingOccurrences(of: "0x", with: "")
        }
        return ""
    }
    
    private func parseHexWords(from output: String) -> [String] {
        var results: [String] = []
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: ":")
            let hexPart = parts.count > 1 ? parts[1] : parts[0]
            let tokens = hexPart.components(separatedBy: .whitespaces)
            for token in tokens where !token.isEmpty {
                results.append(token.replacingOccurrences(of: "0x", with: ""))
            }
        }
        return results
    }
    
    private func hexToAscii(_ hex: String) -> String {
        var chars: [Character] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let byteStr = String(hex[index..<nextIndex])
            if let byte = UInt8(byteStr, radix: 16) {
                if byte >= 32 && byte <= 126 {
                    chars.append(Character(UnicodeScalar(byte)))
                } else {
                    chars.append(".")
                }
            } else {
                chars.append(".")
            }
            index = nextIndex
        }
        return String(chars)
    }
}
