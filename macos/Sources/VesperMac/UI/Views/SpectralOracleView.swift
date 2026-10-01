import SwiftUI

public struct SpectralOracleView: View {
    @State private var selectedTab: Int = 0 // 0 = AI Analysis, 1 = Signal Arsenal, 2 = Protocol KB
    @State private var rawSignalInput: String = """
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 433920000
Preset: FuriHalSubGhzPresetOok650Async
Protocol: RAW
RAW_Data: 450 -450 450 -450 900 -450 450 -900 450 -450 900 -450 900 -450 450 -900
"""
    @State private var oracleAnalysisOutput: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var openRouter = OpenRouterService.shared
    @State private var settings = AppSettings.shared
    @State private var connection = FlipperConnectionManager.shared
    
    private let arsenalSignals: [VaultSignal] = [
        VaultSignal(name: "Tesla Charge Port Door", type: .subghz, frequencyText: "433.92 MHz", protocolName: "RAW", path: "/ext/subghz/tesla_charge.sub", description: "Opens Tesla charge port doors via 433.92MHz OOK RF pulse sequence."),
        VaultSignal(name: "Nice Flo 12-bit Gate", type: .subghz, frequencyText: "433.92 MHz", protocolName: "Nice Flo", path: "/ext/subghz/nice_gate.sub", description: "Fixed-code gate transmitter pulse modulation."),
        VaultSignal(name: "Somfy RTS Blind Roller", type: .subghz, frequencyText: "433.42 MHz", protocolName: "Somfy RTS", path: "/ext/subghz/somfy_blind.sub", description: "Rolling-code window blind controller protocol."),
        VaultSignal(name: "Sony Bravia Power Toggle", type: .infrared, frequencyText: "38 kHz Carrier", protocolName: "SIRC 12-bit", path: "/ext/infrared/sony_tv.ir", description: "Infrared power toggle command for Sony displays."),
        VaultSignal(name: "Samsung TV Power/Mute", type: .infrared, frequencyText: "38 kHz Carrier", protocolName: "Samsung", path: "/ext/infrared/samsung.ir", description: "Standard Samsung IR remote commands."),
        VaultSignal(name: "Amiibo NTAG215 Zelda", type: .nfc, frequencyText: "13.56 MHz", protocolName: "ISO14443-3A", path: "/ext/nfc/zelda.nfc", description: "NFC NTAG215 gaming character transponder emulator."),
        VaultSignal(name: "EM4100 Standard Badge", type: .rfid, frequencyText: "125 kHz", protocolName: "EM4100", path: "/ext/lfrfid/badge.rfid", description: "125kHz low-frequency proximity access badge.")
    ]
    
    private let knownProtocols: [KnownProtocolDef] = [
        KnownProtocolDef(name: "Princeton PT2262", frequency: "315 / 433 MHz", modulation: "OOK (ASK)", securityTier: "INSECURE (Fixed Code)", description: "Widely used in wireless doorbells, cheap garage door openers, and RF power outlets. Zero replay protection.", isReplayable: true),
        KnownProtocolDef(name: "Nice Flo", frequency: "433.92 MHz", modulation: "OOK", securityTier: "INSECURE (Fixed Code)", description: "12-bit or 24-bit fixed dip-switch code. Easily replayed with 100% reliability.", isReplayable: true),
        KnownProtocolDef(name: "CAME (12-bit / 24-bit)", frequency: "433.92 MHz", modulation: "OOK Manchester", securityTier: "INSECURE (Fixed Code)", description: "Common Italian barrier and residential gate protocol. Fixed binary framing.", isReplayable: true),
        KnownProtocolDef(name: "KeeLoq Rolling Code", frequency: "433.92 / 868 MHz", modulation: "OOK / 2FSK", securityTier: "SECURE (Rolling Code)", description: "Cryptographically generated rolling code. Replay attacks are blocked; requires counter synchronization or de-sync rolljam.", isReplayable: false),
        KnownProtocolDef(name: "Somfy RTS", frequency: "433.42 MHz", modulation: "OOK (Manchester)", securityTier: "MODERATE (Rolling 16-bit)", description: "Radio Technology Somfy for awnings, blinds, and shutters. Uses a rolling frame counter.", isReplayable: false),
        KnownProtocolDef(name: "Linear MegaCode", frequency: "318.00 MHz", modulation: "OOK PWM", securityTier: "INSECURE (Fixed Facility Code)", description: "North American garage and commercial access protocol with fixed facility and transmitter IDs.", isReplayable: true)
    ]
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(VesperTheme.cyberPurple)
                            .frame(width: 64, height: 64)
                            .background(VesperTheme.cyberPurple.opacity(0.15))
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spectral Oracle & Signal Intelligence")
                                .font(.title2.bold())
                            Text("AI signal identification, RF protocol dissection, and vulnerability analysis.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(20)
                .glassCard()
                
                // Tab Selection
                Picker("", selection: $selectedTab) {
                    Text("AI Spectral Analysis").tag(0)
                    Text("Signal Arsenal").tag(1)
                    Text("Protocol Knowledge Base").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 480)
                
                if selectedTab == 0 {
                    // AI Analysis Interface
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Raw Signal Data / .sub Capture")
                                .font(.headline)
                            Spacer()
                            Button(action: runOracleAnalysis) {
                                if isAnalyzing {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Label("Run Oracle Analysis", systemImage: "sparkles")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(VesperTheme.accentCyan)
                                        .foregroundColor(.black)
                                        .cornerRadius(8)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isAnalyzing || rawSignalInput.isEmpty)
                        }
                        
                        TextEditor(text: $rawSignalInput)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(height: 120)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                            )
                        
                        if !oracleAnalysisOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .foregroundColor(VesperTheme.neonAmber)
                                    Text("Oracle Signal Intelligence Verdict")
                                        .font(.headline)
                                }
                                
