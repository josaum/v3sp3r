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
    }
    
    public static let availableModels: [(id: String, name: String, desc: String)] = [
        ("x-ai/grok-4.7", "Grok 4.7 (xAI)", "SOTA reasoning, deep analysis & hardware control (Recommended)"),
        ("x-ai/grok-4.5", "Grok 4.5 (xAI)", "High-performance low-latency xAI intelligence"),
        ("nousresearch/hermes-4", "Hermes 4", "Purpose-built for tool-use & agent workflows"),
        ("anthropic/claude-sonnet-4", "Claude Sonnet 4", "Best balance of speed and intelligence"),
        ("anthropic/claude-opus-4.6", "Claude Opus 4.6", "Deep reasoning model for complex RF/firmware"),
        ("anthropic/claude-haiku-4", "Claude Haiku 4", "Blazing fast for simple reads and queries"),
        ("openai/gpt-4o", "GPT-4o", "Strong general multimodal alternative")
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
