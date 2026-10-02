import SwiftUI
import AppKit

public enum MicroDocsTab: String, CaseIterable, Identifiable {
    case quickstart = "Quickstart Guide"
    case subghz = "Sub-GHz & RF"
    case gpio = "GPIO & Devboards"
    case firmware = "Firmware Matrix"
    case badusb = "BadUSB / DuckyScript"
    case ferrite = "FerriteOS Local AI"
    case webmcp = "WebMCP Protocol"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .quickstart: return "sparkles.rectangle.stack.fill"
        case .subghz: return "waveform.path.ecg"
        case .gpio: return "cpu.fill"
        case .firmware: return "arrow.triangle.2.circlepath.circle.fill"
        case .badusb: return "keyboard.fill"
        case .ferrite: return "atom"
        case .webmcp: return "network"
        }
    }
}

public struct MicroDocsView: View {
    @State private var selectedTab: MicroDocsTab = .quickstart
    @State private var searchText: String = ""
    @State private var copiedToast: String?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Tab Selector
            tabSelectorBar
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    if let toast = copiedToast {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(VesperTheme.neonGreen)
                            Text(toast)
                                .font(.caption.bold())
                                .foregroundColor(VesperTheme.neonGreen)
                            Spacer()
                        }
                        .padding(10)
                        .background(VesperTheme.neonGreen.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.neonGreen.opacity(0.3), lineWidth: 1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    switch selectedTab {
                    case .quickstart:
                        QuickstartTabContent(copyAction: copyToClipboard)
                    case .subghz:
                        SubGhzTabContent(filter: searchText, copyAction: copyToClipboard)
                    case .gpio:
                        GpioTabContent(filter: searchText, copyAction: copyToClipboard)
                    case .firmware:
                        FirmwareMatrixTabContent(filter: searchText)
                    case .badusb:
                        BadUsbTabContent(filter: searchText, copyAction: copyToClipboard)
                    case .ferrite:
                        FerriteOsTabContent(filter: searchText, copyAction: copyToClipboard)
                    case .webmcp:
                        WebMcpTabContent(copyAction: copyToClipboard)
                    }
                }
                .padding(24)
            }
        }
        .background(VesperTheme.darkBackground)
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .font(.title2)
                        .foregroundColor(VesperTheme.accentCyan)
                    Text("FIELD OPERATOR MANUAL")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(VesperTheme.primaryTextColor)
                    
                    Text("MICRO-DOCS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.accentCyan.opacity(0.2))
                        .foregroundColor(VesperTheme.accentCyan)
                        .cornerRadius(4)
                }
                
                Text("Tactical references, pinouts, radio spectrum specs, FerriteOS NLP, and WebMCP client setups.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Search Input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search manuals, pins, freqs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: 260)
            .background(VesperTheme.secondaryCardBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(VesperTheme.cardBackground)
    }
    
    // MARK: - Tab Bar
    private var tabSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MicroDocsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? VesperTheme.accentCyan.opacity(0.2) : Color.clear)
                        .foregroundColor(selectedTab == tab ? VesperTheme.accentCyan : .secondary)
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(selectedTab == tab ? VesperTheme.accentCyan.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(VesperTheme.cardBackground.opacity(0.7))
    }
    
    private func copyToClipboard(_ text: String, label: String = "Copied to clipboard") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            copiedToast = label
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if copiedToast == label { copiedToast = nil }
            }
        }
    }
}

