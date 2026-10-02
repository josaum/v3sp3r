import SwiftUI

public struct SwarmMissionView: View {
    @State private var orchestrator = SwarmAgentOrchestrator.shared
    @State private var missionInput: String = ""
    @State private var swarmManager = FlipperSwarmManager.shared
    
    private let presetMissions = [
        "Distributed 315MHz & 433MHz Sub-GHz RF spectrum sweep across available fleet nodes",
        "Forge cross-platform BadUSB payload for macOS & Windows with terminal banner",
        "Perform complete hardware fleet audit, battery health check, and SD inventory",
        "Analyze high-frequency 13.56MHz NFC and 125kHz RFID access control cards"
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(orchestrator.isMissionActive ? FerriteSuiteTheme.neonAmber : FerriteSuiteTheme.neonGreen)
                        .frame(width: 8, height: 8)
                    Text(orchestrator.missionStatusText)
                        .font(.caption.monospaced().bold())
                        .foregroundColor(FerriteSuiteTheme.accentCyan)
                }
                
                Spacer()
                
                Text("\(swarmManager.nodes.count) Fleet Nodes Online")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(FerriteSuiteTheme.secondaryCardBackground)
                    .cornerRadius(6)
                
                Button(action: {
                    orchestrator.swarmMessages = [
                        ChatMessage(
                            role: .assistant,
                            agentRole: .commander,
                            content: "COMMANDER ONLINE. Standing by for next mission directives."
                        )
                    ]
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(FerriteSuiteTheme.cardBackground)
            
            Divider().background(FerriteSuiteTheme.subtleBorder)
            
            // Mission Messages Stream
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(orchestrator.swarmMessages) { msg in
                            SwarmMessageRow(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: orchestrator.swarmMessages.count) {
                    if let last = orchestrator.swarmMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider().background(FerriteSuiteTheme.subtleBorder)
            
            // Preset Missions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetMissions, id: \.self) { preset in
                        Button(action: {
                            missionInput = preset
                            submitMission()
                        }) {
                            Text(preset)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(FerriteSuiteTheme.cardBackground.opacity(0.5))
            
            // Input Bar
            HStack(spacing: 12) {
                TextField("Define tactical mission for the AI Swarm...", text: $missionInput)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        submitMission()
                    }
                    .padding(10)
                    .background(FerriteSuiteTheme.secondaryCardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                    )
                
                Button(action: submitMission) {
                    if orchestrator.isMissionActive {
                        ProgressView().scaleEffect(0.7)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.title2)
                            .foregroundColor(missionInput.isEmpty ? .secondary : FerriteSuiteTheme.accentCyan)
                    }
                }
                .buttonStyle(.plain)
                .disabled(missionInput.isEmpty || orchestrator.isMissionActive)
            }
            .padding(16)
            .background(FerriteSuiteTheme.cardBackground)
        }
        .background(FerriteSuiteTheme.darkBackground)
    }
    
    private func submitMission() {
        let task = missionInput
        missionInput = ""
        Task {
            await orchestrator.launchMission(objective: task)
        }
    }
}

private struct SwarmMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 40)
            } else {
                AgentAvatar(role: message.agentRole ?? .commander)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if let role = message.agentRole, message.role == .assistant {
                    HStack(spacing: 6) {
                        Text(role.codename)
                            .font(.system(size: 10, weight: .black).monospaced())
                            .foregroundColor(roleColor(role))
                        Text("• \(role.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(message.role == .user ? FerriteSuiteTheme.cyberPurple.opacity(0.25) : FerriteSuiteTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardBorderColor, lineWidth: 1)
                    )
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            } else {
                Circle()
                    .fill(FerriteSuiteTheme.accentCyan.gradient)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                    )
            }
        }
    }
    
    private var cardBorderColor: Color {
        if message.role == .user {
            return FerriteSuiteTheme.cyberPurple.opacity(0.5)
        }
        if let role = message.agentRole {
            return roleColor(role).opacity(0.5)
        }
        return FerriteSuiteTheme.subtleBorder
    }
    
    private func roleColor(_ role: AgentRole) -> Color {
        switch role {
        case .commander: return FerriteSuiteTheme.accentCyan
        case .recon: return FerriteSuiteTheme.neonGreen
        case .forge: return FerriteSuiteTheme.neonAmber
        case .cipher: return FerriteSuiteTheme.cyberPurple
        case .sentry: return Color.blue
        }
    }
}

private struct AgentAvatar: View {
    let role: AgentRole
    
    var body: some View {
        Circle()
            .fill(avatarColor.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: role.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(avatarColor)
            )
            .overlay(
                Circle()
                    .stroke(avatarColor.opacity(0.8), lineWidth: 1)
            )
    }
    
    private var avatarColor: Color {
        switch role {
        case .commander: return FerriteSuiteTheme.accentCyan
        case .recon: return FerriteSuiteTheme.neonGreen
        case .forge: return FerriteSuiteTheme.neonAmber
        case .cipher: return FerriteSuiteTheme.cyberPurple
        case .sentry: return Color.blue
        }
    }
}
