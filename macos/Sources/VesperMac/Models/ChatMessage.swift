import Foundation

public enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

public enum RiskLevel: String, Codable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case blocked = "BLOCKED"
    
    public var badgeColor: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        case .blocked: return "purple"
        }
    }
}

public struct ToolCall: Identifiable, Codable, Equatable {
    public let id: String
    public let action: String
    public let parameters: [String: String]
    public var riskLevel: RiskLevel
    public var isApproved: Bool
    public var requiresConfirmation: Bool
    
    public init(
        id: String = UUID().uuidString,
        action: String,
        parameters: [String: String] = [:],
        riskLevel: RiskLevel = .low,
        isApproved: Bool = false,
        requiresConfirmation: Bool = false
    ) {
        self.id = id
        self.action = action
        self.parameters = parameters
        self.riskLevel = riskLevel
        self.isApproved = isApproved
        self.requiresConfirmation = requiresConfirmation
    }
}

public struct ToolResult: Identifiable, Codable, Equatable {
    public var id: String { toolCallId }
    public let toolCallId: String
    public let output: String
    public let isError: Bool
    
    public init(toolCallId: String, output: String, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.output = output
        self.isError = isError
    }
}

public struct ProactiveAction: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let promptOrCommand: String
    public let icon: String
    public let category: String
    
    public init(id: String = UUID().uuidString, title: String, promptOrCommand: String, icon: String = "bolt.fill", category: String = "Action") {
        self.id = id
        self.title = title
        self.promptOrCommand = promptOrCommand
        self.icon = icon
        self.category = category
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable {
    public let id: String
    public let role: MessageRole
    public var agentRole: AgentRole?
    public var content: String
    public var toolCalls: [ToolCall]
    public var toolResults: [ToolResult]
    public var suggestedActions: [ProactiveAction]
    public let timestamp: Date
    public var isStreaming: Bool
    
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        agentRole: AgentRole? = nil,
        content: String,
        toolCalls: [ToolCall] = [],
        toolResults: [ToolResult] = [],
        suggestedActions: [ProactiveAction] = [],
        timestamp: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.agentRole = agentRole
        self.content = content
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.suggestedActions = suggestedActions
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}