// MARK: - 1. Quickstart Guide Tab
private struct QuickstartTabContent: View {
    let copyAction: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Field Operator Quickstart (5-Minute Onboarding)")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            // Steps Grid
            VStack(spacing: 14) {
                stepCard(
                    number: "01",
                    title: "Connect Flipper via USB CDC or BLE",
                    icon: "cable.connector",
                    color: VesperTheme.accentCyan,
                    desc: "Plug your Flipper Zero into your Mac with USB-C. ferriteSuite automatically probes `/dev/cu.usbmodemflip_*` at 230,400 baud. The bottom-left telemetry indicator turns bright green once connected."
                )
                
                stepCard(
                    number: "02",
                    title: "Deploy Autonomous Hardware Workflows",
                    icon: "point.3.connected.trianglepath.dotted",
                    color: VesperTheme.flipperOrange,
                    desc: "Navigate to 'Workflows & DAG'. Click 'Run Workflow' to execute autonomous multi-node security tasks (e.g. Sub-GHz Recon, Hardware Diagnostics, or Access Control Badge Auditor). You can pause, step, or inspect live execution at any moment."
                )
                
                stepCard(
                    number: "03",
                    title: "Offline Deterministic AI with FerriteOS",
                    icon: "atom",
                    color: VesperTheme.cyberPurple,
                    desc: "FerriteOS is bundled locally with a compiled Rust micro-model. Speak or type natural language instructions like 'scan for garage doors on 433mhz'. FerriteOS deterministically parses the intent and maps it directly to hardware parameters with zero cloud latency."
                )
                
                stepCard(
                    number: "04",
                    title: "Connect Claude Desktop / WebMCP",
                    icon: "network",
                    color: VesperTheme.neonGreen,
                    desc: "ferriteSuite includes an embedded WebMCP bridge on `http://127.0.0.1:8765/sse`. Add this URL to your `claude_desktop_config.json` or Cursor to let external LLMs read, transmit, and flash directly through ferriteSuite."
                )
                
                stepCard(
                    number: "05",
                    title: "Flash Firmware & WiFi Devboard Over-The-Air",
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    color: VesperTheme.neonAmber,
                    desc: "Use 'Firmware & Flashing' to switch between Unleashed, Momentum, and Official Flipper releases, or install ESP32 Marauder to your WiFi Devboard with automated GitHub asset fetching."
                )
            }
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Helpful Quick Links
            HStack(spacing: 16) {
                Link(destination: URL(string: "https://docs.flipper.net")!) {
                    Label("Official Flipper Docs ↗", systemImage: "safari")
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                }
                
                Link(destination: URL(string: "https://github.com/DarkFlippers/unleashed-firmware")!) {
                    Label("Unleashed Firmware GitHub ↗", systemImage: "arrow.up.right.circle")
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                }
                
                Link(destination: URL(string: "https://modelcontextprotocol.io")!) {
                    Label("Model Context Protocol Spec ↗", systemImage: "network")
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                }
            }
        }
    }
    
    private func stepCard(number: String, title: String, icon: String, color: Color, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(VesperTheme.primaryTextColor)
                }
                
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(16)
        .background(VesperTheme.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VesperTheme.subtleBorder, lineWidth: 1))
    }
}

// MARK: - 2. Sub-GHz & RF Spectrum Tab
private struct SubGhzTabContent: View {
    let filter: String
    let copyAction: (String, String) -> Void
    
