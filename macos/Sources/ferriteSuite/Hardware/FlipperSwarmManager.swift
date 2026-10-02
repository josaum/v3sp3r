import Foundation
import SwiftUI

public final class PrimaryFlipperTransport: @unchecked Sendable, FlipperTransport {
    public weak var delegate: (any FlipperTransportDelegate)?
    public var transportType: TransportType { .usb }
    public var isConnected: Bool { true }
    
    public init() {}
    public func connect() async throws {}
    public func disconnect() async {}
    public func send(command: String) async throws -> String {
        return try await FlipperConnectionManager.shared.executeCommand(command)
    }
    public func sendRaw(data: Data) async throws {}
}

@MainActor
@Observable
public final class FlipperSwarmManager {
    public static let shared = FlipperSwarmManager()
    
    public var nodes: [SwarmNode] = []
    public var isScanning: Bool = false
    public var lastBroadcastLog: [String] = []
    
    public init() {
        // Defer discovery so primary FlipperConnectionManager retains exclusive serial access
    }
    
    public func autoDiscoverAndConnect() {
        let ports = SerialTransport.findFlipperPorts()
        let activePort = FlipperConnectionManager.shared.activePort
        
        for (index, port) in ports.enumerated() {
            // Check if node already registered
            if !nodes.contains(where: { $0.portOrIdentifier == port }) {
                let defaultName = "Flipper-\(Character(UnicodeScalar(65 + (index % 26))!))" // Alpha, Bravo, Charlie...
                
                if port == activePort || (activePort == nil && index == 0 && FlipperConnectionManager.shared.status.isConnected) {
                    let node = SwarmNode(
                        customName: "\(defaultName) (Primary)",
                        transportType: .usb,
                        portOrIdentifier: port,
                        transport: PrimaryFlipperTransport()
                    )
                    node.deviceInfo = FlipperConnectionManager.shared.deviceInfo
                    nodes.append(node)
                } else {
                    connectUsbNode(port: port, customName: defaultName)
                }
            }
        }
    }
    
    public func connectUsbNode(port: String, customName: String) {
        let transport = SerialTransport(portPath: port, baudRate: AppSettings.shared.customBaudRate)
        let node = SwarmNode(
            customName: customName,
            transportType: .usb,
            portOrIdentifier: port,
            transport: transport
        )
        
        nodes.append(node)
        
        Task {
            do {
                try await transport.connect()
                node.status = .idle
                await node.refreshInfo()
            } catch {
                node.status = .error(error.localizedDescription)
            }
        }
    }
    
    public func connectBleNode(name: String = "Flipper Zero", customName: String? = nil) {
        let transport = BleTransport(targetDeviceName: name)
        let assignedName = customName ?? "Flipper-BLE-\(nodes.count + 1)"
        let node = SwarmNode(
            customName: assignedName,
            transportType: .ble,
            portOrIdentifier: name,
            transport: transport
        )
        
        nodes.append(node)
        
        Task {
            do {
                try await transport.connect()
                node.status = .idle
                await node.refreshInfo()
            } catch {
                node.status = .error(error.localizedDescription)
            }
        }
    }
    
    public func disconnectNode(id: String) async {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        let node = nodes[index]
        await node.transport.disconnect()
        nodes.remove(at: index)
    }
    
    public func assignRole(nodeId: String, role: AgentRole?) {
        if let node = nodes.first(where: { $0.id == nodeId }) {
            node.assignedRole = role
        }
    }
    
    public func executeOnNode(id: String, command: String) async throws -> String {
        guard let node = nodes.first(where: { $0.id == id }) else {
            throw NSError(domain: "FlipperSwarmManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Node \(id) not found in swarm."])
        }
        return try await node.execute(command)
    }
    
    public func executeOnRole(role: AgentRole, command: String) async throws -> String {
        guard let node = nodes.first(where: { $0.assignedRole == role }) else {
            // Fallback to first available idle node
            if let idleNode = nodes.first(where: { $0.status == .idle }) {
                idleNode.assignedRole = role
                return try await idleNode.execute(command)
            }
            throw NSError(domain: "FlipperSwarmManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Flipper node assigned or available for role \(role.rawValue)."])
        }
        return try await node.execute(command)
    }
    
    public func broadcast(command: String) async -> [String: String] {
        var results: [String: String] = [:]
        await withTaskGroup(of: (String, String).self) { group in
            for node in nodes where node.status.isConnected {
                let name = node.customName
                group.addTask {
                    do {
                        let out = try await node.execute(command)
                        return (name, out)
                    } catch {
                        return (name, "Error: \(error.localizedDescription)")
                    }
                }
            }
            
            for await (name, out) in group {
                results[name] = out
            }
        }
        
        lastBroadcastLog.append("Broadcast: '\(command)' across \(results.count) nodes.")
        return results
    }
    
    public func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for node in nodes {
                group.addTask {
                    await node.refreshInfo()
                }
            }
        }
    }
    
    // MARK: - Synchronized Fleet Operations
    
    public func fleetVibrate() async {
        _ = await broadcast(command: "vibro 1")
        try? await Task.sleep(nanoseconds: 400_000_000)
        _ = await broadcast(command: "vibro 0")
    }
    
    public func fleetLedPulse(r: Int, g: Int, b: Int) async {
        _ = await broadcast(command: "led r \(r)")
        _ = await broadcast(command: "led g \(g)")
        _ = await broadcast(command: "led b \(b)")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        _ = await broadcast(command: "led r 0")
        _ = await broadcast(command: "led g 0")
        _ = await broadcast(command: "led b 0")
    }
}
