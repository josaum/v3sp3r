import SwiftUI

public struct DeviceView: View {
    @State private var connection = FlipperConnectionManager.shared
    @State private var selectedPort: String = ""
    @State private var selectedLedColor: Color = .cyan
    @State private var actionFeedback: String = ""
    
    public init() {}
    
    private let flipperApps = [
        ("Sub-GHz", "Sub-GHz", "antenna.radiowaves.left.and.right"),
        ("Infrared", "Infrared", "rays"),
        ("NFC", "NFC", "wave.3.forward"),
        ("RFID", "125kHz RFID", "creditcard"),
        ("Bad USB", "Bad USB", "keyboard"),
        ("iButton", "iButton", "key.fill")
    ]
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header HUD
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 40))
                            .foregroundColor(FerriteSuiteTheme.flipperOrange)
                            .frame(width: 68, height: 68)
                            .background(FerriteSuiteTheme.flipperOrange.opacity(0.15))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(FerriteSuiteTheme.flipperOrange.opacity(0.3), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(connection.deviceInfo.hardwareModel.isEmpty ? "Flipper Zero" : connection.deviceInfo.hardwareModel)
                                .font(.title2.bold())
                                .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(connection.status.isConnected ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                                    .frame(width: 8, height: 8)
                                Text(connection.status.description)
                                    .font(.subheadline.monospaced())
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Firmware: \(connection.deviceInfo.firmwareVersion) (\(connection.deviceInfo.firmwareBranch)) • Commit: \(connection.deviceInfo.firmwareCommit)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Battery HUD
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: connection.deviceInfo.isCharging ? "bolt.batteryblock.fill" : "battery.75percent")
                                    .foregroundColor(connection.deviceInfo.batteryLevel < 20 ? FerriteSuiteTheme.neonRed : FerriteSuiteTheme.neonGreen)
                                Text("\(connection.deviceInfo.batteryLevel)%")
                                    .font(.title3.bold().monospaced())
                            }
                            Text(connection.deviceInfo.isCharging ? "Charging via USB" : "On Battery")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                Task { await connection.refreshDeviceInfo() }
                            }) {
                                Label("Refresh Specs", systemImage: "arrow.clockwise")
                                    .font(.caption2.bold())
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .glassCard()
                }
                
                // Connection Management Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Connection & Transport")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("USB CDC Serial Port:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedPort) {
                                if connection.availableUsbPorts.isEmpty {
                                    Text("No Flipper USB Detected").tag("")
                                } else {
                                    ForEach(connection.availableUsbPorts, id: \.self) { port in
                                        Text((port as NSString).lastPathComponent).tag(port)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 240)
                        }
                        
                        Button(action: {
                            Task {
                                let port = selectedPort.isEmpty ? nil : selectedPort
                                await connection.connectUsb(portPath: port)
                            }
                        }) {
                            Label("Connect USB", systemImage: "cable.connector")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(FerriteSuiteTheme.flipperOrange)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            Task { await connection.connectBle() }
                        }) {
                            Label("Connect BLE", systemImage: "antenna.radiowaves.left.and.right")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(FerriteSuiteTheme.cyberPurple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        if connection.status.isConnected {
                            Button(action: {
                                Task { await connection.disconnect() }
                            }) {
                                Text("Disconnect")
                                    .foregroundColor(FerriteSuiteTheme.neonRed)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .glassCard()
                
                // Detailed Hardware Telemetry Grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("Hardware Architecture & Telemetry")
                        .font(.headline)
                        .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                        SpecPill(title: "MODEL", value: connection.deviceInfo.hardwareModel.isEmpty ? "Flipper Zero" : connection.deviceInfo.hardwareModel, icon: "cpu")
                        SpecPill(title: "FIRMWARE", value: connection.deviceInfo.firmwareVersion.isEmpty ? "Unleashed" : connection.deviceInfo.firmwareVersion, icon: "cube.fill")
                        SpecPill(title: "COMMIT", value: connection.deviceInfo.firmwareCommit.isEmpty ? "603f90d0" : connection.deviceInfo.firmwareCommit, icon: "number")
                        SpecPill(title: "RADIO MODE", value: connection.deviceInfo.radioMode.isEmpty ? "Stack Active" : connection.deviceInfo.radioMode, icon: "antenna.radiowaves.left.and.right")
                        SpecPill(title: "LINK TRANSPORT", value: connection.status.isConnected ? "USB CDC Serial" : "Offline", icon: "cable.connector")
                        SpecPill(title: "BATTERY GAUGE", value: "\(connection.deviceInfo.batteryLevel)% (\(connection.deviceInfo.isCharging ? "Charging" : "Discharging"))", icon: "bolt.fill")
                    }
                }
                .padding(16)
                .glassCard()
                
                // Hardware Controls & Power State
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Actuators & Power Management")
                            .font(.headline)
                            .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                        Spacer()
                    }
                    
                    // LED & Haptics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LED & HAPTIC ACTUATORS:")
                            .font(.system(size: 9.5, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                runCommand("vibro 1")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.runCommand("vibro 0") }
                            }) {
                                Label("Vibrate 400ms", systemImage: "waveform")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { runCommand("led r 0"); runCommand("led g 255"); runCommand("led b 255") }) {
                                Label("Cyan", systemImage: "circle.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(Color.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { runCommand("led r 255"); runCommand("led g 80"); runCommand("led b 0") }) {
                                Label("Orange", systemImage: "circle.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(FerriteSuiteTheme.flipperOrange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { runCommand("led r 0"); runCommand("led g 255"); runCommand("led b 0") }) {
                                Label("Green", systemImage: "circle.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(FerriteSuiteTheme.neonGreen)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { runCommand("led r 180"); runCommand("led g 0"); runCommand("led b 255") }) {
                                Label("Purple", systemImage: "circle.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(FerriteSuiteTheme.cyberPurple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { runCommand("led r 0"); runCommand("led g 0"); runCommand("led b 0") }) {
                                Label("Off", systemImage: "lightbulb.slash")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider().background(FerriteSuiteTheme.subtleBorder)
                    
                    // Power Management
                    VStack(alignment: .leading, spacing: 8) {
                        Text("POWER OPERATIONS:")
                            .font(.system(size: 9.5, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            Button(action: { runCommand("power reboot") }) {
                                Label("Reboot Flipper", systemImage: "arrow.clockwise.circle")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .foregroundColor(FerriteSuiteTheme.neonAmber)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("Soft reboot Flipper Zero operating system")
                            
                            Button(action: { runCommand("power reboot2dfu") }) {
                                Label("Reboot to DFU Bootloader", systemImage: "bolt.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .foregroundColor(FerriteSuiteTheme.cyberPurple)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("Reboot Flipper into DFU Bootloader mode for flashing")
                            
                            Button(action: { runCommand("power off") }) {
                                Label("Power Off", systemImage: "power")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(FerriteSuiteTheme.secondaryCardBackground)
                                    .foregroundColor(FerriteSuiteTheme.neonRed)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("Safely power down Flipper Zero hardware")
                        }
                    }
                }
                .padding(16)
                .glassCard()
                
                // App Launcher Grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("Launch Flipper Application")
                        .font(.headline)
                        .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                        ForEach(flipperApps, id: \.0) { app in
                            Button(action: {
                                runCommand("loader open \(app.1)")
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: app.2)
                                        .font(.title2)
                                        .foregroundColor(FerriteSuiteTheme.accentCyan)
                                    Text(app.0)
                                        .font(.caption.bold())
                                        .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .glassCard()
                
                if !actionFeedback.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(FerriteSuiteTheme.neonGreen)
                                .font(.caption)
                            Text("CLI Execution Response:")
                                .font(.system(size: 9.5, weight: .bold).monospaced())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(actionFeedback, forType: .string)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.system(size: 9.5).monospaced())
                                    .foregroundColor(FerriteSuiteTheme.accentCyan)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(actionFeedback)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FerriteSuiteTheme.terminalBackground)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                            )
                    }
                    .padding(14)
                    .glassCard()
                }
            }
            .padding(20)
        }
        .background(FerriteSuiteTheme.darkBackground)
        .onAppear {
            if let first = connection.availableUsbPorts.first {
                selectedPort = first
            }
        }
    }
    
    private func runCommand(_ cmd: String) {
        Task {
            do {
                let res = try await connection.executeCommand(cmd)
                DispatchQueue.main.async {
                    self.actionFeedback = "Output for '\(cmd)':\n\(res)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.actionFeedback = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct SpecPill: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(FerriteSuiteTheme.accentCyan)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(FerriteSuiteTheme.secondaryCardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
        )
    }
}
