import SwiftUI

public struct ChatView: View {
    @State private var agent = VesperAgent.shared
    @State private var connection = FlipperConnectionManager.shared
    @State private var voice = AudioVoiceService.shared
    @State private var workflowEngine = WorkflowEngine.shared
    @State private var settings = AppSettings.shared
    @State private var showConsoleDrawer: Bool = false
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    
    public init() {}
    
    private let quickPrompts = [
        "🎯 /goal Audit RF spectrum on 433.92 & 315 MHz and decode captures",
        "🎯 /goal Inspect SD card /ext and catalog all payloads and keys",
        "Run Sub-GHz Spectrum Recon Workflow",
        "Run Flipper Diagnostic Health Self-Test",
        "Run Access Control & Badge Audit",
        "What's my battery level and storage?",
        "Flash the RGB LED cyan and vibrate for 1s"
    ]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Live Flipper Telemetry & Status HUD
            HStack(spacing: 12) {
                // Connection Status & Battery
                HStack(spacing: 8) {
                    Circle()
                        .fill(connection.status.isConnected ? VesperTheme.neonGreen : VesperTheme.neonRed)
                        .frame(width: 8, height: 8)
                    Text(connection.status.description)
                        .font(.caption.monospaced())
                        .foregroundColor(.primary)
                    
                    if connection.status.isConnected {
                        HStack(spacing: 4) {
                            Image(systemName: connection.deviceInfo.isCharging ? "bolt.fill" : "battery.75percent")
                                .foregroundColor(connection.deviceInfo.batteryLevel < 20 ? VesperTheme.neonRed : VesperTheme.neonGreen)
                            Text("\(connection.deviceInfo.batteryLevel)%")
                                .font(.caption2.bold().monospaced())
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.secondaryCardBackground)
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Autonomous Autopilot Mode Badge & Toggle
                Button(action: {
                    withAnimation {
                        settings.autopilotMode = (settings.autopilotMode == .autonomous) ? .supervised : .autonomous
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: settings.autopilotMode == .autonomous ? "bolt.shield.fill" : "shield.lefthalf.filled")
                            .font(.caption2)
                            .foregroundColor(settings.autopilotMode == .autonomous ? VesperTheme.neonGreen : .secondary)
                        Text(settings.autopilotMode == .autonomous ? "AUTOPILOT: ON" : "SUPERVISED")
                            .font(.system(size: 9.5, weight: .bold).monospaced())
                            .foregroundColor(settings.autopilotMode == .autonomous ? VesperTheme.neonGreen : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(settings.autopilotMode == .autonomous ? VesperTheme.neonGreen.opacity(0.15) : VesperTheme.secondaryCardBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(settings.autopilotMode == .autonomous ? VesperTheme.neonGreen.opacity(0.5) : VesperTheme.subtleBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Toggle between Full Autonomous Autopilot and Supervised Mode")
                
                // If currently running autonomous steps, show pause / resume button
                if agent.currentAutonomousIteration > 0 && agent.isThinking {
                    Button(action: {
                        if agent.isAutonomousPaused {
                            Task { await agent.resumeAutopilot() }
                        } else {
                            agent.pauseAutopilot()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: agent.isAutonomousPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 9))
                            Text(agent.isAutonomousPaused ? "Resume" : "Pause")
                                .font(.system(size: 9, weight: .bold).monospaced())
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VesperTheme.neonAmber.opacity(0.2))
                        .foregroundColor(VesperTheme.neonAmber)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                // Real-time Flipper Activity Pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(connection.currentActivity.contains("Active") || connection.currentActivity.contains("Exec") ? VesperTheme.neonAmber : VesperTheme.accentCyan)
                        .frame(width: 6, height: 6)
                    Text(connection.currentActivity)
                        .font(.caption2.bold().monospaced())
                        .foregroundColor(VesperTheme.accentCyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(VesperTheme.accentCyan.opacity(0.12))
                .cornerRadius(6)
                
                // Live Serial Telemetry Console Toggle
                Button(action: { showConsoleDrawer.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.caption)
                        Text(showConsoleDrawer ? "Hide Stream" : "Live Telemetry")
                            .font(.caption2.monospaced())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(showConsoleDrawer ? VesperTheme.accentCyan.opacity(0.25) : VesperTheme.secondaryCardBackground)
                    .foregroundColor(showConsoleDrawer ? VesperTheme.accentCyan : .secondary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Toggle live serial stream console drawer")
                
                Text(agent.statusText)
                    .font(.caption.monospaced())
                    .foregroundColor(VesperTheme.accentCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VesperTheme.accentCyan.opacity(0.1))
                    .cornerRadius(6)
                
                Button(action: {
                    agent.messages = [ChatMessage(role: .assistant, content: "Conversation cleared. Vesper is ready.")]
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Clear chat history")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(VesperTheme.cardBackground)
            
            // Expandable Live Serial Stream Console Drawer
            if showConsoleDrawer {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("FLIPPER SERIAL REAL-TIME STREAM")
                            .font(.system(size: 10, weight: .bold).monospaced())
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("TX: \(connection.txBytesTotal) B  |  RX: \(connection.rxBytesTotal) B")
                            .font(.system(size: 10).monospaced())
                            .foregroundColor(VesperTheme.accentCyan)
                        
                        Button(action: {
                            let text = connection.recentLogLines.joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.system(size: 9.5).monospaced())
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy logs to clipboard")
                        
                        Button(action: {
                            connection.recentLogLines.removeAll()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear stream buffer")
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(connection.recentLogLines.suffix(16).enumerated()), id: \.offset) { item in
                                    Text(item.element)
                                        .font(.system(size: 10.5).monospaced())
                                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(item.offset)
                                }
                            }
                        }
                        .frame(maxHeight: 110)
                    }
                }
                .padding(10)
                .background(VesperTheme.terminalBackground)
                .border(VesperTheme.subtleBorder, width: 1)
            }
            
            // Real-Time Active Workflow Banner with Live Pause Controls
            if let activeWf = workflowEngine.activeWorkflow, workflowEngine.isExecuting || workflowEngine.isPaused {
                HStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundColor(activeWf.executionState.color)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("WORKFLOW:")
                                .font(.system(size: 9, weight: .bold).monospaced())
                                .foregroundColor(.secondary)
                            Text(activeWf.title)
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                            Text(activeWf.executionState.rawValue)
                                .font(.system(size: 9, weight: .bold).monospaced())
                                .foregroundColor(activeWf.executionState.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(activeWf.executionState.color.opacity(0.18))
                                .cornerRadius(4)
                        }
                        
                        ProgressView(value: activeWf.progressFraction)
                            .progressViewStyle(.linear)
                            .tint(activeWf.executionState.color)
                    }
                    
                    Spacer()
                    
                    // Workflow Interactive Pause / Resume / Step / Stop Buttons
                    HStack(spacing: 8) {
                        if workflowEngine.isPaused {
                            Button(action: { workflowEngine.resume() }) {
                                Label("Resume", systemImage: "play.fill")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(VesperTheme.neonGreen.opacity(0.2))
                                    .foregroundColor(VesperTheme.neonGreen)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(VesperTheme.neonGreen, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { workflowEngine.pause() }) {
                                Label("Pause", systemImage: "pause.fill")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(VesperTheme.neonAmber.opacity(0.25))
                                    .foregroundColor(VesperTheme.neonAmber)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(VesperTheme.neonAmber, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: { workflowEngine.step() }) {
                            Image(systemName: "forward.frame.fill")
                                .font(.caption2)
                                .padding(6)
                                .background(VesperTheme.secondaryCardBackground)
                                .foregroundColor(.secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(workflowEngine.isExecuting && !workflowEngine.isPaused)
                        .help("Step next task")
                        
                        Button(action: { workflowEngine.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.caption2)
                                .padding(6)
                                .background(VesperTheme.secondaryCardBackground)
                                .foregroundColor(VesperTheme.neonRed)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(VesperTheme.cardBackground.opacity(0.95))
                .border(activeWf.executionState.color.opacity(0.4), width: 1)
            }
            
            Divider()
                .background(VesperTheme.subtleBorder)
            
            // Messages Scroll Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(agent.messages) { message in
                            MessageRow(message: message) { action in
                                handleProactiveAction(action)
                            }
                            .id(message.id)
                        }
                        
                        if let pending = agent.pendingConfirmation {
                            PendingConfirmationCard(toolCall: pending)
                                .id("pendingCard")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: agent.messages.count) {
                    if let last = agent.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
                .background(VesperTheme.subtleBorder)
            
            // Quick Prompts Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button(action: {
                            inputText = prompt
                            submitMessage()
                        }) {
                            Text(prompt)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(VesperTheme.secondaryCardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(VesperTheme.cardBackground.opacity(0.5))
            
            // Interactive Slash Command Autocomplete Bar
            if inputText.hasPrefix("/") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SlashCommandChip(cmd: "/goal ", desc: "Autonomous mission", icon: "target") {
                            inputText = "/goal "
                            isInputFocused = true
                        }
                        SlashCommandChip(cmd: "/recon", desc: "Sub-GHz recon", icon: "waveform.path.ecg") {
                            inputText = "/recon"
                            submitMessage()
                        }
                        SlashCommandChip(cmd: "/firmware", desc: "Firmware hub", icon: "arrow.triangle.2.circlepath") {
                            inputText = "/firmware"
                            submitMessage()
                        }
                        SlashCommandChip(cmd: "/health", desc: "Diagnostic self-test", icon: "cross.case.fill") {
                            inputText = "/health"
                            submitMessage()
                        }
                        SlashCommandChip(cmd: "/audit", desc: "RFID/NFC audit", icon: "lock.shield.fill") {
                            inputText = "/audit"
                            submitMessage()
                        }
                        SlashCommandChip(cmd: "/ferrite ", desc: "FerriteOS parser", icon: "atom") {
                            inputText = "/ferrite "
                            isInputFocused = true
                        }
                        SlashCommandChip(cmd: "/theme", desc: "Toggle theme", icon: "paintpalette.fill") {
                            inputText = "/theme"
                            submitMessage()
                        }
                        SlashCommandChip(cmd: "/clear", desc: "Clear chat", icon: "trash") {
                            inputText = "/clear"
                            submitMessage()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .background(VesperTheme.cardBackground)
                .transition(.opacity)
            }
            
            // Input Bar
            HStack(spacing: 10) {
                Button(action: {
                    if inputText.hasPrefix("/goal ") {
                        inputText = String(inputText.dropFirst(6))
                    } else {
                        inputText = "/goal " + inputText
                    }
                    isInputFocused = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 11, weight: .bold))
                        Text("Goal")
                            .font(.system(size: 10.5, weight: .bold).monospaced())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(inputText.hasPrefix("/goal ") ? VesperTheme.neonAmber.opacity(0.25) : VesperTheme.secondaryCardBackground)
                    .foregroundColor(inputText.hasPrefix("/goal ") ? VesperTheme.neonAmber : .secondary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(inputText.hasPrefix("/goal ") ? VesperTheme.neonAmber : VesperTheme.subtleBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Toggle autonomous multi-step mission goal prefix (/goal)")
                
                TextField("Prompt Vesper or set goal (e.g. '/goal audit 433MHz signals')...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitMessage()
                    }
                    .padding(10)
                    .background(VesperTheme.secondaryCardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isInputFocused ? VesperTheme.accentCyan.opacity(0.8) : VesperTheme.subtleBorder, lineWidth: 1)
                    )
                
                Button(action: toggleVoiceDictation) {
                    Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(voice.isListening ? VesperTheme.neonRed : VesperTheme.accentCyan)
                }
                .buttonStyle(.plain)
                .help(voice.isListening ? "Stop Voice Dictation" : "Dictate Prompt with Voice")
                
                Button(action: submitMessage) {
                    if agent.isThinking {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .secondary : VesperTheme.accentCyan)
                    }
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || agent.isThinking)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(16)
            .background(VesperTheme.cardBackground)
        }
        .background(VesperTheme.darkBackground)
    }
    
    private func toggleVoiceDictation() {
        if voice.isListening {
            voice.stopListening()
        } else {
            Task {
                do {
                    try await voice.startListening { text in
                        self.inputText = text
                    }
                } catch {
                    voice.stopListening()
                }
            }
        }
    }
    
    private func submitMessage() {
        if voice.isListening {
            voice.stopListening()
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        
        let lower = text.lowercased()
        
        // Native Slash Commands
        if text == "/clear" {
            agent.messages = [ChatMessage(role: .assistant, content: "Conversation cleared. Vesper is ready.")]
            return
        } else if text == "/theme" {
            switch settings.appTheme {
            case .system: settings.appTheme = .light
            case .light: settings.appTheme = .dark
            case .dark: settings.appTheme = .system
            }
            agent.messages.append(ChatMessage(role: .assistant, content: "🎨 Switched appearance to **\(settings.appTheme.rawValue)**."))
            return
        } else if text == "/recon" {
            agent.messages.append(ChatMessage(role: .user, content: "/recon (Sub-GHz Spectrum Recon)"))
            workflowEngine.start(workflow: WorkflowEngine.createSubGhzReconWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Sub-GHz Full Spectrum Recon Workflow. Monitoring live execution across subgraphs."))
            return
        } else if text == "/health" {
            agent.messages.append(ChatMessage(role: .user, content: "/health (Flipper Diagnostic Self-Test)"))
            workflowEngine.start(workflow: WorkflowEngine.createDiagnosticHealthWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Flipper Hardware Diagnostic Self-Test. Inspecting battery, storage, and radio status."))
            return
        } else if text == "/audit" {
            agent.messages.append(ChatMessage(role: .user, content: "/audit (Access Control & Badge Audit)"))
            workflowEngine.start(workflow: WorkflowEngine.createAccessControlAuditWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Access Control & Badge Audit Workflow. Executing RFID/NFC subgraphs with live telemetry."))
            return
        } else if text == "/firmware" {
            agent.messages.append(ChatMessage(role: .user, content: "/firmware (Firmware Diagnostics & Updates)"))
            workflowEngine.start(workflow: WorkflowEngine.createFirmwareDiagnosticAndFlashWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Firmware Diagnostic & Flash Workflow. Pre-flight checks starting."))
            return
        } else if text.hasPrefix("/ferrite ") {
            let query = String(text.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            agent.messages.append(ChatMessage(role: .user, content: text))
            Task {
                do {
                    let res = try await FerriteOSService.shared.understandPhrase(query)
                    let reply = "🦀 **FerriteOS Intent Engine Result**:\n\n• **Phrase**: `\(query)`\n• **Intent**: `\(res.intent)`\n• **Domain**: `\(res.domain)`\n• **Confidence**: `\(res.confidence)/5`\n\n```\n\(res.rawOutput)\n```"
                    agent.messages.append(ChatMessage(role: .assistant, content: reply))
                } catch {
                    agent.messages.append(ChatMessage(role: .assistant, content: "⚠️ FerriteOS Error: \(error.localizedDescription)"))
                }
            }
            return
        }
        
        // Natural Language Workflow Triggers
        if lower.contains("sub-ghz") && lower.contains("workflow") {
            agent.messages.append(ChatMessage(role: .user, content: text))
            workflowEngine.start(workflow: WorkflowEngine.createSubGhzReconWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Sub-GHz Full Spectrum Recon Workflow. Monitoring live execution across subgraphs. You can pause or step through tasks using the HUD bar above."))
            return
        } else if lower.contains("diagnostic") || lower.contains("self-test") {
            agent.messages.append(ChatMessage(role: .user, content: text))
            workflowEngine.start(workflow: WorkflowEngine.createDiagnosticHealthWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Flipper Hardware Diagnostic Self-Test. Monitoring live execution across subgraphs. Use the HUD controls to pause or inspect."))
            return
        } else if lower.contains("access control") || lower.contains("badge") {
            agent.messages.append(ChatMessage(role: .user, content: text))
            workflowEngine.start(workflow: WorkflowEngine.createAccessControlAuditWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Access Control & Badge Audit Workflow. Executing RFID/NFC subgraphs with live telemetry."))
            return
        } else if lower.contains("flash") && lower.contains("workflow") {
            agent.messages.append(ChatMessage(role: .user, content: text))
            workflowEngine.start(workflow: WorkflowEngine.createFirmwareDiagnosticAndFlashWorkflow())
            agent.messages.append(ChatMessage(role: .assistant, content: "🚀 Initiated Firmware Diagnostic & Flash Workflow. Validating Flipper battery & storage preflight before staging."))
            return
        }
        
        Task {
            await agent.sendMessage(text)
        }
    }
    
    private func handleProactiveAction(_ action: ProactiveAction) {
        let cmd = action.promptOrCommand
        let lower = cmd.lowercased()
        
        if lower.contains("sub-ghz spectrum recon") || lower.contains("sub-ghz full spectrum") {
            agent.messages.append(ChatMessage(role: .user, content: "Trigger Workflow: Sub-GHz Spectrum Recon"))
            workflowEngine.start(workflow: WorkflowEngine.createSubGhzReconWorkflow())
            agent.messages.append(ChatMessage(
                role: .assistant,
                content: "🚀 Initiated Sub-GHz Full Spectrum Recon Workflow. Monitoring live execution across subgraphs. You can pause or step through tasks using the HUD bar above."
            ))
        } else if lower.contains("diagnostic health") || lower.contains("diagnostic self-test") {
            agent.messages.append(ChatMessage(role: .user, content: "Trigger Workflow: Flipper Health Self-Test"))
            workflowEngine.start(workflow: WorkflowEngine.createDiagnosticHealthWorkflow())
            agent.messages.append(ChatMessage(
                role: .assistant,
                content: "🚀 Initiated Flipper Hardware Diagnostic Self-Test. Monitoring live execution across subgraphs."
            ))
        } else if lower.contains("access control") || lower.contains("badge audit") {
            agent.messages.append(ChatMessage(role: .user, content: "Trigger Workflow: Access Control & Badge Audit"))
            workflowEngine.start(workflow: WorkflowEngine.createAccessControlAuditWorkflow())
            agent.messages.append(ChatMessage(
                role: .assistant,
                content: "🚀 Initiated Access Control & Badge Audit Workflow. Executing RFID/NFC subgraphs with live telemetry."
            ))
        } else {
            inputText = cmd
            submitMessage()
        }
    }
}

private struct SlashCommandChip: View {
    let cmd: String
    let desc: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(VesperTheme.accentCyan)
                Text(cmd)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(VesperTheme.primaryTextColor)
                Text("(\(desc))")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VesperTheme.secondaryCardBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(VesperTheme.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    var onSelectAction: ((ProactiveAction) -> Void)? = nil
    @State private var hasCopied: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 40)
            } else {
                Circle()
                    .fill(VesperTheme.cyberPurple.gradient)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "cpu")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if !message.content.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(message.content))
                            .font(.body)
                            .textSelection(.enabled)
                        
                        if message.role == .assistant {
                            HStack(spacing: 12) {
                                Spacer()
                                
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.content, forType: .string)
                                    hasCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        hasCopied = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                        Text(hasCopied ? "Copied" : "Copy")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(hasCopied ? VesperTheme.neonGreen : VesperTheme.secondaryTextColor)
                                }
                                .buttonStyle(.plain)
                                .help("Copy response text to clipboard")
                                
                                Button(action: { AudioVoiceService.shared.speak(text: message.content) }) {
                                    Label("Speak", systemImage: "speaker.wave.2")
                                        .font(.caption2)
                                        .foregroundColor(VesperTheme.accentCyan.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Read Aloud")
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(message.role == .user ? VesperTheme.cyberPurple.opacity(0.18) : VesperTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(message.role == .user ? VesperTheme.cyberPurple.opacity(0.4) : VesperTheme.subtleBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                }
                
                // Tool Calls Display
                ForEach(message.toolCalls) { tool in
                    ToolCallBadge(tool: tool)
                }
                
                // Tool Results Display
                ForEach(message.toolResults) { result in
                    ToolResultRow(result: result)
                }
                
                // Proactive Action Suggestions Cards
                if message.role == .assistant && !message.suggestedActions.isEmpty && !message.isStreaming {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(VesperTheme.accentCyan)
                            Text("PROACTIVE RECOMMENDATIONS")
                                .font(.system(size: 9.5, weight: .bold).monospaced())
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(message.suggestedActions) { action in
                                    Button(action: { onSelectAction?(action) }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: action.icon)
                                                .font(.caption2)
                                                .foregroundColor(VesperTheme.accentCyan)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(action.title)
                                                    .font(.caption.bold())
                                                    .foregroundColor(VesperTheme.primaryTextColor)
                                                Text(action.category.uppercased())
                                                    .font(.system(size: 8, weight: .bold).monospaced())
                                                    .foregroundColor(.secondary)
                                            }
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 9))
                                                .foregroundColor(VesperTheme.accentCyan)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(VesperTheme.secondaryCardBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(VesperTheme.accentCyan.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            } else {
                Circle()
                    .fill(VesperTheme.accentCyan.gradient)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                    )
            }
        }
    }
}

private struct ToolResultRow: View {
    let result: ToolResult
    @State private var hasCopied: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.isError ? "exclamationmark.triangle.fill" : "terminal.fill")
                    .foregroundColor(result.isError ? VesperTheme.neonRed : VesperTheme.neonGreen)
                    .font(.caption)
                Text(result.isError ? "Hardware Error" : "Flipper Hardware Output")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.output, forType: .string)
                    hasCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { hasCopied = false }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                        Text(hasCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 9.5).monospaced())
                    .foregroundColor(hasCopied ? VesperTheme.neonGreen : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(result.output)
                .font(.system(size: 10.5, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(result.isError ? VesperTheme.neonRed : Color(red: 0.2, green: 0.9, blue: 0.4))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VesperTheme.terminalBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                )
        }
        .padding(10)
        .glassCard()
    }
}

private struct ToolCallBadge: View {
    let tool: ToolCall
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                if !tool.parameters.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(VesperTheme.neonAmber)
                    
                    Text("Tool: \(tool.action)")
                        .font(.caption.monospaced().bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                    
                    Spacer()
                    
                    Text(tool.riskLevel.rawValue)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(riskColor.opacity(0.18))
                        .foregroundColor(riskColor)
                        .cornerRadius(4)
                    
                    if !tool.parameters.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded && !tool.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(tool.parameters.keys.sorted()), id: \.self) { key in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(key):")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(VesperTheme.accentCyan)
                            Text(tool.parameters[key] ?? "")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(VesperTheme.primaryTextColor)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VesperTheme.terminalBackground)
                .cornerRadius(6)
            }
        }
        .padding(8)
        .background(VesperTheme.secondaryCardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
        )
    }
    
    private var riskColor: Color {
        switch tool.riskLevel {
        case .low: return VesperTheme.neonGreen
        case .medium: return VesperTheme.neonAmber
        case .high: return VesperTheme.neonRed
        case .blocked: return VesperTheme.cyberPurple
        }
    }
}

private struct PendingConfirmationCard: View {
    let toolCall: ToolCall
    @State private var agent = VesperAgent.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(VesperTheme.neonAmber)
                Text("Confirm Flipper Hardware Action")
                    .font(.headline)
                Spacer()
                Text(toolCall.riskLevel.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VesperTheme.neonAmber.opacity(0.2))
                    .foregroundColor(VesperTheme.neonAmber)
                    .cornerRadius(6)
            }
            
            Text("Action: **\(toolCall.action)**")
                .font(.subheadline)
            
            if !toolCall.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(toolCall.parameters.keys.sorted()), id: \.self) { key in
                        Text("• \(key): \(toolCall.parameters[key] ?? "")")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(VesperTheme.terminalBackground)
                .cornerRadius(6)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    Task { await agent.approvePendingAction() }
                }) {
                    Label("Execute Command", systemImage: "bolt.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(VesperTheme.accentCyan)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task { await agent.rejectPendingAction() }
                }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VesperTheme.neonAmber.opacity(0.8), lineWidth: 1.5)
        )
    }
}
