import Foundation
import SwiftUI

public enum AgentRole: String, Codable, CaseIterable, Identifiable {
    case commander = "Commander"
    case recon = "Spectre (RF Recon)"
    case forge = "Vulcan (Payload Forge)"
    case cipher = "Cipher (Protocol Analyst)"
    case sentry = "Sentry (Fleet Health)"
    
    public var id: String { rawValue }
    
    public var codename: String {
        switch self {
        case .commander: return "COMMANDER"
        case .recon: return "SPECTRE"
        case .forge: return "VULCAN"
        case .cipher: return "CIPHER"
        case .sentry: return "SENTRY"
        }
    }
    
    public var colorName: String {
        switch self {
        case .commander: return "cyan"
        case .recon: return "green"
        case .forge: return "orange"
        case .cipher: return "purple"
        case .sentry: return "blue"
        }
    }
    
    public var iconName: String {
        switch self {
        case .commander: return "crown.fill"
        case .recon: return "antenna.radiowaves.left.and.right"
        case .forge: return "hammer.fill"
        case .cipher: return "key.fill"
        case .sentry: return "shield.fill"
        }
    }
}

public enum NodeStatus: Equatable {
    case idle
    case busy(task: String)
    case disconnected
    case error(String)
    
    public var isConnected: Bool {
        switch self {
        case .idle, .busy: return true
        default: return false
        }
    }
    
    public var displayText: String {
        switch self {
        case .idle: return "Idle (Ready)"
        case .busy(let task): return "Busy: \(task)"
        case .disconnected: return "Disconnected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

@MainActor
@Observable
public final class SwarmNode: Identifiable {
    public let id: String
    public var customName: String
    public let transportType: TransportType
    public let portOrIdentifier: String
    public var transport: any FlipperTransport
    public var status: NodeStatus = .idle
    public var deviceInfo: FlipperDeviceInfo = FlipperDeviceInfo()
    public var assignedRole: AgentRole?
    public var lastActivity: Date = Date()
    
    public init(
        id: String = UUID().uuidString,
        customName: String,
        transportType: TransportType,
        portOrIdentifier: String,
        transport: any FlipperTransport,
        assignedRole: AgentRole? = nil
    ) {
        self.id = id
        self.customName = customName
        self.transportType = transportType
        self.portOrIdentifier = portOrIdentifier
        self.transport = transport
        self.assignedRole = assignedRole
    }
    
    public func execute(_ command: String) async throws -> String {
        status = .busy(task: command)
        defer {
            if case .busy = status { status = .idle }
            lastActivity = Date()
        }
        return try await transport.send(command: command)
    }
    
    public func refreshInfo() async {
        guard transport.isConnected else { return }
        do {
            let pOut = try await transport.send(command: "power info")
            parsePowerInfo(pOut)
            let dOut = try await transport.send(command: "info device")
            parseDeviceInfo(dOut)
        } catch {
            // failed to refresh
        }
    }
    
    private func parsePowerInfo(_ text: String) {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            if parts[0] == "charge" || parts[0] == "battery" {
                if let pct = Int(parts[1].replacingOccurrences(of: "%", with: "")) {
                    self.deviceInfo.batteryLevel = pct
                }
            } else if parts[0] == "charge_state" || parts[0] == "charging" {
                self.deviceInfo.isCharging = parts[1].lowercased().contains("charg") || parts[1] == "1"
            }
        }
    }
    
    private func parseDeviceInfo(_ text: String) {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            if parts[0] == "firmware_version" || parts[0] == "version" {
                self.deviceInfo.firmwareVersion = parts[1]
            } else if parts[0] == "hardware_model" {
                self.deviceInfo.hardwareModel = parts[1]
            }
        }
    }
}
