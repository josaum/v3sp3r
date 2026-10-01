import Foundation
import SwiftUI

@MainActor
@Observable
public final class SwarmAgentOrchestrator {
    public static let shared = SwarmAgentOrchestrator()
    
    public var swarmMessages: [ChatMessage] = []
    public var isMissionActive: Bool = false
    public var currentMission: String = ""
    public var missionStatusText: String = "Swarm Standby"
    
    private let swarmManager = FlipperSwarmManager.shared
    private let openRouter = OpenRouterService.shared
    private let settings = AppSettings.shared
    
    public init() {
        let briefing = ChatMessage(
            role: .assistant,
            agentRole: .commander,
            content: "COMMANDER ONLINE. Swarm network synchronized. Fleet nodes available: \(swarmManager.nodes.count). Ready to coordinate multi-agent tactical operations."
        )
        swarmMessages.append(briefing)
    }
    
    public func launchMission(objective: String) async {
        guard !objective.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isMissionActive = true
        currentMission = objective
        missionStatusText = "Commander organizing swarm..."
        
        // Add user objective
        let userMsg = ChatMessage(role: .user, content: objective)
        swarmMessages.append(userMsg)
        
        // 1. Commander Briefing
        await runAgentStep(
            role: .commander,
            instruction: "User Mission Objective: \(objective)\nAvailable Fleet Nodes: \(swarmManager.nodes.map { "\($0.customName) (\($0.transportType.rawValue))" }.joined(separator: ", "))\n\nOutline the multi-agent plan and delegate tasks to SPECTRE, VULCAN, or CIPHER."
        )
        
        // 2. Determine and trigger specialized agents based on objective keywords
        let lower = objective.lowercased()
        
        // Parallel agent execution using async let or TaskGroup
        missionStatusText = "Swarm agents executing in parallel..."
        
        let shouldRunRecon = lower.contains("sub") || lower.contains("rf") || lower.contains("signal") || lower.contains("spectrum") || lower.contains("scan") || lower.contains("all")
        let shouldRunForge = lower.contains("badusb") || lower.contains("payload") || lower.contains("script") || lower.contains("portal") || lower.contains("ducky") || lower.contains("all")
        let shouldRunCipher = lower.contains("nfc") || lower.contains("rfid") || lower.contains("card") || lower.contains("key") || lower.contains("ibutton") || lower.contains("all")
        
        if shouldRunRecon {
            await runAgentStep(
                role: .recon,
                instruction: "Perform RF spectrum analysis or Sub-GHz reconnaissance for: '\(objective)'. Coordinate with hardware nodes."
            )
        }
        
        if shouldRunForge {
            await runAgentStep(
                role: .forge,
                instruction: "Synthesize necessary payload (BadUSB / DuckyScript / IR) for: '\(objective)'. Validate syntax and prepare deployment."
            )
        }
        
        if shouldRunCipher {
            await runAgentStep(
                role: .cipher,
                instruction: "Analyze protocol framing, RFID tag formats, or cryptographic credentials relevant to: '\(objective)'."
            )
        }
        
        // 3. Commander Final Synthesis
        missionStatusText = "Commander synthesizing mission outcome..."
        await runAgentStep(
            role: .commander,
            instruction: "All specialized agents have reported. Provide a concise tactical summary of the mission status, executed hardware actions, and ready deliverables."
        )
        
        isMissionActive = false
        missionStatusText = "Mission Complete"
    }
    
    private func runAgentStep(role: AgentRole, instruction: String) async {
        let msgIndex = swarmMessages.count
        var agentMsg = ChatMessage(role: .assistant, agentRole: role, content: "", isStreaming: true)
        swarmMessages.append(agentMsg)
        
        let systemPrompt = SwarmPrompts.promptFor(role: role)
        let messagesPayload: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": instruction]
        ]
        
        do {
            try await openRouter.streamChat(
                messages: messagesPayload,
                apiKey: settings.openRouterApiKey,
                model: settings.selectedModel
            ) { [weak self] chunk in
                guard let self = self else { return }
                if let text = chunk.textDelta {
                    agentMsg.content += text
                    self.swarmMessages[msgIndex] = agentMsg
                }
            }
            agentMsg.isStreaming = false
            self.swarmMessages[msgIndex] = agentMsg
        } catch {
            agentMsg.isStreaming = false
            agentMsg.content += "\n⚠️ Agent error: \(error.localizedDescription)"
            self.swarmMessages[msgIndex] = agentMsg
        }
    }
}
