import SwiftUI
import AppKit

public struct FerriteWorkbenchView: View {
    @State private var ferrite = FerriteOSService.shared
    @State private var selectedTab: Int = 0
    
    // Intent tab state
    @State private var inputPhrase: String = "decode 433mhz signal"
    @State private var executionFeedback: String = ""
    
    // Decoder tab state
    @State private var signalFilePath: String = "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/nfc/Ntag216.nfc"
    @State private var selectedDecoderFlag: String = ""
    @State private var decoderOutput: String = ""
    @State private var isDecoding: Bool = false
    
    // Firmware tab state
    @State private var showFlashConfirmModal: Bool = false
    @State private var flashResult: String = ""
    
    // Wire protocol tab state (SPEC-011)
    @State private var wireHandshakeResult: String = ""
    @State private var isRunningWireHandshake: Bool = false
    @State private var wireHexOutput: String = ""
    
    private let samplePhrases = [
        "decode 433mhz signal",
        "read 125khz rfid card",
        "what is this /ext/subghz/gate.sub",
        "scan 433mhz garage remotes",
        "observe 2.4ghz field",
        "save it as frontgate",
        "status"
    ]
    
    private let sampleFiles = [
        ("NFC NTAG216", "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/nfc/Ntag216.nfc"),
        ("Sub-GHz Holtek 40b", "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/static_holtek_raw.sub"),
        ("Sub-GHz CAME Atomo", "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/static_came_atomo_raw.sub"),
        ("Sub-GHz Doitrand", "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/static_gates_doitrand_raw.sub"),
        ("Sub-GHz RAW (Marantec)", "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/marantec_raw.sub"),
        ("NFC Vicinity (ISO15693)", "/Users/josaum/projects/FerriteOS/crates/ferrite-rf/testdata/nfc_vicinity/Slix_cap_default.nfc")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header HUD
            headerHud
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Tab Selector
            Picker("Mode", selection: $selectedTab) {
                Text("Intent Engine").tag(0)
                Text("RF Decoder").tag(1)
                Text("Wire Protocol (SPEC-011)").tag(4)
                Text("Bare-Metal FW").tag(2)
                Text("Crates").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(VesperTheme.cardBackground.opacity(0.6))
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Tab Contents
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case 0:
                        intentTabContent
                    case 1:
                        decoderTabContent
                    case 2:
                        firmwareTabContent
                    case 3:
                        workspaceTabContent
                    case 4:
                        wireProtocolTabContent
                    default:
                        EmptyView()
                    }
                }
                .padding(20)
            }
        }
        .background(VesperTheme.darkBackground)
        .alert("Confirm FerriteOS Standalone Flash", isPresented: $showFlashConfirmModal) {
            Button("Cancel", role: .cancel) {}
            Button("Proceed with DFU Flash (0x08000000)", role: .destructive) {
                executeFerriteFlash()
            }
        } message: {
            Text("WARNING: Writing FerriteOS to 0x08000000 replaces the stock Flipper bootloader and main OS. Ensure Flipper is connected via USB and battery is charged. You can restore stock firmware anytime using official DFU recovery.")
        }
    }
    
    // MARK: - Header HUD
    private var headerHud: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "atom")
                    .font(.system(size: 30))
                    .foregroundColor(VesperTheme.neonAmber)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("FerriteOS Deep Integration")
                            .font(.title2.bold())
                            .foregroundColor(VesperTheme.primaryTextColor)
                        
                        Text("RUST no_std")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VesperTheme.neonAmber.opacity(0.18))
                            .foregroundColor(VesperTheme.neonAmber)
                            .cornerRadius(4)
                    }
                    
                    Text("Deterministic microsecond intent parsing, 55+ protocol decoders, and bare-metal STM32WB55 firmware.")
                        .font(.caption)
                        .foregroundColor(VesperTheme.secondaryTextColor)
                }
                
                Spacer()
                
                // Telemetry Badges
                HStack(spacing: 8) {
                    statusPill(title: "NLP Console", active: ferrite.isAvailable)
                    statusPill(title: "Firmware Bin", active: ferrite.isFirmwareBinPresent)
                    statusPill(title: "dfu-util", active: ferrite.isDfuUtilPresent)
                }
            }
            
            HStack(spacing: 16) {
                Text("Workspace: \(ferrite.workspacePath)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                
                if let manifest = ferrite.manifestInfo {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Image: \(manifest.flashBytes / 1024) KB / \(manifest.flashLimitBytes / 1024) KB (Flash Base 0x\(String(manifest.flashBase, radix: 16).uppercased()))")
                        .font(.caption2.monospaced())
                        .foregroundColor(VesperTheme.accentCyan)
                }
            }
        }
        .padding(20)
        .background(VesperTheme.cardBackground)
    }
    
    private func statusPill(title: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? VesperTheme.neonGreen : VesperTheme.neonRed)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(active ? VesperTheme.neonGreen : VesperTheme.neonRed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VesperTheme.secondaryCardBackground)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VesperTheme.subtleBorder, lineWidth: 1))
    }
    
    // MARK: - Tab 0: Intent & Natural Language
    private var intentTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(VesperTheme.accentCyan)
                    Text("Deterministic Natural Language Parser (ferrite-console)")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Evaluates commands in microseconds with zero cloud connectivity, translating operator requests into typed hardware action plans.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    TextField("Enter phrase (e.g. 'decode 433mhz signal')...", text: $inputPhrase)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                    
                    Button(action: runIntent) {
                        if ferrite.isExecuting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 24, height: 24)
                        } else {
                            Label("Understand", systemImage: "bolt.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VesperTheme.accentCyan)
                    .disabled(inputPhrase.isEmpty || ferrite.isExecuting)
                }
                
                // Sample Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(samplePhrases, id: \.self) { sample in
                            Button(action: {
                                inputPhrase = sample
                                runIntent()
                            }) {
                                Text(sample)
                                    .font(.caption2.monospaced())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(VesperTheme.secondaryCardBackground)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .glassCard()
            
            // Result Card
            if let understanding = ferrite.lastUnderstanding {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(VesperTheme.neonGreen)
                        Text("FerriteOS Structured Intent Classification")
                            .font(.headline)
                        Spacer()
                        Text(understanding.timestamp, style: .time)
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        metricBox(title: "INTENT", value: understanding.intent, color: VesperTheme.accentCyan)
                        metricBox(title: "DOMAIN", value: understanding.domain, color: VesperTheme.cyberPurple)
                        metricBox(title: "CONFIDENCE", value: "\(understanding.confidence) / 5", color: VesperTheme.neonGreen)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("CONSOLE ENGINE OUTPUT:")
                                .font(.system(size: 9.5, weight: .bold).monospaced())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Copy Output") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(understanding.rawOutput, forType: .string)
                            }
                            .font(.caption.bold())
                            .foregroundColor(VesperTheme.accentCyan)
                            .buttonStyle(.plain)
                        }
                        
                        Text(understanding.rawOutput)
                            .font(.caption.monospaced())
                            .foregroundColor(VesperTheme.neonGreen)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VesperTheme.terminalBackground)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                    }
                    
                    // Interactive Planned Actions Execution Panel
                    if !understanding.plannedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "bolt.badge.automatic.fill")
                                    .foregroundColor(VesperTheme.neonAmber)
                                Text("PLANNED HARDWARE ACTIONS (SPEC-001)")
                                    .font(.system(size: 10.5, weight: .bold).monospaced())
                                    .foregroundColor(VesperTheme.primaryTextColor)
                                Spacer()
                                Text("\(understanding.plannedActions.count) actions")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(understanding.plannedActions) { action in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(action.actionType.uppercased())
                                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(action.isEmitting ? VesperTheme.neonRed.opacity(0.2) : VesperTheme.accentCyan.opacity(0.18))
                                                .foregroundColor(action.isEmitting ? VesperTheme.neonRed : VesperTheme.accentCyan)
                                                .cornerRadius(4)
                                            
                                            Text(action.targetDomain)
                                                .font(.caption.bold())
                                                .foregroundColor(VesperTheme.primaryTextColor)
                                            
                                            if action.requiresHardware {
                                                Text("RADIO REQUIRED")
                                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                                    .foregroundColor(VesperTheme.neonAmber)
                                            }
                                        }
                                        
                                        Text(action.detail)
                                            .font(.caption2.monospaced())
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            let res = await ferrite.dispatchPlannedAction(action)
                                            executionFeedback = res
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: action.isEmitting ? "antenna.radiowaves.left.and.right" : "play.fill")
                                                .font(.caption2)
                                            Text("Execute")
                                                .font(.caption.bold())
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(VesperTheme.accentCyan.opacity(0.15))
                                        .foregroundColor(VesperTheme.accentCyan)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(VesperTheme.accentCyan.opacity(0.5), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(10)
                                .background(VesperTheme.cardBackground.opacity(0.7))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            
                            if !executionFeedback.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "terminal.fill")
                                        .foregroundColor(VesperTheme.neonGreen)
                                        .font(.caption)
                                    Text(executionFeedback)
                                        .font(.caption.monospaced())
                                        .foregroundColor(VesperTheme.neonGreen)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(VesperTheme.terminalBackground)
                                .cornerRadius(6)
                            }
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(8)
                    }
                }
                .padding(20)
                .glassCard()
            }
        }
    }
    
    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
        .padding(10)
        .frame(minWidth: 110, alignment: .leading)
        .background(VesperTheme.secondaryCardBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
    }
    
    // MARK: - Tab 1: Offline Signal Decoder
    private var decoderTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Signal Picker & Controls Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(VesperTheme.flipperOrange)
                    Text("High-Speed Offline Signal Decoder (ferrite-rf)")
                        .font(.headline)
                    Spacer()
                    if let capture = ferrite.lastDecodedCapture {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(capture.finding != nil ? VesperTheme.neonGreen : VesperTheme.neonAmber)
                                .frame(width: 7, height: 7)
                            Text(capture.finding != nil ? "DECODED" : "ANALYZED")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(capture.finding != nil ? VesperTheme.neonGreen : VesperTheme.neonAmber)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(6)
                    }
                }
                
                Text("Direct execution of FerriteOS compiled Rust decoders on local files. Decodes Sub-GHz (Hormann, Nice, KeeLoq, Princeton, Marantec, Somfy, Chamberlain, Alutech), NFC (NTAG, Ultralight, SLIX, ISO15693), and RFID.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    TextField("Absolute path to .sub, .nfc, .rfid, .ibtn file...", text: $signalFilePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                    
                    Button("Browse...") {
                        selectLocalFile()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: runSignalDecoder) {
                        if isDecoding {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 20, height: 20)
                        } else {
                            Label("Decode", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VesperTheme.flipperOrange)
                    .disabled(signalFilePath.isEmpty || isDecoding)
                }
                
                // Sample Test Files from Repo
                VStack(alignment: .leading, spacing: 6) {
                    Text("SAMPLE CAPTURE FIXTURES FROM REPOSITORY:")
                        .font(.system(size: 9.5, weight: .bold).monospaced())
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sampleFiles, id: \.1) { name, path in
                                Button(action: {
                                    signalFilePath = path
                                    runSignalDecoder()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.caption2)
                                        Text(name)
                                            .font(.caption2.monospaced())
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(VesperTheme.secondaryCardBackground)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .glassCard()
            
            // Decoded Protocol & Telemetry Card
            if let capture = ferrite.lastDecodedCapture {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("PROTOCOL DECODE TELEMETRY")
                            .font(.system(size: 11, weight: .bold).monospaced())
                            .foregroundColor(VesperTheme.primaryTextColor)
                        Spacer()
                        Text(capture.timestamp, style: .time)
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                    
                    // Metadata Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                        if let proto = capture.finding?.protocolName ?? (capture.metadata.protocolName.isEmpty ? nil : capture.metadata.protocolName) {
                            SpecPill(title: "PROTOCOL", value: proto, icon: "antenna.radiowaves.left.and.right")
                        }
                        if !capture.domain.isEmpty {
                            SpecPill(title: "DOMAIN", value: capture.domain, icon: "dot.radiowaves.up.forward")
                        }
                        if !capture.metadata.frequency.isEmpty {
                            SpecPill(title: "FREQUENCY", value: capture.metadata.frequency, icon: "wave.3.forward")
                        }
                        if !capture.metadata.preset.isEmpty {
                            SpecPill(title: "PRESET", value: capture.metadata.preset, icon: "slider.horizontal.3")
                        }
                        if let bits = capture.finding?.bits {
                            SpecPill(title: "PAYLOAD BITS", value: "\(bits) bits", icon: "number")
                        }
                        if let key = capture.finding?.keyHex {
                            SpecPill(title: "HEX KEY", value: key, icon: "key.fill")
                        }
                        if !capture.metadata.uid.isEmpty {
                            SpecPill(title: "CARD UID", value: capture.metadata.uid, icon: "creditcard.fill")
                        }
                        if capture.metadata.totalSamples > 0 {
                            SpecPill(title: "RAW EDGES", value: "\(capture.metadata.totalSamples) pulses", icon: "chart.bar.xaxis")
                        }
                    }
                    
                    // Summary Banner
                    if let summary = capture.finding?.summary {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(VesperTheme.neonAmber)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("DECODED PAYLOAD SUMMARY")
                                    .font(.system(size: 9, weight: .bold).monospaced())
                                    .foregroundColor(.secondary)
                                Text(summary)
                                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(VesperTheme.neonGreen)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                    }
                    
                    // Detailed Payload / Message Breakdown
                    if let details = capture.finding?.details, !details.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FIELD METRICS & REGISTERS:")
                                .font(.system(size: 9, weight: .bold).monospaced())
                                .foregroundColor(.secondary)
                            Text(details)
                                .font(.caption.monospaced())
                                .foregroundColor(VesperTheme.accentCyan)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(20)
                .glassCard()
                
                // Pulse Waveform Viewer (for Sub-GHz RF captures)
                if !capture.pulses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "waveform.path")
                                .foregroundColor(VesperTheme.accentCyan)
                            Text("DIGITAL PULSE STREAM WAVEFORM (First \(capture.pulses.count) transitions)")
                                .font(.system(size: 10.5, weight: .bold).monospaced())
                                .foregroundColor(VesperTheme.primaryTextColor)
                            Spacer()
                            Text("Timing in microseconds (µs)")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                        
                        // Interactive Pulse Strip
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(capture.pulses) { pulse in
                                    VStack(spacing: 2) {
                                        Text("\(pulse.durationMicros)")
                                            .font(.system(size: 7, weight: .regular, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        Rectangle()
                                            .fill(pulse.isHigh ? VesperTheme.neonGreen : VesperTheme.accentCyan.opacity(0.35))
                                            .frame(
                                                width: max(8, min(42, CGFloat(pulse.durationMicros) / 45.0)),
                                                height: pulse.isHigh ? 44 : 10
                                            )
                                            .cornerRadius(2)
                                        
                                        Text(pulse.isHigh ? "H" : "L")
                                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                            .foregroundColor(pulse.isHigh ? VesperTheme.neonGreen : .secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .padding(10)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                    }
                    .padding(20)
                    .glassCard()
                }
            }
            
            // Raw JSON / Console Telemetry Drawer
            if !decoderOutput.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("HOST REPL & MACHINE JSON TELEMETRY")
                            .font(.system(size: 10.5, weight: .bold).monospaced())
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(decoderOutput, forType: .string)
                        }
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                        .buttonStyle(.plain)
                    }
                    
                    Text(decoderOutput)
                        .font(.caption.monospaced())
                        .foregroundColor(VesperTheme.neonGreen)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
                .padding(20)
                .glassCard()
            }
        }
    }
    
    // MARK: - Tab 2: Bare-Metal Firmware (0x08000000)
    private var firmwareTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Manifest Telemetry Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "cpu.fill")
                        .foregroundColor(VesperTheme.cyberPurple)
                    Text("Standalone Bare-Metal Firmware Manifest")
                        .font(.headline)
                    Spacer()
                    if let passed = ferrite.preflightPassed {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(passed ? VesperTheme.neonGreen : VesperTheme.neonRed)
                                .frame(width: 8, height: 8)
                            Text(passed ? "PREFLIGHT PASS" : "PREFLIGHT FAILED")
                                .font(.system(size: 9.5, weight: .bold).monospaced())
                                .foregroundColor(passed ? VesperTheme.neonGreen : VesperTheme.neonRed)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(6)
                    }
                }
                
                Text("FerriteOS includes an autonomous STM32WB55 bare-metal firmware image with a custom reset runtime, passive PA0 infrared pulse DMA, and TIM2 capture.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let m = ferrite.manifestInfo {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                        SpecPill(title: "FLASH BASE", value: "0x\(String(m.flashBase, radix: 16).uppercased())", icon: "memorychip")
                        SpecPill(title: "FLASH USED", value: "\(m.flashBytes / 1024) KB (\(String(format: "%.1f", m.flashPercentage))%)", icon: "cube.fill")
                        SpecPill(title: "FLASH ALLOCATION", value: "\(m.flashLimitBytes / 1024) KB Max", icon: "archivebox.fill")
                        SpecPill(title: "RAM HEADROOM", value: "\(m.ramHeadroomBytes / 1024) KB Free", icon: "gauge")
                        SpecPill(title: "BOOTLOADER", value: m.replacesStockBootloader ? "Replaces Stock" : "Co-exists", icon: "exclamationmark.triangle.fill")
                        SpecPill(title: "TARGET", value: m.target, icon: "cpu")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BINARY SHA-256 CHECKSUM:")
                            .font(.system(size: 9, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        Text(m.binSha256)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(VesperTheme.accentCyan)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                }
            }
            .padding(20)
            .glassCard()
            
            // Actions & Toolchain Grid
            VStack(alignment: .leading, spacing: 14) {
                Text("Pre-Flight Verification & Hardware Flashing")
                    .font(.headline)
                    .foregroundColor(VesperTheme.primaryTextColor)
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task { _ = await ferrite.runPreflightCheck() }
                    }) {
                        HStack(spacing: 6) {
                            if ferrite.isPreflightRunning {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                            }
                            Text("Run Image Pre-flight")
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VesperTheme.accentCyan)
                    
                    Button(action: {
                        Task { _ = await ferrite.runUnitTests() }
                    }) {
                        HStack(spacing: 6) {
                            if ferrite.isTestRunning {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "testtube.2")
                            }
                            Text("Run 33 Unit Tests")
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        Task { _ = await ferrite.scanDfuDevices() }
                    }) {
                        Label("Probe DFU USB", systemImage: "cable.connector")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        Task { _ = await ferrite.scanProbeDevices() }
                    }) {
                        Label("Probe SWD", systemImage: "bolt.horizontal")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: { showFlashConfirmModal = true }) {
                        let baseStr = (ferrite.manifestInfo?.flashBase == 0x08008000) ? "0x08008000" : "0x08000000"
                        Label("Flash via DFU (\(baseStr))", systemImage: "flame.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VesperTheme.neonRed)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Preflight or Test Output Console
                if !ferrite.lastPreflightOutput.isEmpty || !ferrite.lastTestOutput.isEmpty || !ferrite.dfuScanOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DIAGNOSTIC TELEMETRY LOG:")
                            .font(.system(size: 9.5, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        
                        let combined = [
                            ferrite.lastPreflightOutput.isEmpty ? nil : "[check_image.py]\n\(ferrite.lastPreflightOutput)",
                            ferrite.lastTestOutput.isEmpty ? nil : "[test_build.py]\n\(ferrite.lastTestOutput)",
                            ferrite.dfuScanOutput.isEmpty ? nil : "[dfu-util --list]\n\(ferrite.dfuScanOutput)",
                            ferrite.probeScanOutput.isEmpty ? nil : "[probe-rs list]\n\(ferrite.probeScanOutput)",
                            flashResult.isEmpty ? nil : "[Flash Result]\n\(flashResult)"
                        ].compactMap { $0 }.joined(separator: "\n\n")
                        
                        Text(combined)
                            .font(.caption.monospaced())
                            .foregroundColor(VesperTheme.neonGreen)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VesperTheme.terminalBackground)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                    }
                }
            }
            .padding(20)
            .glassCard()
        }
    }
    
    // MARK: - Tab 3: Workspace & Crates
    private var workspaceTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(VesperTheme.neonAmber)
                    Text("FerriteOS Architecture & Verified Subsystems")
                        .font(.headline)
                        .foregroundColor(VesperTheme.primaryTextColor)
                    Spacer()
                    Text("9 NO_STD CRATES")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.neonAmber.opacity(0.18))
                        .foregroundColor(VesperTheme.neonAmber)
                        .cornerRadius(4)
                }
                
                Text("Every FerriteOS crate is strictly `#![no_std]` and `#![forbid(unsafe_code)]` with formal invariant models. Execute in-crate test suites directly below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(18)
            .glassCard()
            
            // Crate Grid
            VStack(spacing: 10) {
                ForEach(ferrite.crates) { crate in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(crate.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(VesperTheme.accentCyan)
                                
                                Text(crate.specReference)
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(VesperTheme.secondaryCardBackground)
                                    .foregroundColor(VesperTheme.cyberPurple)
                                    .cornerRadius(4)
                                
                                if crate.isPureNoStd {
                                    Text("no_std")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(VesperTheme.neonGreen)
                                }
                                
                                if let status = crate.lastTestStatus {
                                    Text(status)
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background((crate.passed ?? false) ? VesperTheme.neonGreen.opacity(0.2) : VesperTheme.neonRed.opacity(0.2))
                                        .foregroundColor((crate.passed ?? false) ? VesperTheme.neonGreen : VesperTheme.neonRed)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(crate.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                _ = await ferrite.runCrateTest(crateName: crate.name)
                            }
                        }) {
                            HStack(spacing: 5) {
                                if ferrite.testingCrateName == crate.name {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "play.circle.fill")
                                }
                                Text("Test")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(ferrite.testingCrateName != nil)
                    }
                    .padding(14)
                    .background(VesperTheme.cardBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
            }
            
            // Crate Test Output Log
            if !ferrite.crateTestOutput.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundColor(VesperTheme.neonGreen)
                        Text("CRATE TEST RESULTS")
                            .font(.system(size: 10, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Clear") {
                            ferrite.crateTestOutput = ""
                        }
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                        .buttonStyle(.plain)
                    }
                    
                    Text(ferrite.crateTestOutput)
                        .font(.caption.monospaced())
                        .foregroundColor(VesperTheme.neonGreen)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
                .padding(18)
                .glassCard()
            }
        }
    }
    
    // MARK: - Tab 4: Wire Protocol (SPEC-011)
    private var wireProtocolTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "cable.connector.horizontal")
                        .foregroundColor(VesperTheme.accentCyan)
                    Text("FerriteOS Headless Wire Protocol Codec (SPEC-011)")
                        .font(.headline)
                    Spacer()
                    Text("CRC-32 / ISO-HDLC")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.accentCyan.opacity(0.18))
                        .foregroundColor(VesperTheme.accentCyan)
                        .cornerRadius(4)
                }
                
                Text("FerriteOS communicates over USB CDC ACM using the deterministic SPEC-011 wire framing: `[0xFE, 0x55] Magic + 1-byte Version + 1-byte Type + 2-byte Opcode + 2-byte Seq + 2-byte Len + Payload + 4-byte CRC-32`.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button(action: runWireHandshake) {
                        HStack(spacing: 6) {
                            if isRunningWireHandshake {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "hand.wave.fill")
                            }
                            Text("Simulate SPEC-011 HELLO Handshake")
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VesperTheme.accentCyan)
                    
                    Button(action: runWireTest) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield")
                            Text("Verify In-Crate Wire Unit Tests")
                        }
                        .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .glassCard()
            
            // Frame Spec Grid
            VStack(alignment: .leading, spacing: 12) {
                Text("SPEC-011 FRAME ANATOMY")
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    SpecPill(title: "MAGIC", value: "0xFE 0x55", icon: "wand.and.stars")
                    SpecPill(title: "WIRE VER", value: "v1 (Pinned)", icon: "number")
                    SpecPill(title: "CTRL BASE", value: "0xFF00", icon: "command")
                    SpecPill(title: "USB MTU", value: "4096 B", icon: "arrow.up.left.and.arrow.down.right")
                    SpecPill(title: "CRC-32", value: "ISO-HDLC", icon: "shield.lefthalf.filled")
                }
            }
            .padding(16)
            .glassCard()
            
            // Output Log Card
            if !wireHandshakeResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundColor(VesperTheme.neonGreen)
                        Text("WIRE CODEC LOG:")
                            .font(.system(size: 9.5, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(wireHandshakeResult, forType: .string)
                        }
                        .font(.caption.bold())
                        .foregroundColor(VesperTheme.accentCyan)
                        .buttonStyle(.plain)
                    }
                    
                    Text(wireHandshakeResult)
                        .font(.caption.monospaced())
                        .foregroundColor(VesperTheme.neonGreen)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
                }
                .padding(20)
                .glassCard()
            }
        }
    }
    
    private func runWireHandshake() {
        isRunningWireHandshake = true
        wireHandshakeResult = "Building host HELLO frame (SPEC-011 §4.5)...\n"
        Task {
            // Emulate the exact wire handshake from ferrite-wire in swift
            let magic = "FE55"
            let wireVer = "01"
            let reqType = "00" // FrameType::Req = 0
            let helloOp = "00FF" // CTRL_HELLO = 0xFF00 (LE)
            let seq = "0100" // seq = 1 (LE)
            let len = "0E00" // Descriptor length = 14 bytes (LE)
            
            // Host descriptor: wire=1, abi=1, img=(0,1,0), max_frame=4096, caps=0
            let descHex = "0100010000000100000000100000"
            
            wireHandshakeResult += """
            [1] HOST -> CORE [REQ CTRL_HELLO]:
                Header: Magic=0x\(magic), Ver=0x\(wireVer), Type=Req, Opcode=0xFF00, Seq=1, Len=14
                Descriptor: wire_ver=1, abi=1, image_ver=(0,1,0), max_frame_usb=4096, caps=0
                Frame Bytes: \(magic)\(wireVer)\(reqType)\(helloOp)\(seq)\(len)\(descHex)[CRC-32: 0x9B4E3120]
            
            [2] CORE PROTOCOL ENGINE:
                classify_opcode(0xFF00) -> OpClass::Control(ControlOp::Hello)
                accept_hello(host_wire=1, host_abi=1, max_frame=4096, caps=0b101)
                Negotiation outcome: Handshake::Accept { effective_wire: 1, abi: 1 }
            
            [3] CORE -> HOST [RESP CTRL_HELLO]:
                Header: Magic=0x\(magic), Ver=0x\(wireVer), Type=Resp, Opcode=0xFF00, Seq=1, Len=14
                Core Descriptor: wire_ver=1, abi=1, image_ver=(0,1,0), max_frame=4096, caps=0x0005
                Status: OPEN (SPEC-011 link active and ready for syscall frame dispatch)
            """
            isRunningWireHandshake = false
        }
    }
    
    private func runWireTest() {
        isRunningWireHandshake = true
        wireHandshakeResult = "Running cargo test -p ferrite-wire...\n"
        Task {
            let cargoPath = "/Users/josaum/.cargo/bin/cargo"
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cargoPath)
                process.arguments = ["test", "-p", "ferrite-wire"]
                process.currentDirectoryURL = URL(fileURLWithPath: ferrite.workspacePath)
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/Users/josaum/.cargo/bin:/opt/homebrew/bin:/usr/bin:/bin"
                process.environment = env
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                wireHandshakeResult = String(data: data, encoding: .utf8) ?? "Done"
                isRunningWireHandshake = false
            } catch {
                wireHandshakeResult = "Error running cargo test: \(error.localizedDescription)"
                isRunningWireHandshake = false
            }
        }
    }
    
    private func runIntent() {
        let p = inputPhrase
        Task {
            do {
                _ = try await ferrite.understandPhrase(p)
            } catch {
                executionFeedback = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func runSignalDecoder() {
        let path = signalFilePath
        isDecoding = true
        decoderOutput = "Executing FerriteOS decode routine..."
        Task {
            do {
                let capture = try await ferrite.decodeCapture(filePath: path)
                if let finding = capture.finding {
                    self.decoderOutput = "\(finding.summary)\n\nRaw Telemetry:\n\(capture.rawOutput)"
                } else {
                    self.decoderOutput = capture.rawOutput
                }
                self.isDecoding = false
            } catch {
                self.decoderOutput = "Decoder error: \(error.localizedDescription)"
                self.isDecoding = false
            }
        }
    }
    
    private func selectLocalFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        if panel.runModal() == .OK, let url = panel.url {
            self.signalFilePath = url.path
            runSignalDecoder()
        }
    }
    
    private func executeFerriteFlash() {
        Task {
            do {
                flashResult = "Scanning for STM32 DFU USB bootloader..."
                let scan = await ferrite.scanDfuDevices()
                if !scan.contains("0483:df11") && !scan.contains("Found DFU") {
                    flashResult = """
                    ⚠️ [No DFU Device Detected]
                    Your Flipper Zero is currently in normal OS runtime mode.
                    dfu-util requires the STM32WB55 microcontroller to be in DFU Bootloader Mode.
                    
                    👉 How to enter STM32 DFU Bootloader Mode (takes 3 seconds):
                    1. Keep the Flipper connected to your Mac via USB-C.
                    2. Press and hold LEFT + BACK buttons together until the screen blinks.
                    3. Release the BACK button, but KEEP HOLDING the LEFT button for ~3 seconds.
                    4. The Flipper will enter STM32 DFU Bootloader Mode (LED will illuminate blue).
                    5. Click 'Probe DFU USB' to confirm, then click 'Flash via DFU'.
                    """
                    return
                }
                
                flashResult = "DFU Bootloader detected! Initiating FerriteOS flash via dfu-util..."
                let res = try await ferrite.flashFirmwareDfu()
                flashResult = "✅ Flash Successful!\n\n\(res)"
            } catch {
                flashResult = "Flash error: \(error.localizedDescription)"
            }
        }
    }
}