    let bands = [
        ("315.00 MHz", "Americas", "Automotive key fobs, older garage door Openers, tire pressure sensors (TPMS)."),
        ("433.92 MHz", "EU & Worldwide", "ISM band standard. Weather stations, wireless doorbells, smart plugs, alarms, gate remotes."),
        ("868.35 MHz", "Europe (SRD)", "LoRa, IoT smart home sensors, Zigbee Sub-GHz, high-security gate remotes."),
        ("915.00 MHz", "Americas (ISM)", "Industrial monitoring, LoRaWAN, smart utility meters, wireless home automation."),
        ("300–348 MHz", "Tunable CC1101", "Band 1 supported by Texas Instruments CC1101 transceiver."),
        ("387–464 MHz", "Tunable CC1101", "Band 2 supported by CC1101 (covers 433 MHz ISM)."),
        ("779–928 MHz", "Tunable CC1101", "Band 3 supported by CC1101 (covers 868 MHz & 915 MHz).")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sub-GHz Radio Architecture & Frequencies")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Text("Hardware: Texas Instruments CC1101 low-power Sub-1 GHz transceiver.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Link("Flipper Sub-GHz Docs ↗", destination: URL(string: "https://docs.flipper.net/sub-ghz")!)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            // Bands Table
            VStack(spacing: 8) {
                ForEach(bands.filter { filter.isEmpty || $0.0.localizedCaseInsensitiveContains(filter) || $0.2.localizedCaseInsensitiveContains(filter) }, id: \.0) { band in
                    HStack(spacing: 12) {
                        Text(band.0)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(VesperTheme.flipperOrange)
                            .frame(width: 120, alignment: .leading)
                        
                        Text(band.1)
                            .font(.caption.bold())
                            .foregroundColor(VesperTheme.accentCyan)
                            .frame(width: 140, alignment: .leading)
                        
                        Text(band.2)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            copyAction(band.0, "Copied frequency \(band.0)")
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy frequency")
                    }
                    .padding(10)
                    .background(VesperTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
            }
            
            // Modulation & Protocols Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Modulations & Signal Parsing")
                    .font(.headline)
                    .foregroundColor(VesperTheme.primaryTextColor)
                
                Text("• **AM / ASK (Amplitude Shift Keying)**: Used by 80% of consumer remotes (Princeton, Nice, Came, CAME TOP).\n• **FM / 2-FSK (Frequency Shift Keying)**: Higher noise resistance, used by automotive fobs (Keeloq, StarLine).\n• **Static Code**: Signal repeats identical pulse pattern on every press. Can be captured and replayed freely.\n• **Dynamic / Rolling Code (KeeLoq, Alutech, Nice Flor-S)**: Counter increments with cryptographic MAC. *Caution: Replaying old rolling codes will fail and may de-synchronize the original remote.*")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .glassCard()
        }
    }
}

// MARK: - 3. GPIO & Devboard Tab
private struct GpioTabContent: View {
    let filter: String
    let copyAction: (String, String) -> Void
    
    let pins = [
        ("Pin 1", "5V / VBUS", "Power output from Flipper 5V step-up (must enable 5V in GPIO menu)"),
        ("Pin 2", "GND", "Ground connection"),
        ("Pin 3", "PA7", "Hardware GPIO pin / ADC input"),
        ("Pin 4", "PA6", "Hardware GPIO pin / ADC input"),
        ("Pin 5", "PA4 (SCK)", "Hardware SPI Clock (used for NRF24L01 / CC1101 modules)"),
        ("Pin 6", "PB3 (MISO)", "Hardware SPI Master In Slave Out"),
        ("Pin 7", "PB2 (MOSI)", "Hardware SPI Master Out Slave In"),
        ("Pin 8", "PC3", "Hardware GPIO pin"),
        ("Pin 9", "3V3 Out", "Regulated 3.3V power output (up to 200mA)"),
        ("Pin 11", "GND", "Ground connection"),
        ("Pin 13", "USART TX (PB6)", "UART Transmit from Flipper -> Connect to RX of ESP32"),
        ("Pin 14", "USART RX (PB7)", "UART Receive into Flipper <- Connect to TX of ESP32"),
        ("Pin 15", "1-Wire / PB14", "Dallas / iButton digital 1-Wire communication"),
        ("Pin 16", "SWDIO", "ARM Cortex-M4 Serial Wire Debug Data"),
        ("Pin 17", "SWCLK", "ARM Cortex-M4 Serial Wire Debug Clock"),
        ("Pin 18", "GND", "Ground connection")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("18-Pin GPIO Header Reference & Devboard Wiring")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Text("Flipper Zero features an 18-pin 2.54mm female pitch header for external sensors and microcontrollers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Link("Official Pinout Specs ↗", destination: URL(string: "https://docs.flipper.net/gpio-and-modules")!)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            // ESP32 Marauder Wiring Box
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wifi.circle.fill")
                        .foregroundColor(VesperTheme.neonAmber)
                    Text("ESP32 WiFi Marauder Quick Wiring Guide")
                        .font(.headline)
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Spacer()
                    Link("Marauder GitHub ↗", destination: URL(string: "https://github.com/justcallmekoko/ESP32Marauder")!)
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                }
                
                Text("To connect a standalone ESP32-WROOM or ESP32-S2/S3 Devboard:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    codeLine("Flipper Pin 9  (3V3)  ---> ESP32 3V3 (or Pin 1 [5V] to VIN with 5V enabled)")
                    codeLine("Flipper Pin 2  (GND)  ---> ESP32 GND")
                    codeLine("Flipper Pin 13 (TX)   ---> ESP32 GPIO 4 (or RX0) (Crossed: Flipper TX to ESP RX)")
                    codeLine("Flipper Pin 14 (RX)   ---> ESP32 GPIO 5 (or TX0) (Crossed: Flipper RX to ESP TX)")
                }
            }
            .padding(16)
            .glassCard()
            
