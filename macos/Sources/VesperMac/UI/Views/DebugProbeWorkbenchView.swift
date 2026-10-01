import SwiftUI

public struct DebugProbeWorkbenchView: View {
    @State private var probeService = DebugProbeService.shared
    @State private var ferrite = FerriteOSService.shared
    @State private var newWriteAddress: String = "0x20000000"
    @State private var newWriteValue: String = "0xCAFEBABE"
    @State private var showEraseAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider().background(VesperTheme.subtleBorder)
            
            ScrollView {
                VStack(spacing: 18) {
                    // Probe Selector & Target Telemetry Row
                    HStack(alignment: .top, spacing: 16) {
                        probeSelectionCard
                        targetTelemetryCard
                    }
                    
                    // Hardware Actions Toolbar
                    hardwareActionsCard
                    
                    // Memory Inspector & Live Read/Write Card
                    memoryInspectorCard
                    
                    // Raw Console & Execution Telemetry
                    rawConsoleCard
                }
                .padding(20)
            }
        }
        .background(VesperTheme.darkBackground)
        .alert("Erase Nonvolatile Chip Flash?", isPresented: $showEraseAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Erase All Flash", role: .destructive) {
                Task {
                    _ = try? await probeService.eraseChip()
                }
            }
        } message: {
            Text("This will wipe all flash sectors on the \(probeService.selectedChip) via SWD mass-erase. Are you sure you want to proceed?")
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VesperTheme.accentCyan.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("SWD / JTAG Hardware Probe Lab")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    
                    Text("probe-rs 0.29")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.accentCyan.opacity(0.2))
                        .foregroundColor(VesperTheme.accentCyan)
                        .cornerRadius(4)
                }
                Text("Direct bare-metal debugging, memory extraction, registers inspection, and flash unbricking.")
                    .font(.caption)
                    .foregroundColor(VesperTheme.secondaryTextColor)
            }
            
            Spacer()
            
            // Status Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(probeService.targetTelemetry.isConnected ? VesperTheme.neonGreen : (probeService.selectedProbe != nil ? VesperTheme.neonAmber : VesperTheme.neonRed))
                    .frame(width: 8, height: 8)
                Text(probeService.statusMessage)
                    .font(.caption.monospaced())
                    .foregroundColor(VesperTheme.primaryTextColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(VesperTheme.secondaryCardBackground)
            .cornerRadius(8)
            
            Button(action: {
                Task { await probeService.refreshProbes() }
            }) {
                HStack(spacing: 6) {
                    if probeService.isScanning {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Rescan Probes")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(VesperTheme.accentCyan.opacity(0.15))
                .foregroundColor(VesperTheme.accentCyan)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(VesperTheme.accentCyan.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(probeService.isScanning || probeService.isExecuting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(VesperTheme.cardBackground)
    }
    
    // MARK: - Probe Selection Card
    
    private var probeSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cable.connector.horizontal")
                    .foregroundColor(VesperTheme.accentCyan)
                Text("Connected Probes (\(probeService.probes.count))")
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                Spacer()
            }
            
            if probeService.probes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(VesperTheme.neonAmber)
                    Text("No hardware debug probes found")
                        .font(.caption.bold())
                    Text("Connect an ST-Link V2/V3, J-Link, CMSIS-DAP, or BlackMagic Probe via USB.")
                        .font(.caption2)
                        .foregroundColor(VesperTheme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(VesperTheme.secondaryCardBackground.opacity(0.4))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(probeService.probes) { probe in
                        let isSelected = probeService.selectedProbe?.id == probe.id
                        Button(action: {
                            probeService.selectedProbe = probe
                            Task { await probeService.inspectTargetChip() }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? VesperTheme.neonGreen : VesperTheme.secondaryTextColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(probe.name)
                                            .font(.caption.bold())
                                            .foregroundColor(VesperTheme.primaryTextColor)
                                        Spacer()
                                        Text("[\(probe.probeType)]")
                                            .font(.caption2.monospaced())
                                            .foregroundColor(VesperTheme.accentCyan)
                                    }
                                    Text("VID:PID \(probe.vid):\(probe.pid) • S/N: \(probe.serial.isEmpty ? "Direct" : probe.serial)")
                                        .font(.system(size: 9.5).monospaced())
                                        .foregroundColor(VesperTheme.secondaryTextColor)
                                }
                            }
                            .padding(10)
                            .background(isSelected ? VesperTheme.accentCyan.opacity(0.12) : VesperTheme.secondaryCardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? VesperTheme.accentCyan : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Target Chip Selector
            HStack(spacing: 8) {
                Text("Target MCU:")
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.secondaryTextColor)
                Picker("", selection: $probeService.selectedChip) {
                    ForEach(probeService.commonChips, id: \.self) { chip in
                        Text(chip).tag(chip)
                    }
                }
                .pickerStyle(.menu)
                .tint(VesperTheme.accentCyan)
                .onChange(of: probeService.selectedChip) { _, _ in
                    Task { await probeService.inspectTargetChip() }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(VesperTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Target Telemetry Card
    
    private var targetTelemetryCard: some View {
        let t = probeService.targetTelemetry
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(VesperTheme.neonGreen)
                Text("Target Telemetry: \(t.chip)")
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                Spacer()
                if t.isConnected {
                    Text("SWD SYNCHRONIZED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.neonGreen.opacity(0.2))
                        .foregroundColor(VesperTheme.neonGreen)
                        .cornerRadius(4)
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                telemetryCell(title: "Device Signature", value: t.deviceId.isEmpty ? "—" : t.deviceId, icon: "signature")
                telemetryCell(title: "Option Bytes", value: t.optionBytes.isEmpty ? "—" : t.optionBytes, icon: "lock.shield")
                telemetryCell(title: "Main Stack Pointer", value: t.msp.isEmpty ? "—" : t.msp, icon: "arrow.down.to.line")
                telemetryCell(title: "Reset Vector", value: t.resetVector.isEmpty ? "—" : t.resetVector, icon: "arrow.uturn.right")
            }
            
            // 96-bit Unique ID Banner
            VStack(alignment: .leading, spacing: 4) {
                Text("96-Bit Silicon Unique ID (UID):")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(VesperTheme.secondaryTextColor)
                Text(t.uid.isEmpty ? "Not connected or read error" : t.uid)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(t.uid.isEmpty ? VesperTheme.secondaryTextColor : VesperTheme.accentCyan)
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VesperTheme.secondaryCardBackground)
            .cornerRadius(8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(VesperTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
        )
    }
    
    private func telemetryCell(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(VesperTheme.secondaryTextColor)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VesperTheme.secondaryTextColor)
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(VesperTheme.primaryTextColor)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VesperTheme.secondaryCardBackground)
        .cornerRadius(6)
    }
    
    // MARK: - Hardware Actions Toolbar
    
    private var hardwareActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundColor(VesperTheme.neonAmber)
                Text("SWD Direct Hardware Actions")
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Inspect Registers
                actionButton(title: "Inspect Target", icon: "magnifyingglass", color: VesperTheme.accentCyan) {
                    Task { await probeService.inspectTargetChip() }
                }
                
                // Hardware Reset
                actionButton(title: "Hardware Reset", icon: "arrow.counterclockwise", color: VesperTheme.neonAmber) {
                    Task { await probeService.resetTarget(halt: false) }
                }
                
                // Reset & Halt
                actionButton(title: "Connect Under Reset", icon: "pause.fill", color: .purple) {
                    Task { await probeService.resetTarget(halt: true) }
                }
                
                // Flash FerriteOS App
                actionButton(title: "Flash FerriteOS (App)", icon: "bolt.fill", color: VesperTheme.neonGreen) {
                    Task {
                        _ = try? await probeService.flashBinary(
                            binaryPath: ferrite.firmwareAppBinPath,
                            baseAddressHex: "0x08008000"
                        )
                    }
                }
                
                // Flash FerriteOS Standalone
                actionButton(title: "Flash Standalone", icon: "flame.fill", color: .orange) {
                    Task {
                        _ = try? await probeService.flashBinary(
                            binaryPath: ferrite.firmwareBinPath,
                            baseAddressHex: "0x08000000"
                        )
                    }
                }
                
                // Mass Erase
                actionButton(title: "Mass Erase Flash", icon: "trash.fill", color: VesperTheme.neonRed) {
                    showEraseAlert = true
                }
            }
        }
        .padding(16)
        .background(VesperTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
        )
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(probeService.selectedProbe == nil || probeService.isExecuting)
    }
    
    // MARK: - Memory Inspector Card
    
    private var memoryInspectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(VesperTheme.accentCyan)
                Text("Memory & Register Inspector")
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                
                Spacer()
                
                // Quick Address Jump Buttons
                quickJumpButton(name: "Flash Base", addr: "0x08000000")
                quickJumpButton(name: "App Slot", addr: "0x08008000")
                quickJumpButton(name: "SRAM Base", addr: "0x20000000")
                quickJumpButton(name: "Device ID", addr: "0x1FFF7580")
                quickJumpButton(name: "Option Bytes", addr: "0x1FFF7800")
            }
            
            // Read Controls
            HStack(spacing: 10) {
                Text("Address:")
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.secondaryTextColor)
                TextField("0x1FFF7580", text: $probeService.memoryInspectAddressHex)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(6)
                    .frame(width: 120)
                    .background(VesperTheme.secondaryCardBackground)
                    .cornerRadius(6)
                
                Text("Words:")
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.secondaryTextColor)
                Stepper("\(probeService.memoryInspectWordsCount)", value: $probeService.memoryInspectWordsCount, in: 1...64)
                    .font(.caption.monospaced())
                
                Button("Read Memory") {
                    Task { await probeService.readMemoryChunk() }
                }
                .buttonStyle(.borderedProminent)
                .tint(VesperTheme.accentCyan)
                .controlSize(.small)
                
                Spacer()
                
                // Write to RAM control
                HStack(spacing: 6) {
                    TextField("Addr", text: $newWriteAddress)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(5)
                        .frame(width: 90)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(6)
                    TextField("Val", text: $newWriteValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(5)
                        .frame(width: 90)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(6)
                    Button("Write RAM") {
                        Task {
                            await probeService.writeMemoryWord(addressHex: newWriteAddress, valueHex: newWriteValue)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // Hex Table Display
            if probeService.memoryData.isEmpty {
                Text("No memory read executed yet.")
                    .font(.caption)
                    .foregroundColor(VesperTheme.secondaryTextColor)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    // Header
                    HStack {
                        Text("ADDRESS")
                            .frame(width: 90, alignment: .leading)
                        Text("32-BIT HEX WORD")
                            .frame(width: 140, alignment: .leading)
                        Text("ASCII")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(VesperTheme.secondaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VesperTheme.secondaryCardBackground.opacity(0.5))
                    
                    ForEach(probeService.memoryData) { item in
                        HStack {
                            Text(String(format: "0x%08X", item.address))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(VesperTheme.accentCyan)
                                .frame(width: 90, alignment: .leading)
                            
                            Text(item.hexValue)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(VesperTheme.primaryTextColor)
                                .frame(width: 140, alignment: .leading)
                            
                            Text(item.asciiRepresentation)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(VesperTheme.neonGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VesperTheme.secondaryCardBackground.opacity(0.3))
                        .cornerRadius(4)
                    }
                }
                .padding(8)
                .background(VesperTheme.darkBackground)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(VesperTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
        )
    }
    
    private func quickJumpButton(name: String, addr: String) -> some View {
        Button(action: {
            probeService.memoryInspectAddressHex = addr
            Task { await probeService.readMemoryChunk() }
        }) {
            Text(name)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(VesperTheme.secondaryCardBackground)
                .foregroundColor(VesperTheme.accentCyan)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Raw Console Output
    
    private var rawConsoleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(VesperTheme.secondaryTextColor)
                Text("Hardware Probe CLI Telemetry")
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                Spacer()
                Button("Clear") {
                    probeService.consoleOutput = ""
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(VesperTheme.accentCyan)
            }
            
            ScrollView {
                Text(probeService.consoleOutput.isEmpty ? "Probe telemetry ready. Run any action above to stream diagnostic output." : probeService.consoleOutput)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(probeService.consoleOutput.contains("Error") ? VesperTheme.neonRed : VesperTheme.accentCyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .frame(height: 120)
            .background(VesperTheme.darkBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(VesperTheme.subtleBorder, lineWidth: 1)
            )
        }
        .padding(16)
        .background(VesperTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
        )
    }
}
