import Foundation
import SwiftUI

@MainActor
@Observable
public final class VesperAgent {
    public static let shared = VesperAgent()
    
    public var messages: [ChatMessage] = []
    public var isThinking: Bool = false
    public var pendingConfirmation: ToolCall?
    public var statusText: String = "Ready"
    public var currentAutonomousIteration: Int = 0
    public var isAutonomousPaused: Bool = false
    public var activeGoal: String? = nil
    
    private let openRouter = OpenRouterService.shared
    private let toolExecutor = FlipperToolExecutor.shared
    private let settings = AppSettings.shared
    
    public init() {
        let welcome = ChatMessage(
            role: .assistant,
            content: "ferriteSuite online. Connected to macOS desktop workstation. Ready to operate your Flipper Zero over USB or BLE. Type a command, ask a hardware question, or tap a proactive action card below.",
            suggestedActions: [
                ProactiveAction(title: "Hardware Health Self-Test", promptOrCommand: "Run Flipper Diagnostic Health Self-Test", icon: "cross.case.fill", category: "Workflow"),
                ProactiveAction(title: "Sub-GHz Spectrum Recon", promptOrCommand: "Run Sub-GHz Spectrum Recon Workflow", icon: "waveform.path.ecg", category: "Workflow"),
                ProactiveAction(title: "FerriteOS Intent Engine", promptOrCommand: "Ask FerriteOS to interpret 'audit subghz band'", icon: "atom", category: "FerriteOS"),
                ProactiveAction(title: "Audit Access Badges", promptOrCommand: "Run Access Control & Badge Audit", icon: "lock.shield.fill", category: "Workflow")
            ]
        )
        messages.append(welcome)
    }
    
    public func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("/goal ") {
            let goalText = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            await runAutonomousGoal(goalText)
            return
        }
        
        currentAutonomousIteration = 0
        isAutonomousPaused = false
        activeGoal = nil
        
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        
        isThinking = true
        if settings.aiEngine == .piHarness && PiHarnessService.shared.isAvailable {
            let modelName = settings.piHarnessModel.isEmpty ? (PiHarnessService.shared.hostConfig?.defaultModel ?? "kimi-k3") : settings.piHarnessModel
            statusText = "Pi Harness (\(modelName)): Reasoning..."
        } else {
            statusText = settings.autopilotMode == .autonomous ? "Autopilot active: Reasoning..." : "Consulting AI model..."
        }
        
