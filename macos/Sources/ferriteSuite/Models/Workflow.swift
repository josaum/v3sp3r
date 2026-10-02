import Foundation
import SwiftUI

public struct WorkflowWebInsight: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var url: String
    public var snippet: String
    public var tags: [String]
    
    public init(id: String = UUID().uuidString, title: String, url: String, snippet: String, tags: [String] = []) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.tags = tags
    }
}

public enum WorkflowTaskType: String, Codable, CaseIterable {
    case serialCommand = "Serial CLI"
    case flipperTool = "Flipper Tool"
    case subGhzScan = "Sub-GHz Scan"
    case subGhzTx = "Sub-GHz Transmit"
    case subGhzAutoTune = "Sub-GHz Auto-Tuning"
    case doorbellAudit = "Doorbell & Remote Audit"
    case wifiSurvey = "802.11 Wi-Fi Survey"
    case signalDisambiguation = "Action Gate & Disambiguation"
    case webIntelligence = "Web & Protocol Intelligence"
    case delay = "Delay / Timer"
    case aiAnalysis = "AI Analysis (Grok 4.7)"
    case ledSignal = "LED Indicator"
    case vibroPulse = "Vibration Alert"
    case healthCheck = "Diagnostic Health"
    
    public var iconName: String {
        switch self {
        case .serialCommand: return "terminal.fill"
        case .flipperTool: return "wrench.and.screwdriver.fill"
        case .subGhzScan: return "antenna.radiowaves.left.and.right"
        case .subGhzTx: return "wave.3.forward"
        case .subGhzAutoTune: return "dial.low.fill"
        case .doorbellAudit: return "bell.badge.fill"
        case .wifiSurvey: return "wifi.badge.plus"
        case .signalDisambiguation: return "questionmark.bubble.fill"
        case .webIntelligence: return "globe.badge.chevron.backward"
        case .delay: return "timer"
        case .aiAnalysis: return "brain.head.profile"
        case .ledSignal: return "lightbulb.fill"
        case .vibroPulse: return "waveform"
        case .healthCheck: return "heart.text.square.fill"
        }
    }
}

public enum WorkflowTaskStatus: Equatable, Codable {
    case pending
    case running
    case completed(output: String)
    case failed(error: String)
    case paused
    case skipped
    case waitingForInput(prompt: String)
    
    public var iconName: String {
        switch self {
        case .pending: return "circle.dashed"
        case .running: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .skipped: return "forward.circle.fill"
        case .waitingForInput: return "hand.raised.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return FerriteSuiteTheme.accentCyan
        case .completed: return FerriteSuiteTheme.neonGreen
        case .failed: return FerriteSuiteTheme.neonRed
        case .paused: return FerriteSuiteTheme.neonAmber
        case .skipped: return .secondary.opacity(0.6)
        case .waitingForInput: return FerriteSuiteTheme.neonAmber
        }
    }
    
    public var label: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Executing..."
        case .completed: return "Completed"
        case .failed(let err): return "Failed: \(err)"
        case .paused: return "Paused"
        case .skipped: return "Skipped"
        case .waitingForInput(let prompt): return "Operator Decision Required: \(prompt)"
        }
    }
}

public struct WorkflowTask: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var type: WorkflowTaskType
    public var command: String
    public var delaySeconds: Double
    public var status: WorkflowTaskStatus
    public var output: String
    public var executionTimeMs: Int
    
    // Interactive & Actionable extensions
    public var interactivePrompt: String?
    public var options: [String]
    public var selectedOption: String?
    public var telemetryBadges: [String: String]
    public var webInsights: [WorkflowWebInsight]
    public var isWaitingForUser: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        type: WorkflowTaskType,
        command: String = "",
        delaySeconds: Double = 0.0,
        status: WorkflowTaskStatus = .pending,
        output: String = "",
        executionTimeMs: Int = 0,
        interactivePrompt: String? = nil,
        options: [String] = [],
        selectedOption: String? = nil,
        telemetryBadges: [String: String] = [:],
        webInsights: [WorkflowWebInsight] = [],
        isWaitingForUser: Bool = false
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.command = command
        self.delaySeconds = delaySeconds
        self.status = status
        self.output = output
        self.executionTimeMs = executionTimeMs
        self.interactivePrompt = interactivePrompt
        self.options = options
        self.selectedOption = selectedOption
        self.telemetryBadges = telemetryBadges
        self.webInsights = webInsights
        self.isWaitingForUser = isWaitingForUser
    }
}

public struct WorkflowSubgraph: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var tasks: [WorkflowTask]
    public var isCollapsed: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String = "",
        tasks: [WorkflowTask] = [],
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.tasks = tasks
        self.isCollapsed = isCollapsed
    }
    
    public var isCompleted: Bool {
        !tasks.isEmpty && tasks.allSatisfy { task in
            if case .completed = task.status { return true }
            if case .skipped = task.status { return true }
            return false
        }
    }
    
    public var isRunning: Bool {
        tasks.contains { $0.status == .running }
    }
    
    public var isPaused: Bool {
        tasks.contains { $0.status == .paused }
    }
}

public enum WorkflowExecutionState: String, Codable {
    case idle = "IDLE"
    case running = "RUNNING"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case stopped = "STOPPED"
    case failed = "FAILED"
    
    public var color: Color {
        switch self {
        case .idle: return .secondary
        case .running: return FerriteSuiteTheme.accentCyan
        case .paused: return FerriteSuiteTheme.neonAmber
        case .completed: return FerriteSuiteTheme.neonGreen
        case .stopped: return .secondary
        case .failed: return FerriteSuiteTheme.neonRed
        }
    }
}

public struct Workflow: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var description: String
    public var subgraphs: [WorkflowSubgraph]
    public var executionState: WorkflowExecutionState
    public var currentSubgraphIndex: Int
    public var currentTaskIndex: Int
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        subgraphs: [WorkflowSubgraph] = [],
        executionState: WorkflowExecutionState = .idle,
        currentSubgraphIndex: Int = 0,
        currentTaskIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.subgraphs = subgraphs
        self.executionState = executionState
        self.currentSubgraphIndex = currentSubgraphIndex
        self.currentTaskIndex = currentTaskIndex
    }
    
    public var totalTasksCount: Int {
        subgraphs.reduce(0) { $0 + $1.tasks.count }
    }
    
    public var completedTasksCount: Int {
        subgraphs.reduce(0) { count, sg in
            count + sg.tasks.filter {
                if case .completed = $0.status { return true }
                if case .skipped = $0.status { return true }
                return false
            }.count
        }
    }
    
    public var progressFraction: Double {
        guard totalTasksCount > 0 else { return 0 }
        return Double(completedTasksCount) / Double(totalTasksCount)
    }
}
