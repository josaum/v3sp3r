import SwiftUI

public enum FlipperCaseEdition: String, CaseIterable, Identifiable {
    case white = "White Edition"
    case black = "Black Edition"
    public var id: String { rawValue }
}

public struct VirtualFlipperView: View {
    @State private var remote = VirtualFlipperRemote.shared
    @State private var connection = FlipperConnectionManager.shared
    @State private var lastKeyPressed: String = "Ready"
    @State private var isPressingKey: [FlipperKey: Bool] = [:]
    @State private var simulatedScreenMessage: String = "V3SP3R HUD"
    @State private var caseEdition: FlipperCaseEdition = .white
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Title & Casing Switcher
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Virtual Flipper Screen & Remote")
                            .font(.title2.bold())
                        Text("Hardware mirroring and real-time D-pad. Use arrow keys, Return (OK), and Escape (Back).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Edition Picker
                    Picker("Casing", selection: $caseEdition) {
                        ForEach(FlipperCaseEdition.allCases) { edition in
                            Text(edition.rawValue).tag(edition)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // The Flipper Device Body
                VStack(spacing: 0) {
                    // Top shell accent with notification LED
                    HStack {
                        // RGB notification LED
                        Circle()
                            .fill(connection.status.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: connection.status.isConnected ? Color.green : Color.red, radius: 4)
                        
                        Spacer()
                        
                        // Infrared window simulation
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 40, height: 8)
                        
                        Spacer()
                        
                        Text(AppInfo.productName)
                            .font(.system(size: 10, weight: .black).monospaced())
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Screen and Controls Layout
                    HStack(spacing: 36) {
                        // Orange LCD Display (128x64 aspect ratio)
                        VStack(spacing: 6) {
                            ZStack {
                                // LCD Backlight
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.55, blue: 0.0), Color(red: 0.95, green: 0.45, blue: 0.0)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 256, height: 128)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.4), lineWidth: 4)
                                    )
                                    .shadow(color: Color.orange.opacity(0.3), radius: 8)
                                
                                // LCD Content (Black Pixel Matrix)
                                VStack(alignment: .leading, spacing: 4) {
                                    // Status Header
                                    HStack {
                                        Text("VESPER")
                                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        Spacer()
                                        Image(systemName: connection.deviceInfo.isCharging ? "bolt.batteryblock.fill" : "battery.75percent")
                                            .font(.system(size: 10))
                                        Text("\(connection.deviceInfo.batteryLevel)%")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 6)
                                    
                                    Divider().background(Color.black.opacity(0.4))
                                    
                                    // Dolphin / HUD Graphic
                                    HStack(spacing: 12) {
                                        // Retro ASCII Dolphin Icon
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("  /\\_/\\ ")
                                            Text(" ( o.o )")
                                            Text("  > ^ < ")
                                        }
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black)
                                        .padding(.leading, 8)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(connection.deviceInfo.hardwareModel)
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(.black)
                                            Text("FW: \(connection.deviceInfo.firmwareVersion)")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.black.opacity(0.8))
                                            Text("KEY: \(lastKeyPressed)")
                                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .frame(maxHeight: .infinity)
                                    
                                    // Bottom Navigation Bar
                                    HStack {
                                        Text("USB: \(connection.status.isConnected ? "ONLINE" : "OFFLINE")")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        Spacer()
                                        Text("BLE: READY")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    }
                                    .foregroundColor(.black.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 6)
                                }
                                .frame(width: 256, height: 128)
                            }
                        }
                        
                        // D-Pad and Back Button
                        HStack(spacing: 20) {
                            // Circular 5-way D-Pad
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.15, green: 0.17, blue: 0.2))
                                    .frame(width: 140, height: 140)
                                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                                
                                // UP
                                Button(action: { pressKey(.up) }) {
                                    Image(systemName: "triangle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(isPressingKey[.up] == true ? VesperTheme.accentCyan : .white)
                                        .frame(width: 44, height: 36)
                                }
                                .buttonStyle(.plain)
                                .help("Up Arrow Key")
                                .offset(y: -44)
                                
                                // DOWN
                                Button(action: { pressKey(.down) }) {
                                    Image(systemName: "triangle.fill")
                                        .rotationEffect(.degrees(180))
                                        .font(.system(size: 14))
                                        .foregroundColor(isPressingKey[.down] == true ? VesperTheme.accentCyan : .white)
                                        .frame(width: 44, height: 36)
                                }
                                .buttonStyle(.plain)
                                .help("Down Arrow Key")
                                .offset(y: 44)
                                
                                // LEFT
                                Button(action: { pressKey(.left) }) {
                                    Image(systemName: "triangle.fill")
                                        .rotationEffect(.degrees(-90))
                                        .font(.system(size: 14))
                                        .foregroundColor(isPressingKey[.left] == true ? VesperTheme.accentCyan : .white)
                                        .frame(width: 36, height: 44)
                                }
                                .buttonStyle(.plain)
                                .help("Left Arrow Key")
                                .offset(x: -44)
                                
                                // RIGHT
                                Button(action: { pressKey(.right) }) {
                                    Image(systemName: "triangle.fill")
                                        .rotationEffect(.degrees(90))
                                        .font(.system(size: 14))
                                        .foregroundColor(isPressingKey[.right] == true ? VesperTheme.accentCyan : .white)
                                        .frame(width: 36, height: 44)
                                }
                                .buttonStyle(.plain)
                                .help("Right Arrow Key")
                                .offset(x: 44)
                                
                                // CENTER OK BUTTON (Signature Flipper Orange)
                                Button(action: { pressKey(.ok) }) {
                                    Circle()
                                        .fill(VesperTheme.flipperOrange)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                             Text("OK")
                                                 .font(.system(size: 11, weight: .black))
                                                 .foregroundColor(.black)
                                        )
                                        .shadow(color: VesperTheme.flipperOrange.opacity(0.4), radius: 4)
                                }
                                .buttonStyle(.plain)
                                .help("OK / Confirm (Return Key)")
                            }
                            
                            // BACK BUTTON
                            VStack {
                                Spacer()
                                Button(action: { pressKey(.back) }) {
                                    Circle()
                                        .fill(Color(red: 0.22, green: 0.24, blue: 0.28))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "arrow.uturn.backward")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Back Button (Escape)")
                                
                                Text("BACK")
                                    .font(.system(size: 9, weight: .bold).monospaced())
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 140)
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: 580)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(caseEdition == .white ? Color(red: 0.94, green: 0.95, blue: 0.97) : Color(red: 0.12, green: 0.14, blue: 0.17))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(caseEdition == .white ? Color.gray.opacity(0.3) : VesperTheme.subtleBorder, lineWidth: 1.5)
                        )
                )
                .shadow(color: Color.black.opacity(caseEdition == .white ? 0.15 : 0.6), radius: 16, x: 0, y: 8)
                
                // Keyboard Shortcut Reference
                HStack(spacing: 24) {
                    Label("Arrow Keys: D-Pad", systemImage: "keyboard")
                    Label("Return: OK", systemImage: "return")
                    Label("Escape: Back", systemImage: "escape")
                }
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .padding(12)
                .glassCard()
                
                // Active Keyboard Shortcut Triggers
                Group {
                    Button("") { pressKey(.up) }.keyboardShortcut(.upArrow, modifiers: []).opacity(0).frame(width: 0, height: 0)
                    Button("") { pressKey(.down) }.keyboardShortcut(.downArrow, modifiers: []).opacity(0).frame(width: 0, height: 0)
                    Button("") { pressKey(.left) }.keyboardShortcut(.leftArrow, modifiers: []).opacity(0).frame(width: 0, height: 0)
                    Button("") { pressKey(.right) }.keyboardShortcut(.rightArrow, modifiers: []).opacity(0).frame(width: 0, height: 0)
                    Button("") { pressKey(.ok) }.keyboardShortcut(.return, modifiers: []).opacity(0).frame(width: 0, height: 0)
                    Button("") { pressKey(.back) }.keyboardShortcut(.escape, modifiers: []).opacity(0).frame(width: 0, height: 0)
                }
            }
            .padding(20)
        }
        .background(VesperTheme.darkBackground)
    }
    
    private func pressKey(_ key: FlipperKey) {
        lastKeyPressed = key.rawValue.uppercased()
        isPressingKey[key] = true
        
        Task {
            try? await remote.sendKey(key, type: .short)
            try? await Task.sleep(nanoseconds: 150_000_000)
            DispatchQueue.main.async {
                self.isPressingKey[key] = false
            }
        }
    }
}