        await runAgentLoop()
    }
    
    public func runAutonomousGoal(_ goal: String) async {
        guard !goal.isEmpty else { return }
        activeGoal = goal
        currentAutonomousIteration = 0
        isAutonomousPaused = false
        
        let userMsg = ChatMessage(role: .user, content: "🎯 Autonomous Goal: \(goal)")
        messages.append(userMsg)
        
        isThinking = true
        statusText = "Autopilot: Deconstructing goal into autonomous execution plan..."
        
        await runAgentLoop()
    }
    
    public func pauseAutopilot() {
        isAutonomousPaused = true
        statusText = "Autopilot Paused by Operator"
    }
    
    public func resumeAutopilot() async {
        isAutonomousPaused = false
        isThinking = true
        statusText = "Autopilot Resumed: Continuing..."
        await runAgentLoop()
    }
    
    private func runAgentLoop() async {
        let assistantIndex = messages.count
        var assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMsg)
        
        var toolCallId = ""
        var toolName = ""
        var toolArgsBuffer = ""
        
        do {
            let fullSystemPrompt = buildSystemPrompt()
            
            if settings.aiEngine == .piHarness && PiHarnessService.shared.isAvailable {
                let prompt = buildPromptForPiHarness()
                try await PiHarnessService.shared.streamPrompt(
                    prompt: prompt,
                    systemPrompt: fullSystemPrompt
                ) { [weak self] chunk in
                    guard let self = self else { return }
                    
                    if let text = chunk.textDelta {
                        assistantMsg.content += text
                        self.messages[assistantIndex] = assistantMsg
                    }
                    
                    if let tool = chunk.toolCallDelta {
                        if let id = tool.id { toolCallId = id }
                        if let name = tool.name { toolName = name }
                        if let args = tool.args { toolArgsBuffer += args }
                    }
                }
            } else {
                let apiMessages = buildApiPayload(systemPrompt: fullSystemPrompt)
                
                try await openRouter.streamChat(
                    messages: apiMessages,
                    apiKey: settings.openRouterApiKey,
                    model: settings.selectedModel
                ) { [weak self] chunk in
                    guard let self = self else { return }
                    
                    if let text = chunk.textDelta {
                        assistantMsg.content += text
                        self.messages[assistantIndex] = assistantMsg
                    }
                    
                    if let tool = chunk.toolCallDelta {
                        if let id = tool.id { toolCallId = id }
                        if let name = tool.name { toolName = name }
                        if let args = tool.args { toolArgsBuffer += args }
                    }
                }
            }
            
            assistantMsg.isStreaming = false
            self.messages[assistantIndex] = assistantMsg
            
            if !toolName.isEmpty {
                // Parse arguments
                var params: [String: String] = [:]
                if let data = toolArgsBuffer.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    let action = json["action"] as? String ?? toolName
                    if let rawParams = json["parameters"] as? [String: Any] {
                        for (k, v) in rawParams {
                            params[k] = "\(v)"
                        }
                    }
                    
                    let risk = classifyRisk(action: action, params: params)
                    let toolCall = ToolCall(
                        id: toolCallId.isEmpty ? UUID().uuidString : toolCallId,
                        action: action,
                        parameters: params,
                        riskLevel: risk,
                        requiresConfirmation: requiresApproval(risk: risk)
                    )
                    
                    assistantMsg.toolCalls.append(toolCall)
                    self.messages[assistantIndex] = assistantMsg
                    
                    if toolCall.requiresConfirmation {
                        self.pendingConfirmation = toolCall
                        self.statusText = "Action requires confirmation (\(risk.rawValue))"
                        self.isThinking = false
                        return
                    } else {
                        await executeToolCall(toolCall)
                    }
                }
            } else {
                self.attachProactiveSuggestions(to: &self.messages[assistantIndex])
                isThinking = false
                statusText = "Ready"
            }
        } catch {
            assistantMsg.isStreaming = false
            assistantMsg.content += "\n\n⚠️ Error: \(error.localizedDescription)"
            self.messages[assistantIndex] = assistantMsg
            self.attachProactiveSuggestions(to: &self.messages[assistantIndex])
            isThinking = false
            statusText = "Error encountered"
        }
    }
    
    public func approvePendingAction() async {
        guard let tool = pendingConfirmation else { return }
        pendingConfirmation = nil
        isThinking = true
        statusText = "Executing approved action..."
        await executeToolCall(tool)
    }
    
    public func rejectPendingAction() async {
        guard let tool = pendingConfirmation else { return }
        pendingConfirmation = nil
        
        let cancelResult = ToolResult(toolCallId: tool.id, output: "User canceled action.", isError: true)
        if var last = messages.last, last.role == .assistant {
            last.toolResults.append(cancelResult)
            messages[messages.count - 1] = last
        }
        
        isThinking = false
        statusText = "Action canceled"
    }
    
    private func executeToolCall(_ tool: ToolCall) async {
        currentAutonomousIteration += 1
        let maxIter = settings.maxAutonomousIterations
        
        statusText = settings.autopilotMode == .autonomous 
            ? "Autopilot [\(currentAutonomousIteration)/\(maxIter)]: \(tool.action)..."
            : "Operating Flipper: \(tool.action)..."
            
        let result = await toolExecutor.execute(action: tool.action, params: tool.parameters)
        let toolResult = ToolResult(toolCallId: tool.id, output: result.output, isError: result.isError)
        
        if var last = messages.last, last.role == .assistant {
            last.toolResults.append(toolResult)
            messages[messages.count - 1] = last
        }
        
        // Auto-record discoveries to Memory Vault
        autoRecordDiscoveries(tool: tool, result: result.output)
        
        if isAutonomousPaused {
            statusText = "Autopilot Paused by Operator"
            isThinking = false
            return
        }
        
        if currentAutonomousIteration >= maxIter {
            statusText = "Autopilot reached iteration limit (\(maxIter))"
            isThinking = false
            if var last = messages.last, last.role == .assistant {
                last.content += "\n\n🏁 *Autonomous execution limit reached (\(maxIter) steps).* Type `/goal <prompt>` to extend or define a new goal."
                messages[messages.count - 1] = last
            }
            return
        }
        
        statusText = settings.autopilotMode == .autonomous 
            ? "Autopilot [\(currentAutonomousIteration)/\(maxIter)]: Reasoning next action..."
            : "Analyzing execution result..."
            
        await runAgentLoop()
    }
    
    private func autoRecordDiscoveries(tool: ToolCall, result: String) {
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("Error") else { return }
        
        if tool.action == "execute_cli" && (trimmed.contains("Frequency:") || trimmed.contains("Protocol:") || trimmed.contains("Key:")) {
            VesperMemoryStore.shared.addMemory(
                category: .signal,
                title: "Observed RF Signal via CLI",
                content: String(trimmed.prefix(350))
            )
        } else if tool.action == "get_device_info" && (trimmed.contains("firmware") || trimmed.contains("battery")) {
            VesperMemoryStore.shared.addMemory(
                category: .hardware,
                title: "Flipper Hardware Snapshot",
                content: String(trimmed.prefix(350))
            )
        } else if tool.action == "ferrite_decode" {
            VesperMemoryStore.shared.addMemory(
                category: .ferritePlan,
                title: "FerriteOS Decoded Signal",
                content: String(trimmed.prefix(350))
            )
        } else if (tool.action == "flash_flipper_firmware" || tool.action == "flash_gpio_board") && !trimmed.contains("Error") {
            VesperMemoryStore.shared.addMemory(
                category: .hardware,
                title: "Firmware Flashed (\(tool.parameters["distro"] ?? tool.parameters["firmware"] ?? "unknown"))",
                content: String(trimmed.prefix(350))
            )
        }
    }
    
    private func attachProactiveSuggestions(to message: inout ChatMessage) {
        var actions: [ProactiveAction] = []
        let lower = message.content.lowercased()
        let toolActions = message.toolCalls.map { $0.action }
        
        if lower.contains("flash") || lower.contains("firmware") || lower.contains("update") || lower.contains("marauder") || lower.contains("devboard") || lower.contains("esp32") || toolActions.contains("flash_flipper_firmware") || toolActions.contains("flash_gpio_board") || toolActions.contains("diagnose_gpio_devboard") || toolActions.contains("check_firmware_updates") {
            actions.append(ProactiveAction(title: "Flash Firmware DAG", promptOrCommand: "Run Firmware Diagnostic & Flash Workflow", icon: "sparkles", category: "Workflow"))
            actions.append(ProactiveAction(title: "Diagnose WiFi Board", promptOrCommand: "Diagnose connected ESP32 WiFi Devboard and report status", icon: "bolt.horizontal.circle.fill", category: "Hardware"))
            actions.append(ProactiveAction(title: "Check Unleashed Updates", promptOrCommand: "Check latest Unleashed firmware releases on GitHub", icon: "arrow.triangle.2.circlepath", category: "Firmware"))
            actions.append(ProactiveAction(title: "Flash 802.11 Diagnostic Suite", promptOrCommand: "Flash latest 802.11 Diagnostic Firmware to the connected WiFi Devboard", icon: "antenna.radiowaves.left.and.right", category: "Hardware"))
        } else if lower.contains("sub-ghz") || lower.contains("subghz") || lower.contains("433") || lower.contains("315") || toolActions.contains("subghz_transmit") {
            actions.append(ProactiveAction(title: "Launch Spectrum Recon DAG", promptOrCommand: "Run Sub-GHz Spectrum Recon Workflow", icon: "point.3.connected.trianglepath.dotted", category: "Workflow"))
            actions.append(ProactiveAction(title: "FerriteOS Intent Analysis", promptOrCommand: "Ask FerriteOS to interpret 'audit subghz band'", icon: "atom", category: "FerriteOS"))
            actions.append(ProactiveAction(title: "Save Capture to Vault", promptOrCommand: "Store this Sub-GHz signal observation in the Memory Vault", icon: "brain", category: "Memory"))
        } else if lower.contains("nfc") || lower.contains("rfid") || lower.contains("badge") || lower.contains("fob") {
            actions.append(ProactiveAction(title: "Run Badge Audit DAG", promptOrCommand: "Run Access Control & Badge Audit", icon: "lock.shield.fill", category: "Workflow"))
            actions.append(ProactiveAction(title: "Scan Low-Frequency RFID", promptOrCommand: "Execute RFID 125kHz read on Flipper", icon: "wave.3.forward", category: "Hardware"))
            actions.append(ProactiveAction(title: "Audit Storage Keys", promptOrCommand: "List RFID files in /ext/lfrfid and /ext/nfc", icon: "folder.fill", category: "Storage"))
        } else if lower.contains("badusb") || lower.contains("keyboard") || lower.contains("payload") {
            actions.append(ProactiveAction(title: "Show Payload Lab", promptOrCommand: "List BadUSB scripts in /ext/badusb", icon: "keyboard.fill", category: "Payload"))
            actions.append(ProactiveAction(title: "Hardware Diagnostic", promptOrCommand: "Run Flipper Diagnostic Health Self-Test", icon: "cross.case.fill", category: "Workflow"))
        } else if lower.contains("battery") || lower.contains("health") || toolActions.contains("get_device_info") {
            actions.append(ProactiveAction(title: "Full Diagnostic DAG", promptOrCommand: "Run Flipper Diagnostic Health Self-Test", icon: "cross.case.fill", category: "Workflow"))
            actions.append(ProactiveAction(title: "Check SD Storage", promptOrCommand: "What is my SD card storage info?", icon: "externaldrive.fill", category: "Hardware"))
            actions.append(ProactiveAction(title: "Save System Profile", promptOrCommand: "Save current firmware and battery status to Memory Vault", icon: "brain", category: "Memory"))
        } else if lower.contains("file") || lower.contains("directory") || toolActions.contains("list_directory") {
            actions.append(ProactiveAction(title: "Inspect /ext/subghz", promptOrCommand: "List all Sub-GHz files in /ext/subghz", icon: "waveform.path.ecg", category: "Storage"))
            actions.append(ProactiveAction(title: "Inspect BadUSB Scripts", promptOrCommand: "List all scripts in /ext/badusb", icon: "keyboard.fill", category: "Storage"))
            actions.append(ProactiveAction(title: "Memory Vault Search", promptOrCommand: "Search memory vault for saved keys", icon: "brain", category: "Memory"))
        } else {
            actions.append(ProactiveAction(title: "Run Spectrum Recon", promptOrCommand: "Run Sub-GHz Spectrum Recon Workflow", icon: "waveform.path.ecg", category: "Workflow"))
            actions.append(ProactiveAction(title: "Device Self-Test", promptOrCommand: "Run Flipper Diagnostic Health Self-Test", icon: "cross.case.fill", category: "Workflow"))
            actions.append(ProactiveAction(title: "FerriteOS Intent Engine", promptOrCommand: "Ask FerriteOS to interpret 'audit subghz band'", icon: "atom", category: "FerriteOS"))
        }
        
        message.suggestedActions = actions
    }
    
    private func classifyRisk(action: String, params: [String: String]) -> RiskLevel {
        switch action {
        case "list_directory", "read_file", "get_device_info", "get_storage_info", "led_control", "vibro_control", "ferrite_understand", "ferrite_decode", "record_memory", "trigger_workflow", "check_firmware_updates", "diagnose_gpio_devboard":
            return .low
        case "write_file", "create_directory", "launch_app", "subghz_transmit", "ir_transmit", "flash_gpio_board":
            return .medium
        case "badusb_execute", "delete", "flash_flipper_firmware":
            return .high
        case "execute_cli":
            let cmd = (params["command"] ?? "").lowercased()
            if cmd.contains("remove") || cmd.contains("format") || cmd.contains("factory") {
                return .high
            }
            return .medium
        default:
            return .medium
        }
    }
    
    private func requiresApproval(risk: RiskLevel) -> Bool {
        if settings.autopilotMode == .autonomous {
            switch risk {
            case .low, .medium: return false
            case .high: return false // In autonomous mode, auto-execute high risk unless strictly blocked
            case .blocked: return true
            }
        } else {
            switch risk {
            case .low: return !settings.autoApproveLow
            case .medium: return !settings.autoApproveMedium
            case .high, .blocked: return true
            }
        }
    }
    
    private func buildSystemPrompt() -> String {
        var systemContent = VesperPrompts.systemPrompt
        
        // Inject Autopilot Status
        systemContent += "\n\n### AUTOPILOT MODE: \(settings.autopilotMode.rawValue.uppercased())\n"
        systemContent += "- Iteration: \(currentAutonomousIteration) of \(settings.maxAutonomousIterations) max autonomous steps.\n"
        systemContent += "- You have full authority to execute chains of commands without pausing for user confirmation.\n"
        
        if let goal = activeGoal {
            systemContent += "\n### ACTIVE AUTONOMOUS MISSION:\n\(goal)\n"
            systemContent += "- Execute all required hardware operations to completion, inspect responses, decode signals, and summarize the tactical findings.\n"
        }
        
        // Inject FerriteOS status
        let ferrite = FerriteOSService.shared
        if ferrite.isAvailable {
            systemContent += "\n### FERRITEOS DETERMINISTIC INTENT ENGINE (LOCAL & ACTIVE)\n"
            systemContent += "- FerriteOS Binary: Available at \(ferrite.binaryPath)\n"
            systemContent += "- Capabilities: Native Rust intent classification, zero-shot token parser, and local RF capture decoding (.sub, .nfc, .rfid, .ibtn).\n"
            systemContent += "- You can use 'ferrite_understand' to understand complex intent, or 'ferrite_decode' to decode raw radio signal files.\n"
        }
        
        // Inject live hardware status
        let conn = FlipperConnectionManager.shared
        systemContent += "\n### LIVE FLIPPER TELEMETRY & HARDWARE STATUS\n"
        systemContent += "- Connection State: \(conn.status.description)\n"
        if conn.status.isConnected {
            systemContent += "- Model: \(conn.deviceInfo.hardwareModel)\n"
            systemContent += "- Firmware: \(conn.deviceInfo.firmwareVersion) (\(conn.deviceInfo.firmwareBranch)) Commit: \(conn.deviceInfo.firmwareCommit)\n"
            systemContent += "- Battery: \(conn.deviceInfo.batteryLevel)% (Charging: \(conn.deviceInfo.isCharging))\n"
            systemContent += "- Current Activity: \(conn.currentActivity)\n"
            systemContent += "- Radio Mode: \(conn.deviceInfo.radioMode)\n"
        }
        
        // Inject persistent memory vault
        systemContent += VesperMemoryStore.shared.generateMemoryContextPrompt()
        return systemContent
    }
    
    private func buildPromptForPiHarness() -> String {
        let slice = messages.suffix(12)
        var context = ""
        for msg in slice {
            guard !msg.content.isEmpty || !msg.toolResults.isEmpty else { continue }
            let roleLabel = msg.role == .user ? "OPERATOR" : "VESPER"
            if !msg.content.isEmpty {
                context += "\(roleLabel): \(msg.content)\n"
            }
            if !msg.toolResults.isEmpty {
                let results = msg.toolResults.map { "  - Tool Result: \($0.output)" }.joined(separator: "\n")
                context += "HARDWARE EXECUTION RESULTS:\n\(results)\n"
            }
        }
        
        if let lastUser = messages.last(where: { $0.role == .user }) {
            return """
Conversation Context:
\(context)

Operator Instruction:
\(lastUser.content)
"""
        } else {
            return context.isEmpty ? "Check Flipper hardware state and report status." : context
        }
    }
    
    private func buildApiPayload(systemPrompt: String) -> [[String: Any]] {
        var apiMsgs: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        let slice = messages.suffix(15)
        for msg in slice {
            var m: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
            if !msg.toolResults.isEmpty {
                let resSummary = msg.toolResults.map { "Result: \($0.output)" }.joined(separator: "\n")
                m["content"] = (msg.content.isEmpty ? "" : msg.content + "\n") + resSummary
            }
            apiMsgs.append(m)
        }
        
        return apiMsgs
    }
}
