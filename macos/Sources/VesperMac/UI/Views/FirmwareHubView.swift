import SwiftUI

public struct FirmwareHubView: View {
    @State private var flashService = FirmwareFlashService.shared
    @State private var connection = FlipperConnectionManager.shared
    @State private var selectedTab: Int = 0
    @State private var selectedDistroFilter: FlipperFirmwareDistro? = nil
    
    // GPIO flashing state
    @State private var selectedGpioRelease: FirmwareRelease? = nil
    @State private var selectedBoard: GPIOBoardType = .esp32s2
    @State private var useFlipperHeaderMode: Bool = true
    @State private var showLogsDrawer: Bool = true
    
    // Active flashing modal state
    @State private var activeFlashingRelease: FirmwareRelease? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top HUD Bar
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.title2)
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("Firmware & Flashing Hub")
                            .font(.title2.bold())
                    }
                    Text("1-click firmware flashing for Flipper Zero and GPIO devboards, synchronized live with GitHub.")
                        .font(.caption)
                        .foregroundColor(VesperTheme.secondaryTextColor)
                }
                
                Spacer()
                
                // Installed Version Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(connection.status.isConnected ? VesperTheme.neonGreen : VesperTheme.neonAmber)
                        .frame(width: 8, height: 8)
                    Text("Installed: \(connection.deviceInfo.firmwareVersion)")
                        .font(.caption.monospaced())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VesperTheme.secondaryCardBackground)
                .cornerRadius(8)
                
                // GitHub Sync Button
                Button(action: {
                    Task { await flashService.syncGitHubReleases() }
                }) {
                    HStack(spacing: 6) {
                        if flashService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(flashService.isSyncing ? "Syncing..." : "Sync GitHub")
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
                .disabled(flashService.isSyncing || flashService.isFlashing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(VesperTheme.cardBackground)
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Tab Segment Control
            Picker("Mode", selection: $selectedTab) {
                Text("Flipper Zero Firmware").tag(0)
                Text("GPIO & WiFi Devboards").tag(1)
                Text("Pinout & Wiring Guide").tag(2)
                Text("Diagnostics & Preflight").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(VesperTheme.cardBackground.opacity(0.6))
            
            // Tab Contents
            Group {
                switch selectedTab {
                case 0:
                    flipperFirmwareTab
                case 1:
                    gpioDevboardsTab
                case 2:
                    pinoutWiringTab
                case 3:
                    diagnosticsTab
                default:
                    EmptyView()
                }
            }
            
            // Active Flash Progress Modal Bar
            if flashService.isFlashing {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(VesperTheme.neonAmber)
                        Text(flashService.flashStatus)
                            .font(.caption.monospaced().bold())
                        Spacer()
                        Text("\(Int(flashService.flashProgress * 100))%")
                            .font(.caption.monospaced())
                            .foregroundColor(VesperTheme.accentCyan)
                    }
                    
                    ProgressView(value: flashService.flashProgress)
                        .progressViewStyle(.linear)
                        .tint(VesperTheme.accentCyan)
                }
                .padding(14)
                .background(VesperTheme.cardBackground)
                .border(VesperTheme.accentCyan.opacity(0.5), width: 1)
            }
        }
        .background(VesperTheme.darkBackground)
    }
    
    // MARK: - Tab 1: Flipper Firmware
    
    private var flipperFirmwareTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Distro Filter Row
                HStack(spacing: 8) {
                    Button(action: { selectedDistroFilter = nil }) {
                        Text("All Distros (\(flashService.flipperReleases.count))")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedDistroFilter == nil ? VesperTheme.accentCyan.opacity(0.2) : VesperTheme.secondaryCardBackground)
                            .foregroundColor(selectedDistroFilter == nil ? VesperTheme.accentCyan : .secondary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(FlipperFirmwareDistro.allCases) { distro in
                        Button(action: { selectedDistroFilter = distro }) {
                            HStack(spacing: 5) {
                                Image(systemName: distro.iconName)
                                Text(distro.rawValue)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedDistroFilter == distro ? distro.accentColor.opacity(0.2) : VesperTheme.secondaryCardBackground)
                            .foregroundColor(selectedDistroFilter == distro ? distro.accentColor : .secondary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Release Cards List
                let filtered = selectedDistroFilter == nil ? flashService.flipperReleases : flashService.flipperReleases.filter { $0.distro == selectedDistroFilter }
                
                ForEach(filtered) { release in
                    FlipperReleaseCard(release: release) {
                        Task {
                            do {
                                try await flashService.flashFlipper(release: release)
                            } catch {
                                flashService.flashLogs.append("Error flashing: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Tab 2: GPIO & Devboards
    
    private var gpioDevboardsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Board Target & Flashing Mode Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("Target GPIO Devboard & Programmer")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        // Board Type Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hardware Board:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            Picker("Board", selection: $selectedBoard) {
                                ForEach(GPIOBoardType.allCases) { b in
                                    Text(b.rawValue).tag(b)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Flashing Mode Toggle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Programming Interface:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            Picker("Mode", selection: $useFlipperHeaderMode) {
                                Text("Mounted on Flipper (18-Pin GPIO Header)").tag(true)
                                Text("Direct USB Connection (Mac Serial Port)").tag(false)
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    if !useFlipperHeaderMode {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("USB Serial Port (/dev/cu.*):")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Picker("Port", selection: $flashService.selectedSerialPort) {
                                        ForEach(flashService.availableSerialPorts, id: \.self) { p in
                                            Text(p).tag(p)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Button(action: { flashService.refreshSerialPorts() }) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Baud Rate:")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                Picker("Baud", selection: $flashService.selectedBaudRate) {
                                    Text("115200").tag(115200)
                                    Text("460800 (Fast)").tag(460800)
                                    Text("921600 (Maximum)").tag(921600)
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Toggle("Erase Chip First", isOn: $flashService.eraseBeforeFlash)
                                .font(.caption)
                                .padding(.top, 16)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(VesperTheme.accentCyan)
                            Text("Flipper Header Mode: Binary is uploaded directly to Flipper SD card (/ext/apps_data/esp_flasher/). Flipper's native ESP32 Flasher handles the flash over USART pins 13/14.")
                                .font(.caption)
                                .foregroundColor(VesperTheme.secondaryTextColor)
                        }
                        .padding(10)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(8)
                    }
                }
                .padding(20)
                .glassCard()
                
                // Available GPIO Firmware Releases
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(VesperTheme.neonAmber)
                        Text("Available Devboard Firmware (GitHub Releases)")
                            .font(.headline)
                    }
                    
                    ForEach(flashService.gpioReleases) { release in
                        GpioReleaseCard(release: release, useFlipperMode: useFlipperHeaderMode) {
                            Task {
                                do {
                                    if useFlipperHeaderMode {
                                        try await flashService.uploadGpioFirmwareToFlipper(release: release)
                                    } else {
                                        try await flashService.flashGpioBoard(
                                            release: release,
                                            port: flashService.selectedSerialPort,
                                            baudRate: flashService.selectedBaudRate,
                                            eraseFirst: flashService.eraseBeforeFlash
                                        )
                                    }
                                } catch {
                                    flashService.flashLogs.append("Error: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                
                // Real-time Flash Terminal Console Drawer
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("PROGRAMMER CONSOLE OUTPUT")
                            .font(.system(size: 10, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { flashService.flashLogs.removeAll() }) {
                            Text("Clear")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(flashService.flashLogs.enumerated()), id: \.offset) { item in
                                Text(item.element)
                                    .font(.system(size: 10).monospaced())
                                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 120)
                }
                .padding(12)
                .background(Color.black.opacity(0.75))
                .border(VesperTheme.subtleBorder, width: 1)
            }
            .padding(20)
        }
    }
    
    // MARK: - Tab 3: Pinout & Wiring Reference
    
    private var pinoutWiringTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header diagram
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flipper 18-Pin GPIO Header & External Modules")
                        .font(.headline)
                    Text("Pinout reference for connecting Official WiFi Devboards, NRF24, CC1101, and custom ESP32 breakout boards.")
                        .font(.caption)
                        .foregroundColor(VesperTheme.secondaryTextColor)
                }
                .padding(16)
                .glassCard()
                
                // Pinout Table
                VStack(alignment: .leading, spacing: 10) {
                    Text("Flipper Zero GPIO Pin Map")
                        .font(.subheadline.bold())
                    
                    let pins: [(pin: String, name: String, funcName: String, desc: String)] = [
                        ("1", "VCC 3V3", "Power Output", "3.3V power supply from Flipper battery"),
                        ("2", "SWCLK", "USART RX / Debug", "GPIO 14 for UART communication"),
                        ("3", "SWDIO", "USART TX / Debug", "GPIO 13 for UART communication"),
                        ("4", "GPIO 2", "Reset Pin", "ESP32 EN / Reset signal"),
                        ("5", "GPIO 3", "Boot Pin", "ESP32 GPIO 0 / Boot mode selection"),
                        ("8", "GND", "Ground", "Common Ground"),
                        ("9", "3V3", "NRF24 VCC", "3.3V power (add 10uF cap for NRF24 stability)"),
                        ("11", "GND", "NRF24 GND", "Ground pin"),
                        ("12", "MOSI", "SPI MOSI", "Master Out Slave In for NRF24 / CC1101"),
                        ("13", "MISO", "SPI MISO", "Master In Slave Out"),
                        ("14", "SCK", "SPI Clock", "SPI serial clock line"),
                        ("15", "CS", "SPI Chip Select", "CSN pin for radio transceivers"),
                        ("16", "CE", "Chip Enable", "TX/RX enable pin for NRF24 / CC1101 GDO0")
                    ]
                    
                    ForEach(pins, id: \.pin) { p in
                        HStack(spacing: 12) {
                            Text("Pin \(p.pin)")
                                .font(.caption.monospaced().bold())
                                .frame(width: 55, alignment: .leading)
                                .foregroundColor(VesperTheme.accentCyan)
                            
                            Text(p.name)
                                .font(.caption.bold())
                                .frame(width: 110, alignment: .leading)
                            
                            Text(p.funcName)
                                .font(.caption2.monospaced())
                                .foregroundColor(VesperTheme.neonAmber)
                                .frame(width: 140, alignment: .leading)
                            
                            Text(p.desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        Divider().background(VesperTheme.subtleBorder.opacity(0.5))
                    }
                }
                .padding(20)
                .glassCard()
            }
            .padding(20)
        }
    }
    
    // MARK: - Tab 4: Diagnostics & Pre-flight
    private var diagnosticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Action Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(VesperTheme.neonAmber)
                        Text("System, Bootloader & Hardware Diagnostics")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                _ = await flashService.runComprehensiveDiagnostics()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if flashService.isRunningDiagnostics {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(flashService.isRunningDiagnostics ? "Running Tests..." : "Run Full Diagnostic Scan")
                            }
                            .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VesperTheme.accentCyan)
                        .disabled(flashService.isRunningDiagnostics)
                    }
                    
                    Text("Pre-flight safety inspection: verifies Flipper serial link, battery charge margin, microSD storage mount, GPIO devboard UART loopback, FerriteOS bare-metal image integrity, and host flashing tools.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .glassCard()
                
                // Diagnostic Results Grid
                if !flashService.diagnosticResults.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DIAGNOSTIC TEST RESULTS (\(flashService.diagnosticResults.filter { $0.passed }.count) / \(flashService.diagnosticResults.count) PASSED):")
                            .font(.system(size: 10, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        
                        ForEach(flashService.diagnosticResults) { res in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: res.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(res.passed ? VesperTheme.neonGreen : VesperTheme.neonAmber)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(res.title)
                                            .font(.subheadline.bold())
                                            .foregroundColor(VesperTheme.primaryTextColor)
                                        
                                        Spacer()
                                        
                                        Text(res.category.uppercased())
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(res.passed ? VesperTheme.neonGreen.opacity(0.15) : VesperTheme.neonAmber.opacity(0.15))
                                            .foregroundColor(res.passed ? VesperTheme.neonGreen : VesperTheme.neonAmber)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(res.detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(VesperTheme.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(res.passed ? VesperTheme.neonGreen.opacity(0.3) : VesperTheme.neonAmber.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                } else {
                    // Empty state card
                    VStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No Diagnostics Run Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Click 'Run Full Diagnostic Scan' above to probe the connected Flipper Zero, storage, devboards, and FerriteOS binary images.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .glassCard()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Subcomponents

private struct FlipperReleaseCard: View {
    let release: FirmwareRelease
    let onFlash: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let distro = release.distro {
                    Circle()
                        .fill(distro.accentColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: distro.iconName)
                                .foregroundColor(distro.accentColor)
                                .font(.system(size: 16))
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(release.title)
                            .font(.headline)
                        
                        Text(release.tagName)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(4)
                    }
                    
                    Text("Repository: \(release.repoName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if release.isInstalled {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(VesperTheme.neonGreen)
                        Text("Active on Flipper")
                            .font(.caption.bold())
                            .foregroundColor(VesperTheme.neonGreen)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(VesperTheme.neonGreen.opacity(0.12))
                    .cornerRadius(8)
                }
                
                Button(action: onFlash) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text(release.isInstalled ? "Reinstall" : "1-Click Flash")
                            .bold()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(release.isInstalled ? VesperTheme.secondaryCardBackground : VesperTheme.accentCyan)
                    .foregroundColor(release.isInstalled ? .primary : .black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            if let distro = release.distro {
                Text(distro.description)
                    .font(.caption)
                    .foregroundColor(VesperTheme.secondaryTextColor)
            }
            
            if !release.changelog.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Release Highlights:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(release.changelog)
                        .font(.caption2.monospaced())
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .padding(10)
                .background(VesperTheme.secondaryCardBackground)
                .cornerRadius(6)
            }
        }
        .padding(16)
        .glassCard()
    }
}

private struct GpioReleaseCard: View {
    let release: FirmwareRelease
    let useFlipperMode: Bool
    let onFlash: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wifi.circle.fill")
                .font(.title)
                .foregroundColor(VesperTheme.neonAmber)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(release.title)
                        .font(.headline)
                    Text(release.tagName)
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(4)
                }
                
                Text(release.changelog)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onFlash) {
                HStack(spacing: 6) {
                    Image(systemName: useFlipperMode ? "folder.badge.plus" : "bolt.fill")
                    Text(useFlipperMode ? "Install to Flipper SD" : "Flash via USB")
                        .bold()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(VesperTheme.neonGreen)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassCard()
    }
}