            // Pins Table
            VStack(spacing: 8) {
                ForEach(pins.filter { filter.isEmpty || $0.0.localizedCaseInsensitiveContains(filter) || $0.1.localizedCaseInsensitiveContains(filter) || $0.2.localizedCaseInsensitiveContains(filter) }, id: \.0) { pin in
                    HStack(spacing: 12) {
                        Text(pin.0)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(VesperTheme.accentCyan)
                            .frame(width: 70, alignment: .leading)
                        
                        Text(pin.1)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(VesperTheme.neonGreen)
                            .frame(width: 130, alignment: .leading)
                        
                        Text(pin.2)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            copyAction("\(pin.0) - \(pin.1)", "Copied \(pin.0)")
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(VesperTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
            }
        }
    }
    
    private func codeLine(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(VesperTheme.neonGreen)
            Spacer()
            Button(action: { copyAction(text, "Copied wiring instruction") }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.black.opacity(0.35))
        .cornerRadius(6)
    }
}

// MARK: - 4. Firmware Ecosystem Matrix Tab
private struct FirmwareMatrixTabContent: View {
    let filter: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Flipper Zero Firmware Distribution Matrix")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            Text("ferriteSuite supports seamless flashing and OTA synchronizing with all major Flipper community and official distributions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Distro Cards
            VStack(spacing: 14) {
                distroCard(
                    name: "Unleashed Firmware",
                    badge: "MOST POPULAR",
                    badgeColor: VesperTheme.neonAmber,
                    icon: "flame.fill",
                    author: "DarkFlippers Community",
                    highlights: [
                        "Frequency Lock Removed: Transmit across 300-348, 387-464, and 779-928 MHz worldwide.",
                        "Enhanced Sub-GHz Rolling Code analyzer and extra KeeLoq/Came algorithms.",
                        "Pre-installed tactical applications: WiFi Marauder companion, Sub-GHz brute-forcers, NRF24 sniffer.",
                        "High stability branch tracking upstream official releases regularly."
                    ],
                    repoUrl: "https://github.com/DarkFlippers/unleashed-firmware"
                )
                
                distroCard(
                    name: "Momentum Firmware",
                    badge: "CUSTOMIZABLE & MODERN",
                    badgeColor: VesperTheme.cyberPurple,
                    icon: "sparkles",
                    author: "Next-Flip / Momentum Team",
                    highlights: [
                        "Rich UI Customization: Custom asset packs, boot animations, icons, and dolphin moods.",
                        "Built-in App Store updater directly on the device via WiFi devboard.",
                        "Advanced Sub-GHz hopping and auto-save raw sniffer modes.",
                        "Protocols: Unlocked regional TX + extensive protocol decoders."
                    ],
                    repoUrl: "https://github.com/Next-Flip/Momentum-Firmware"
                )
                
                distroCard(
                    name: "Official Flipper Firmware",
                    badge: "STABLE & COMPLIANT",
                    badgeColor: VesperTheme.accentCyan,
                    icon: "shield.checkmark.fill",
                    author: "Flipper Devices Inc.",
                    highlights: [
                        "Full regulatory compliance: Transmission restricted to local country ISM bands.",
                        "Zero experimental regressions, guaranteed compatibility with official qFlipper.",
                        "Recommended baseline when testing hardware issues or warranty validation."
                    ],
                    repoUrl: "https://github.com/flipperdevices/flipperzero-firmware"
                )
                
                distroCard(
                    name: "RogueMaster",
                    badge: "EXPERIMENTAL",
                    badgeColor: VesperTheme.neonRed,
                    icon: "bolt.badge.automatic.fill",
                    author: "RogueMaster Community",
                    highlights: [
                        "Aggressive feature integration and early alpha protocol ports.",
                        "Huge library of games and third-party experimental tools.",
                        "Higher frequency of commits; may have occasional firmware panics."
                    ],
                    repoUrl: "https://github.com/RogueMaster/flipperzero-firmware-wPlugins"
                )
            }
        }
    }
    