                                Text(oracleAnalysisOutput)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(VesperTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(VesperTheme.accentCyan.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(20)
                    .glassCard()
                } else if selectedTab == 1 {
                    // Signal Arsenal
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: 16) {
                        ForEach(arsenalSignals) { signal in
                            SignalArsenalCard(signal: signal)
                        }
                    }
                } else {
                    // Protocol Knowledge Base
                    VStack(spacing: 12) {
                        ForEach(knownProtocols) { proto in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(proto.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(proto.securityTier)
                                        .font(.caption.monospaced().bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(proto.isReplayable ? VesperTheme.neonAmber.opacity(0.2) : VesperTheme.neonGreen.opacity(0.2))
                                        .foregroundColor(proto.isReplayable ? VesperTheme.neonAmber : VesperTheme.neonGreen)
                                        .cornerRadius(6)
                                }
                                
                                HStack(spacing: 16) {
                                    Label(proto.frequency, systemImage: "antenna.radiowaves.left.and.right")
                                    Label(proto.modulation, systemImage: "waveform")
                                }
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                
                                Text(proto.description)
                                    .font(.caption)
                                    .foregroundColor(.primary.opacity(0.9))
                            }
                            .padding(14)
                            .glassCard()
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(VesperTheme.darkBackground)
    }
    
    private func runOracleAnalysis() {
        isAnalyzing = true
        oracleAnalysisOutput = ""
        
        let prompt = """
Analyze the following Flipper Zero raw RF / Sub-GHz signal data:
\(rawSignalInput)

Provide a structured signal intelligence report including:
1. Identified Protocol & Estimated Carrier Frequency
2. Modulation Type (OOK / ASK / FSK)
3. Pulse Timing Pattern & Bit length
4. Security & Replay Vulnerability (Fixed code vs Rolling code)
5. Tactical Countermeasures or Defense
"""
        
        Task {
            do {
                try await openRouter.streamChat(
                    messages: [
                        ["role": "system", "content": "You are the Spectral Oracle, an elite signals intelligence AI expert in Sub-GHz, RF modulation, and wireless hardware protocols."],
                        ["role": "user", "content": prompt]
                    ],
                    apiKey: settings.openRouterApiKey,
                    model: settings.selectedModel
                ) { chunk in
                    if let text = chunk.textDelta {
                        self.oracleAnalysisOutput += text
                    }
                }
                self.isAnalyzing = false
            } catch {
                self.oracleAnalysisOutput = "Analysis failed: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }
}

private struct SignalArsenalCard: View {
    let signal: VaultSignal
    @State private var isTransmitting: Bool = false
    @State private var feedbackText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: signal.type.icon)
                    .font(.title3)
                    .foregroundColor(VesperTheme.accentCyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.name)
                        .font(.headline)
                    Text("\(signal.protocolName) • \(signal.frequencyText)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(signal.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Divider().background(VesperTheme.subtleBorder)
            
            HStack {
                Text(signal.path)
                    .font(.system(size: 9).monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    transmitSignal()
                }) {
                    if isTransmitting {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Label("Transmit", systemImage: "paperplane.fill")
                            .font(.caption.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(VesperTheme.neonAmber)
                            .cornerRadius(6)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTransmitting)
            }
            
            if !feedbackText.isEmpty {
                Text(feedbackText)
                    .font(.system(size: 9).monospaced())
                    .foregroundColor(VesperTheme.accentCyan)
            }
        }
        .padding(14)
        .glassCard()
    }
    
    private func transmitSignal() {
        isTransmitting = true
        feedbackText = "Transmitting on Flipper..."
        Task {
            let cmd: String
            switch signal.type {
            case .subghz: cmd = "subghz tx \(signal.path) 1"
            case .infrared: cmd = "ir tx \(signal.path)"
            default: cmd = "storage info \(signal.path)"
            }
            
            let res = try? await FlipperConnectionManager.shared.executeCommand(cmd)
            DispatchQueue.main.async {
                self.isTransmitting = false
                self.feedbackText = res != nil ? "✓ Transmitted successfully" : "Failed to transmit"
            }
        }
    }
}
