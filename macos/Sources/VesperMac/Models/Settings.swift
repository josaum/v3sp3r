import Foundation
import SwiftUI

public enum AutopilotMode: String, Codable, CaseIterable {
    case supervised = "Supervised"
    case autonomous = "Full Autonomous"
    
    public var iconName: String {
        switch self {
        case .supervised: return "shield.lefthalf.filled"
        case .autonomous: return "bolt.shield.fill"
        }
    }
}

public enum AppThemeMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

public enum AiEngineType: String, Codable, CaseIterable {
    case piHarness = "Embedded Pi Harness"
    case openRouter = "OpenRouter Direct API"
    
    public var iconName: String {
        switch self {
        case .piHarness: return "cpu"
        case .openRouter: return "network"
        }
    }
}

@MainActor
@Observable
public final class AppSettings {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    public var aiEngine: AiEngineType {
        didSet { defaults.set(aiEngine.rawValue, forKey: "aiEngine") }
    }
    
    public var customPiBinaryPath: String {
        didSet {
            defaults.set(customPiBinaryPath, forKey: "customPiBinaryPath")
            PiHarnessService.shared.refreshStatus()
        }
    }
    
    public var piHarnessModel: String {
        didSet { defaults.set(piHarnessModel, forKey: "piHarnessModel") }
    }
    
    public var autopilotMode: AutopilotMode {
        didSet { defaults.set(autopilotMode.rawValue, forKey: "autopilotMode") }
    }
    
    public var maxAutonomousIterations: Int {
        didSet { defaults.set(maxAutonomousIterations, forKey: "maxAutonomousIterations") }
    }
    
    public var appTheme: AppThemeMode {
        didSet { defaults.set(appTheme.rawValue, forKey: "appTheme") }
    }
    
    public var openRouterApiKey: String {
        didSet { defaults.set(openRouterApiKey, forKey: "openRouterApiKey") }
    }
    