    private func distroCard(name: String, badge: String, badgeColor: Color, icon: String, author: String, highlights: [String], repoUrl: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(badgeColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(VesperTheme.primaryTextColor)
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor.opacity(0.18))
                            .foregroundColor(badgeColor)
                            .cornerRadius(4)
                    }
                    Text("By \(author)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Link("GitHub Repo ↗", destination: URL(string: repoUrl)!)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(highlights, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(badgeColor)
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - 5. BadUSB & DuckyScript Tab
private struct BadUsbTabContent: View {
    let filter: String
    let copyAction: (String, String) -> Void
    
    let syntax = [
        ("REM [comment]", "Comment line. Ignored by execution interpreter."),
        ("DELAY [ms]", "Pause execution for specified milliseconds (e.g. DELAY 500 = 0.5s)."),
        ("STRING [text]", "Types plain text with human keyboard keystrokes."),
        ("STRINGLN [text]", "Types text followed automatically by an ENTER keystroke."),
        ("ENTER", "Presses the Return / Enter key."),
        ("GUI [key]", "Windows Key on PC, or Command (⌘) key on macOS (e.g. GUI SPACE opens Spotlight)."),
        ("CTRL [key]", "Control modifier key."),
        ("ALT [key]", "Alt / Option (⌥) modifier key."),
        ("SHIFT [key]", "Shift modifier key."),
        ("REPEAT [count]", "Repeats the immediately preceding command N times.")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BadUSB & DuckyScript 3.0 Reference")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Text("Flipper Zero emulates a standard USB HID keyboard to execute automated system commands.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Link("Hak5 DuckyScript Docs ↗", destination: URL(string: "https://docs.hak5.org/ducky-script")!)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            // Example macOS Script
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("macOS Spotlight Quick Terminal Payload Example")
                        .font(.subheadline.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Spacer()
                    Button("Copy Script") {
                        let script = """
                        REM Title: macOS Fast Terminal
                        DELAY 1000
                        GUI SPACE
                        DELAY 300
                        STRING Terminal
                        DELAY 200
                        ENTER
                        DELAY 800
                        STRINGLN echo 'ferriteSuite Operational' && whoami
                        """
                        copyAction(script, "Copied macOS DuckyScript template")
                    }
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
                    .buttonStyle(.plain)
                }
                
                Text("""
                REM Title: macOS Fast Terminal
                DELAY 1000
                GUI SPACE
                DELAY 300
                STRING Terminal
                DELAY 200
                ENTER
                DELAY 800
                STRINGLN echo 'ferriteSuite Operational' && whoami
                """)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(VesperTheme.neonGreen)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            }
            .padding(16)
            .glassCard()
            
            // Syntax Table
            VStack(spacing: 8) {
                ForEach(syntax.filter { filter.isEmpty || $0.0.localizedCaseInsensitiveContains(filter) || $0.1.localizedCaseInsensitiveContains(filter) }, id: \.0) { item in
                    HStack(spacing: 12) {
                        Text(item.0)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(VesperTheme.flipperOrange)
                            .frame(width: 140, alignment: .leading)
                        
                        Text(item.1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(VesperTheme.cardBackground)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - 6. FerriteOS Local AI Tab
private struct FerriteOsTabContent: View {
    let filter: String
    let copyAction: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FerriteOS: Zero-Latency Local Intent Engine")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Text("High-speed deterministic Rust token classifier running completely offline on your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Link("FerriteOS Project ↗", destination: URL(string: "https://github.com/dext7r/FerriteOS")!)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            // Architecture Highlights
            VStack(alignment: .leading, spacing: 12) {
                Text("How FerriteOS Complements LLMs:")
                    .font(.headline)
                    .foregroundColor(VesperTheme.primaryTextColor)
                
                Text("• **100% Air-Gapped & Offline**: Does not require WiFi, cellular, or API tokens to parse tactical commands.\n• **Deterministic Microsecond Routing**: Dissects raw phrases into structured `{ domain, intent, parameters }` JSON in <2ms.\n• **RF Signal Demodulator**: FerriteOS includes compiled Rust routines to decode pulse-length intervals directly from `.sub` captures.\n• **Hybrid Autonomous Execution**: High-level reasoning is handled by Grok/Claude, while FerriteOS validates raw binary parameters before reaching the hardware.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .glassCard()
            
            // Example Intent Schema
            VStack(alignment: .leading, spacing: 10) {
                Text("Sample FerriteOS Output Schema")
                    .font(.subheadline.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                
                Text("""
                {
                  "domain": "subghz",
                  "intent": "analyze_spectrum",
                  "confidence": 0.985,
                  "entities": {
                    "frequency_mhz": 433.92,
                    "modulation": "2FSK",
                    "hop_interval_ms": 100
                  }
                }
                """)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(VesperTheme.accentCyan)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            }
            .padding(16)
            .glassCard()
        }
    }
}

// MARK: - 7. WebMCP Protocol Tab
private struct WebMcpTabContent: View {
    let copyAction: (String, String) -> Void
    @State private var server = WebMcpServer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WebMCP: Model Context Protocol over HTTP/SSE")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Text("Bridge external AI assistants (Claude Desktop, Cursor, Web Agents) directly to Flipper Zero.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Link("MCP Specification ↗", destination: URL(string: "https://modelcontextprotocol.io")!)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
            }
            
            // Server Status Box
            HStack(spacing: 16) {
                Circle()
                    .fill(server.isRunning ? VesperTheme.neonGreen : VesperTheme.neonRed)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.isRunning ? "WebMCP Server Running" : "WebMCP Server Stopped")
                        .font(.headline)
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Text(server.isRunning ? "Listening at http://127.0.0.1:\(server.port)/sse" : "Start server in Settings to connect external clients.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if server.isRunning {
                    Text("\(server.requestCount) Requests")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(VesperTheme.accentCyan.opacity(0.2))
                        .foregroundColor(VesperTheme.accentCyan)
                        .cornerRadius(6)
                }
            }
            .padding(16)
            .glassCard()
            
            // Claude Desktop Config Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .foregroundColor(VesperTheme.cyberPurple)
                    Text("Claude Desktop Integration (`claude_desktop_config.json`)")
                        .font(.headline)
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Spacer()
                    Button("Copy JSON") {
                        let json = """
                        {
                          "mcpServers": {
                            "flipper-vesper": {
                              "url": "http://127.0.0.1:\(server.port)/sse"
                            }
                          }
                        }
                        """
                        copyAction(json, "Copied Claude Desktop configuration")
                    }
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
                    .buttonStyle(.plain)
                }
                
                Text("Paste this into `~/Library/Application Support/Claude/claude_desktop_config.json` to empower Claude with full Flipper Zero RF, BadUSB, and SD card controls:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("""
                {
                  "mcpServers": {
                    "flipper-vesper": {
                      "url": "http://127.0.0.1:\(server.port)/sse"
                    }
                  }
                }
                """)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(VesperTheme.neonGreen)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            }
            .padding(16)
            .glassCard()
            
            // Curl Test Command
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Quick Verification (Terminal curl)")
                        .font(.subheadline.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Spacer()
                    Button("Copy Command") {
                        let cmd = "curl -s http://127.0.0.1:\(server.port)/health | jq ."
                        copyAction(cmd, "Copied curl command")
                    }
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.accentCyan)
                    .buttonStyle(.plain)
                }
                
                Text("curl -s http://127.0.0.1:\(server.port)/health | jq .")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(VesperTheme.accentCyan)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(6)
            }
            .padding(16)
            .glassCard()
        }
    }
}
