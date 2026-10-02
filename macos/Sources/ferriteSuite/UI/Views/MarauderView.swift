import SwiftUI

public struct WirelessAuditView: View {
    @State private var audit = WirelessAuditService.shared
    @State private var rawCommand: String = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header HUD
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "wifi.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                            .frame(width: 64, height: 64)
                            .background(FerriteSuiteTheme.neonGreen.opacity(0.15))
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wireless Security & 802.11 Protocol Auditor")
                                .font(.title2.bold())
                            Text("2.4GHz / 5GHz spectrum observation, packet compliance analysis, and devboard diagnostic bridge.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(audit.currentMode)
                            .font(.caption.monospaced().bold())
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(FerriteSuiteTheme.neonGreen.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(20)
                .glassCard()
                
                // Diagnostic & Audit Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Devboard Diagnostic & Audit Controls")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(action: { Task { await audit.surveyAccessPoints() } }) {
                            Label("Survey APs", systemImage: "wifi")
                                .padding(10)
                                .background(FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await audit.auditBeaconFrames() } }) {
                            Label("Audit Beacons", systemImage: "antenna.radiowaves.left.and.right")
                                .padding(10)
                                .background(FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await audit.auditKeyNegotiation() } }) {
                            Label("Audit Key Handshake", systemImage: "key.fill")
                                .padding(10)
                                .background(FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { await audit.stopSurvey() } }) {
                            Label("Stop Audit", systemImage: "stop.circle.fill")
                                .padding(10)
                                .background(FerriteSuiteTheme.neonRed.opacity(0.2))
                                .foregroundColor(FerriteSuiteTheme.neonRed)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.captivePortal)
                        }) {
                            Label("Portal Architect", systemImage: "network.badge.shield.half.filled")
                                .padding(10)
                                .background(FerriteSuiteTheme.accentCyan.opacity(0.18))
                                .foregroundColor(FerriteSuiteTheme.accentCyan)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .glassCard()
                
                // Audited Access Points Table
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Audited Access Points (\(audit.accessPoints.count))")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(audit.accessPoints) { ap in
                            HStack {
                                Image(systemName: "wifi")
                                    .foregroundColor(signalColor(ap.rssi))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ap.ssid)
                                        .font(.subheadline.bold())
                                    Text("BSSID: \(ap.bssid)")
                                        .font(.caption2.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("CH \(ap.channel)")
                                    .font(.caption.monospaced().bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(4)
                                
                                Text(ap.security)
                                    .font(.caption.monospaced())
                                    .foregroundColor(FerriteSuiteTheme.accentCyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FerriteSuiteTheme.accentCyan.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text("\(ap.rssi) dBm")
                                    .font(.caption.monospaced().bold())
                                    .foregroundColor(signalColor(ap.rssi))
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(10)
                            .background(FerriteSuiteTheme.secondaryCardBackground)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
                .glassCard()
                
                // 802.11 Diagnostic Console
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("802.11 Diagnostic Serial Stream")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            let logs = audit.consoleLogs.joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(logs, forType: .string)
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption.monospaced())
                                .foregroundColor(FerriteSuiteTheme.accentCyan)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            audit.consoleLogs.removeAll()
                        }) {
                            Label("Clear", systemImage: "trash")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            if audit.consoleLogs.isEmpty {
                                Text("Diagnostic stream idle. Initiate an access point survey or enter an audit command below...")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(audit.consoleLogs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: 130)
                    .background(FerriteSuiteTheme.terminalBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                    )
                    
                    // Interactive Diagnostic Command Input
                    HStack(spacing: 8) {
                        TextField("Audit command (e.g. 'scanap', 'sniffpmkid', 'channel 6', 'help')...", text: $rawCommand)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { sendAuditCommand() }
                        
                        Button(action: sendAuditCommand) {
                            Label("Send", systemImage: "arrow.right.circle.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(FerriteSuiteTheme.neonGreen.opacity(0.2))
                                .foregroundColor(FerriteSuiteTheme.neonGreen)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(rawCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(16)
                .glassCard()
            }
            .padding(20)
        }
        .background(FerriteSuiteTheme.darkBackground)
    }
    
    private func signalColor(_ rssi: Int) -> Color {
        if rssi > -60 { return FerriteSuiteTheme.neonGreen }
        if rssi > -75 { return FerriteSuiteTheme.neonAmber }
        return FerriteSuiteTheme.neonRed
    }
    
    private func sendAuditCommand() {
        let cmd = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        rawCommand = ""
        Task {
            await audit.runAuditCommand(cmd)
        }
    }
}

public typealias MarauderView = WirelessAuditView