    public var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: "selectedModel") }
    }
    
    public var autoApproveLow: Bool {
        didSet { defaults.set(autoApproveLow, forKey: "autoApproveLow") }
    }
    
    public var autoApproveMedium: Bool {
        didSet { defaults.set(autoApproveMedium, forKey: "autoApproveMedium") }
    }
    
    public var preferredTransport: TransportType {
        didSet { defaults.set(preferredTransport.rawValue, forKey: "preferredTransport") }
    }
    
    public var ttsVoiceEnabled: Bool {
        didSet { defaults.set(ttsVoiceEnabled, forKey: "ttsVoiceEnabled") }
    }
    
    public var customBaudRate: Int {
        didSet { defaults.set(customBaudRate, forKey: "customBaudRate") }
    }
    
    public var reasoningEffort: String {
        didSet { defaults.set(reasoningEffort, forKey: "reasoningEffort") }
    }
    
    public var enableWebMcpServer: Bool {
        didSet {
            defaults.set(enableWebMcpServer, forKey: "enableWebMcpServer")
            if enableWebMcpServer {
                WebMcpServer.shared.start(port: webMcpPort)
            } else {
                WebMcpServer.shared.stop()
            }
        }
    }
    
    public var webMcpPort: Int {
        didSet {
            defaults.set(webMcpPort, forKey: "webMcpPort")
            if enableWebMcpServer {
                WebMcpServer.shared.restart(port: webMcpPort)
            }
        }
    }
    
    public init() {
        let savedAiEngine = defaults.string(forKey: "aiEngine") ?? AiEngineType.piHarness.rawValue
        self.aiEngine = AiEngineType(rawValue: savedAiEngine) ?? .piHarness
        self.customPiBinaryPath = defaults.string(forKey: "customPiBinaryPath") ?? ""
        self.piHarnessModel = defaults.string(forKey: "piHarnessModel") ?? ""
        
        let savedAutopilot = defaults.string(forKey: "autopilotMode") ?? AutopilotMode.autonomous.rawValue
        self.autopilotMode = AutopilotMode(rawValue: savedAutopilot) ?? .autonomous
        self.maxAutonomousIterations = defaults.integer(forKey: "maxAutonomousIterations") == 0 ? 10 : defaults.integer(forKey: "maxAutonomousIterations")
        
        let savedTheme = defaults.string(forKey: "appTheme") ?? AppThemeMode.system.rawValue
        self.appTheme = AppThemeMode(rawValue: savedTheme) ?? .system
        let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] 
            ?? ProcessInfo.processInfo.environment["GROK_API_KEY"] 
            ?? ProcessInfo.processInfo.environment["XAI_API_KEY"]
            ?? ""
        self.openRouterApiKey = defaults.string(forKey: "openRouterApiKey") ?? envKey
        self.selectedModel = defaults.string(forKey: "selectedModel") ?? "x-ai/grok-4.7"
        self.reasoningEffort = defaults.string(forKey: "reasoningEffort") ?? "low"
        self.autoApproveLow = defaults.object(forKey: "autoApproveLow") as? Bool ?? true
        self.autoApproveMedium = defaults.object(forKey: "autoApproveMedium") as? Bool ?? true
        
        let savedTransport = defaults.string(forKey: "preferredTransport") ?? TransportType.usb.rawValue
        self.preferredTransport = TransportType(rawValue: savedTransport) ?? .usb
        
        self.ttsVoiceEnabled = defaults.bool(forKey: "ttsVoiceEnabled")
        self.customBaudRate = defaults.integer(forKey: "customBaudRate") == 0 ? 230400 : defaults.integer(forKey: "customBaudRate")
        
        self.enableWebMcpServer = defaults.object(forKey: "enableWebMcpServer") as? Bool ?? true
        self.webMcpPort = defaults.integer(forKey: "webMcpPort") == 0 ? 8768 : defaults.integer(forKey: "webMcpPort")
        
        if let cachedData = defaults.data(forKey: "cachedLeaderboardModels"),
           let decoded = try? JSONDecoder().decode([OpenRouterLeaderboardEntry].self, from: cachedData),
           !decoded.isEmpty {
            self.leaderboardModels = decoded
        }
    }
    
    public var leaderboardModels: [OpenRouterLeaderboardEntry] = []
    
    public var effectiveLeaderboard: [OpenRouterLeaderboardEntry] {
        if !leaderboardModels.isEmpty {
            return leaderboardModels
        }
        return OpenRouterLeaderboardService.shared.leaderboard
    }
    
    public func updateWithLeaderboard(_ entries: [OpenRouterLeaderboardEntry]) {
        self.leaderboardModels = entries
        if let encoded = try? JSONEncoder().encode(entries) {
            defaults.set(encoded, forKey: "cachedLeaderboardModels")
        }
    }
    
    public static let availableModels: [(id: String, name: String, desc: String)] = [
        ("stealth/space-bunny-alpha", "Space Bunny Alpha (#1)", "Frontier reasoning engine leading OpenRouter rankings"),
        ("deepseek/deepseek-v4.1-flash", "DeepSeek V4.1 Flash (#2)", "Ultra low-latency MoE model with exceptional reasoning throughput"),
        ("z-ai/glm-5.3-flash", "GLM 5.3 Flash (#3)", "1M context Chinese & English reasoning specialist"),
        ("xiaomi/mimo-v2.6-flash", "MiMo-V2.6-Flash (#4)", "Fast edge-optimized multi-modal model"),
        ("openai/gpt-5.6-luna", "GPT-5.6 Luna (#5)", "OpenAI flagship reasoning and agentic workflow model"),
        ("tencent/hy4-preview", "Hy4 Preview (#6)", "Advanced agentic coding & hardware analysis engine"),
        ("nvidia/nemotron-3.5-lightning:free", "Nemotron 3.5 Lightning (Free)", "High-throughput NVIDIA architecture (Free tier eligible)"),
        ("anthropic/claude-sonnet-5.5", "Claude Sonnet 5.5", "SOTA code generation, tool-use, and firmware synthesis"),
        ("x-ai/grok-4.7", "Grok 4.7 (xAI)", "SOTA reasoning, deep analysis & hardware control"),
        ("nousresearch/hermes-4", "Hermes 4", "Purpose-built for tool-use & agent workflows")
    ]
    
    public static let piHarnessPresets: [(id: String, name: String, desc: String)] = [
        ("", "Host Default (kimi-k3)", "Inherited from ~/.pi/agent/settings.json"),
        ("pi-kimi-coder/kimi-k3", "Kimi K3 (Moonshot)", "Moonshot reasoning coding model (Host default)"),
        ("pi-kimi-coder/kimi-k2.7-code", "Kimi K2.7 Code", "Fast code analysis & tactical execution"),
        ("anthropic/claude-3-7-sonnet", "Claude 3.7 Sonnet (Anthropic)", "Advanced reasoning, tool-use & hardware control"),
        ("anthropic/claude-haiku-4-5", "Claude Haiku 4.5 (Anthropic)", "Fast, low-latency tactical tool execution"),
        ("xai/grok-4.20-0309-reasoning", "Grok 4.20 Reasoning (xAI)", "Deep thinking & RF signal synthesis"),
        ("xai/grok-3", "Grok 3 (xAI)", "Fast security analysis & CLI operations"),
        ("deepseek/deepseek-reasoner", "DeepSeek R1 Reasoner", "Deep open reasoning architecture"),
        ("deepseek/deepseek-chat", "DeepSeek V3", "Low-latency tactical responses"),
        ("openai/gpt-4o", "GPT-4o (OpenAI)", "General multimodal intelligence"),
        ("zai/glm-5.1", "GLM-5.1 (Zhipu AI)", "Long-context coding and reasoning")
    ]
}
