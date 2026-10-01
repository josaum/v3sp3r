import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable {
    case chat = "AI Chat"
    case workflows = "Workflows & DAG"
    case microDocs = "Field Manual & Docs"
    case firmwareHub = "Firmware & Flashing"
    case memoryVault = "Memory Vault"
    case ferriteWorkbench = "FerriteOS Workbench"
    case swarmMission = "AI Swarm Missions"
    case device = "Device HUD"
    case virtualFlipper = "Virtual Flipper & LCD"
    case swarmFleet = "Swarm Fleet"
    case marauder = "Wireless Security Auditor"
    case captivePortal = "Portal Architect"
    case files = "File Browser"
    case fapHub = "FapHub App Store"
    case signalLab = "Signal Alchemy"
    case spectralOracle = "Spectral Oracle"
    case payloadLab = "Payload Lab"
    case opsCenter = "Ops Center"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .workflows: return "point.3.connected.trianglepath.dotted"
        case .microDocs: return "book.pages.fill"
        case .firmwareHub: return "arrow.triangle.2.circlepath.circle.fill"
        case .memoryVault: return "brain"
        case .ferriteWorkbench: return "atom"
        case .swarmMission: return "bolt.horizontal.circle.fill"
        case .device: return "cpu"
        case .virtualFlipper: return "gamecontroller.fill"
        case .swarmFleet: return "square.grid.2x2.fill"
        case .marauder: return "wifi.circle.fill"
        case .captivePortal: return "network.badge.shield.half.filled"
        case .files: return "folder.fill"
        case .fapHub: return "app.badge.checkmark.fill"
        case .signalLab: return "waveform.path.ecg"
        case .spectralOracle: return "waveform.path.ecg.rectangle.fill"
        case .payloadLab: return "keyboard.fill"
        case .opsCenter: return "terminal.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainContentView: View {
    @State private var selectedSection: NavigationSection? = .chat
    @State private var connection = FlipperConnectionManager.shared
    @State private var settings = AppSettings.shared
    @State private var memoryStore = VesperMemoryStore.shared
    @State private var workflowEngine = WorkflowEngine.shared
    @State private var ferrite = FerriteOSService.shared
    @State private var webMcp = WebMcpServer.shared
    @State private var showingQuickstart: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // App Branding & Quick Theme Switcher Header
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VesperTheme.accentCyan, VesperTheme.cyberPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("V3SP3R")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(VesperTheme.primaryTextColor)
                        Text("Flipper AI Desktop")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(VesperTheme.accentCyan)
                    }
                    
                    Spacer()
                    
                    if webMcp.isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(VesperTheme.neonGreen)
                                .frame(width: 6, height: 6)
                            Text("MCP:\(webMcp.port)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(VesperTheme.neonGreen)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(VesperTheme.neonGreen.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VesperTheme.neonGreen.opacity(0.3), lineWidth: 1))
                        .help("WebMCP Server running on port \(webMcp.port) (Claude / Cursor ready)")
                    }
                    
                    // Quickstart Guide & Onboarding Button
                    Button(action: { showingQuickstart = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VesperTheme.accentCyan)
                            .padding(6)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Field Operator Quickstart Guide & Tutorials")
                    
                    // One-Click Fast Theme Switcher (Cycle: System -> Light -> Dark -> System)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            switch settings.appTheme {
                            case .system: settings.appTheme = .light
                            case .light: settings.appTheme = .dark
                            case .dark: settings.appTheme = .system
                            }
                        }
                    }) {
                        Image(systemName: settings.appTheme.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VesperTheme.accentCyan)
                            .padding(6)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Theme: \(settings.appTheme.rawValue) (Click to switch)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(VesperTheme.cardBackground)
                
                Divider().background(VesperTheme.subtleBorder)
                
                // Grouped Sidebar Sections
                List(selection: $selectedSection) {
                    Section("INTELLIGENCE & OPS") {
                        sidebarRow(section: .chat)
                        sidebarRow(section: .workflows, badge: workflowEngine.isExecuting ? "RUNNING" : nil, badgeColor: VesperTheme.neonAmber)
                        sidebarRow(section: .microDocs)
                        sidebarRow(section: .ferriteWorkbench, badge: ferrite.isAvailable ? "ACTIVE" : nil, badgeColor: VesperTheme.accentCyan)
                        sidebarRow(section: .memoryVault, badge: "\(memoryStore.memories.count)", badgeColor: VesperTheme.cyberPurple)
                    }
                    
                    Section("HARDWARE & CONTROLS") {
                        sidebarRow(section: .device, indicatorDot: connection.status.isConnected ? VesperTheme.neonGreen : nil)
                        sidebarRow(section: .virtualFlipper, indicatorDot: connection.status.isConnected ? VesperTheme.flipperOrange : nil)
                        sidebarRow(section: .firmwareHub)
                        sidebarRow(section: .marauder)
                    }
                    
                    Section("TACTICAL & RF LABS") {
                        sidebarRow(section: .signalLab)
                        sidebarRow(section: .spectralOracle)
                        sidebarRow(section: .payloadLab)
                        sidebarRow(section: .captivePortal)
                        sidebarRow(section: .opsCenter)
                        sidebarRow(section: .files)
                        sidebarRow(section: .fapHub)
                    }
                    
                    Section("SWARM & SYSTEM") {
                        sidebarRow(section: .swarmMission)
                        sidebarRow(section: .swarmFleet)
                        sidebarRow(section: .settings)
                    }
                }
                .listStyle(.sidebar)
                
                Divider().background(VesperTheme.subtleBorder)
                
                // Bottom Live Telemetry Footer
                HStack(spacing: 10) {
                    Circle()
                        .fill(connection.status.isConnected ? VesperTheme.neonGreen : VesperTheme.neonRed)
                        .frame(width: 8, height: 8)
                        .shadow(color: connection.status.isConnected ? VesperTheme.neonGreen.opacity(0.6) : Color.clear, radius: 3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(connection.deviceInfo.hardwareModel.isEmpty ? "Flipper Zero" : connection.deviceInfo.hardwareModel)
                                .font(.caption.bold())
                                .foregroundColor(VesperTheme.primaryTextColor)
                                .lineLimit(1)
                            
                            if connection.status.isConnected {
                                Text("(\(connection.deviceInfo.firmwareVersion))")
                                    .font(.system(size: 9.5).monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if connection.status.isConnected {
                            HStack(spacing: 4) {
                                Image(systemName: connection.deviceInfo.isCharging ? "bolt.batteryblock.fill" : "battery.75percent")
                                    .font(.system(size: 9))
                                    .foregroundColor(connection.deviceInfo.batteryLevel < 20 ? VesperTheme.neonRed : VesperTheme.neonGreen)
                                Text("\(connection.deviceInfo.batteryLevel)%")
                                    .font(.system(size: 10, weight: .bold).monospaced())
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                Text(connection.status.description)
                                    .font(.system(size: 9.5).monospaced())
                                    .foregroundColor(VesperTheme.accentCyan)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("Disconnected")
                                .font(.caption2.monospaced())
                                .foregroundColor(VesperTheme.neonRed)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(VesperTheme.cardBackground)
            }
            .frame(minWidth: 230, idealWidth: 250)
            .background(VesperTheme.darkBackground)
        } detail: {
            Group {
                switch selectedSection ?? .chat {
                case .chat:
                    ChatView()
                case .workflows:
                    WorkflowGraphView()
                case .microDocs:
                    MicroDocsView()
                case .firmwareHub:
                    FirmwareHubView()
                case .memoryVault:
                    MemoryVaultView()
                case .ferriteWorkbench:
                    FerriteWorkbenchView()
                case .swarmMission:
                    SwarmMissionView()
                case .device:
                    DeviceView()
                case .virtualFlipper:
                    VirtualFlipperView()
                case .swarmFleet:
                    SwarmFleetView()
                case .marauder:
                    MarauderView()
                case .files:
                    FileManagerView()
                case .fapHub:
                    FapHubView()
                case .signalLab:
                    SignalLabView()
                case .spectralOracle:
                    SpectralOracleView()
                case .payloadLab:
                    PayloadLabView()
                case .captivePortal:
                    CaptivePortalArchitectView()
                case .opsCenter:
                    OpsCenterView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 640, minHeight: 480)
        }
        .preferredColorScheme(settings.appTheme == .system ? nil : (settings.appTheme == .dark ? .dark : .light))
        .sheet(isPresented: $showingQuickstart) {
            QuickstartSheetView()
        }
        .onAppear {
            if settings.enableWebMcpServer && !webMcp.isRunning {
                webMcp.start(port: settings.webMcpPort)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSection)) { notif in
            if let section = notif.object as? NavigationSection {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedSection = section
                }
            }
        }
    }
    
    @ViewBuilder
    private func sidebarRow(section: NavigationSection, badge: String? = nil, badgeColor: Color = VesperTheme.accentCyan, indicatorDot: Color? = nil) -> some View {
        NavigationLink(value: section) {
            HStack(spacing: 8) {
                Label(section.rawValue, systemImage: section.icon)
                    .font(.body)
                
                Spacer()
                
                if let dot = indicatorDot {
                    Circle()
                        .fill(dot)
                        .frame(width: 6, height: 6)
                }
                
                if let b = badge {
                    Text(b)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(badgeColor.opacity(0.18))
                        .foregroundColor(badgeColor)
                        .cornerRadius(4)
                }
            }
        }
    }
}
