import SwiftUI

public struct SwarmFleetView: View {
    @State private var swarm = FlipperSwarmManager.shared
    @State private var broadcastInput: String = ""
    @State private var broadcastResults: [String: String] = [:]
    @State private var isBroadcasting: Bool = false
    @State private var showBroadcastSheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Fleet Header HUD
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(VesperTheme.accentCyan)
                            .frame(width: 64, height: 64)
                            .background(VesperTheme.accentCyan.opacity(0.15))
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Flipper Zero Hardware Swarm")
                                .font(.title2.bold())
                            Text("\(swarm.nodes.count) Connected Node(s) • Multi-Device Parallel Fleet Control")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            swarm.autoDiscoverAndConnect()
                        }) {
                            Label("Scan & Discover USB", systemImage: "arrow.clockwise")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(VesperTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .glassCard()
                
                // Synchronized Fleet Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Synchronized Fleet Operations")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(action: { Task { await swarm.fleetVibrate() } }) {
                            Label("Fleet Buzz (All)", systemImage: "waveform")
                                .padding(10)
                                .background(VesperTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await swarm.fleetLedPulse(r: 0, g: 255, b: 255) } }) {
                            Label("Fleet Cyan Pulse", systemImage: "lightbulb.fill")
                                .padding(10)
                                .background(VesperTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await swarm.fleetLedPulse(r: 255, g: 80, b: 0) } }) {
                            Label("Fleet Orange Pulse", systemImage: "lightbulb.fill")
                                .padding(10)
                                .background(VesperTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await swarm.refreshAll() } }) {
                            Label("Refresh All Battery", systemImage: "battery.100")
                                .padding(10)
                                .background(VesperTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .glassCard()
                
                // Broadcast Command Bar
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fleet Broadcast Terminal")
                        .font(.headline)
                    
                    HStack(spacing: 10) {
                        Text("FLEET >:")
                            .font(.body.monospaced().bold())
                            .foregroundColor(VesperTheme.neonAmber)
                        
                        TextField("Command to broadcast across ALL connected Flippers (e.g. 'info device', 'vibro 1')...", text: $broadcastInput)
                            .textFieldStyle(.plain)
                            .font(.body.monospaced())
                            .onSubmit {
                                submitBroadcast()
                            }
                        
                        Button(action: submitBroadcast) {
                            if isBroadcasting {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Label("Broadcast", systemImage: "paperplane.fill")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(VesperTheme.accentCyan)
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(broadcastInput.isEmpty || isBroadcasting)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    
                    if !broadcastResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Broadcast Responses:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(broadcastResults.keys.sorted()), id: \.self) { nodeName in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Node: \(nodeName)")
                                        .font(.caption.monospaced().bold())
                                        .foregroundColor(VesperTheme.accentCyan)
                                    Text(broadcastResults[nodeName] ?? "")
                                        .font(.caption.monospaced())
                                        .padding(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(10)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .glassCard()
                
                // Node Cards Grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("Active Fleet Nodes (\(swarm.nodes.count))")
                        .font(.headline)
                    
                    if swarm.nodes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "cable.connector.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Flipper Zero devices currently detected.")
                                .foregroundColor(.secondary)
                            Text("Plug in one or more Flippers via USB-C or connect over BLE to expand your swarm.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .glassCard()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                            ForEach(swarm.nodes) { node in
                                NodeCard(node: node)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(VesperTheme.darkBackground)
    }
    
    private func submitBroadcast() {
        let cmd = broadcastInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        
        broadcastInput = ""
        isBroadcasting = true
        
        Task {
            let res = await swarm.broadcast(command: cmd)
            DispatchQueue.main.async {
                self.broadcastResults = res
                self.isBroadcasting = false
            }
        }
    }
}

private struct NodeCard: View {
    @Bindable var node: SwarmNode
    @State private var swarm = FlipperSwarmManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(node.status.isConnected ? VesperTheme.neonGreen : VesperTheme.neonRed)
                    .frame(width: 8, height: 8)
                
                TextField("Node Name", text: $node.customName)
                    .font(.headline)
                    .textFieldStyle(.plain)
                
                Spacer()
                
                Image(systemName: node.transportType.iconName)
                    .foregroundColor(.secondary)
            }
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Status & Battery
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Role Assignment:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Binding(get: { node.assignedRole }, set: { node.assignedRole = $0 })) {
                        Text("Unassigned").tag(nil as AgentRole?)
                        ForEach(AgentRole.allCases) { role in
                            Text(role.rawValue).tag(role as AgentRole?)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: node.deviceInfo.isCharging ? "bolt.batteryblock.fill" : "battery.75percent")
                            .foregroundColor(node.deviceInfo.batteryLevel < 20 ? VesperTheme.neonRed : VesperTheme.neonGreen)
                        Text("\(node.deviceInfo.batteryLevel)%")
                            .font(.caption.monospaced().bold())
                    }
                    Text(node.status.displayText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Port: \(node.portOrIdentifier)")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Quick Node Trigger
            HStack(spacing: 8) {
                Button(action: {
                    Task { _ = try? await node.execute("vibro 1"); try? await Task.sleep(nanoseconds: 300_000_000); _ = try? await node.execute("vibro 0") }
                }) {
                    Text("Ping")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task { await node.refreshInfo() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(VesperTheme.accentCyan)
                
                Spacer()
                
                Button(action: {
                    Task { await swarm.disconnectNode(id: node.id) }
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(VesperTheme.neonRed)
                }
                .buttonStyle(.plain)
                .help("Disconnect Node")
            }
        }
        .padding(14)
        .glassCard()
    }
}
