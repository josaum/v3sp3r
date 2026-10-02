import SwiftUI

public struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var piHarness = PiHarnessService.shared
    @State private var apiKeyInput: String = ""
    @State private var isApiKeyVisible: Bool = false
    @State private var saveConfirmation: Bool = false
    @State private var customPiPathInput: String = ""
    @State private var customPiModelInput: String = ""
    @State private var isTestingPiHarness: Bool = false
    @State private var piHarnessTestResult: String?
    @State private var piHarnessTestSuccess: Bool = false
    @State private var webMcp = WebMcpServer.shared
    @State private var copiedMcpToast: String?
    @State private var leaderboardService = OpenRouterLeaderboardService.shared
    @State private var customOpenRouterModelInput: String = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("ferriteSuite Configuration")
                        .font(.title2.bold())
                    Text("Manage AI model credentials, autonomous risk limits, and hardware interfaces.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .glassCard()
                
                // Appearance & Theme Mode Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text("Appearance & Theme")
                            .font(.headline)
                        Spacer()
                        Text("Active: \(settings.appTheme.rawValue)")
                            .font(.caption.monospaced())
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                    }
                    
                    HStack(spacing: 14) {
                        ForEach(AppThemeMode.allCases, id: \.self) { mode in
                            Button(action: { settings.appTheme = mode }) {
                                HStack(spacing: 8) {
                                    Image(systemName: mode.iconName)
                                        .font(.subheadline)
                                        .foregroundColor(settings.appTheme == mode ? FerriteSuiteTheme.accentCyan : .secondary)
                                    Text(mode.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(settings.appTheme == mode ? .bold : .regular)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(settings.appTheme == mode ? FerriteSuiteTheme.accentCyan.opacity(0.15) : FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(settings.appTheme == mode ? FerriteSuiteTheme.accentCyan : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Select Clean Light Mode for daytime high-contrast operation, Cyber Dark Mode for low-light lab environments, or match macOS System appearance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .glassCard()
                
                // AI Engine Architecture Selection
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text("AI Engine Architecture")
                            .font(.headline)
                        Spacer()
                        Text("Selected: \(settings.aiEngine.rawValue)")
                            .font(.caption.monospaced())
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                    }
                    
                    HStack(spacing: 14) {
                        ForEach(AiEngineType.allCases, id: \.self) { engine in
                            Button(action: { settings.aiEngine = engine }) {
                                HStack(spacing: 8) {
                                    Image(systemName: engine.iconName)
                                        .font(.subheadline)
                                        .foregroundColor(settings.aiEngine == engine ? FerriteSuiteTheme.accentCyan : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(engine.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(settings.aiEngine == engine ? .bold : .regular)
                                        Text(engine == .piHarness ? "Host Config (Recommended)" : "Direct Cloud API")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(settings.aiEngine == engine ? FerriteSuiteTheme.accentCyan.opacity(0.15) : FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(settings.aiEngine == engine ? FerriteSuiteTheme.accentCyan : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if settings.aiEngine == .piHarness {
                        Divider().background(FerriteSuiteTheme.subtleBorder)
                        
                        // Embedded Pi Harness Details
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .foregroundColor(FerriteSuiteTheme.neonGreen)
                                Text("Host Pi Coding Agent Harness")
                                    .font(.subheadline.bold())
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(piHarness.isAvailable ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                                        .frame(width: 8, height: 8)
                                    Text(piHarness.isAvailable ? "ONLINE (\(piHarness.version))" : "NOT FOUND")
                                        .font(.caption.monospaced())
                                        .foregroundColor(piHarness.isAvailable ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(piHarness.isAvailable ? FerriteSuiteTheme.neonGreen.opacity(0.15) : FerriteSuiteTheme.neonRed.opacity(0.15))
                                .cornerRadius(6)
                            }
                            
                            Text("ferriteSuite executes directly through your host's installed `pi` coding agent harness (`@earendil-works/pi-coding-agent`), inheriting all models, provider configs, and API tokens from `~/.pi/agent/` without any duplicate credentials.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Host Config Summary
                            if let cfg = piHarness.hostConfig {
                                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                                    GridRow {
                                        Text("Config Path:").font(.caption.bold()).foregroundColor(.secondary)
                                        Text("\(cfg.configDir)/settings.json").font(.caption.monospaced()).foregroundColor(FerriteSuiteTheme.accentCyan)
                                    }
                                    GridRow {
                                        Text("Active Provider:").font(.caption.bold()).foregroundColor(.secondary)
                                        Text(cfg.defaultProvider).font(.caption.monospaced()).foregroundColor(FerriteSuiteTheme.primaryTextColor)
                                    }
                                    GridRow {
                                        Text("Default Model:").font(.caption.bold()).foregroundColor(.secondary)
                                        Text(cfg.defaultModel).font(.caption.monospaced()).foregroundColor(FerriteSuiteTheme.neonGreen)
                                    }
                                    GridRow {
                                        Text("Thinking Level:").font(.caption.bold()).foregroundColor(.secondary)
                                        Text(cfg.defaultThinkingLevel.uppercased()).font(.caption.monospaced()).foregroundColor(FerriteSuiteTheme.cyberPurple)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(8)
                            }
                            
                            // Pi Harness Model Selection
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "cpu")
                                        .foregroundColor(FerriteSuiteTheme.cyberPurple)
                                    Text("Pi Harness Model Intelligence")
                                        .font(.subheadline.bold())
                                    
                                    Spacer()
                                    
                                    Text(settings.piHarnessModel.isEmpty ? "Host Default (\(piHarness.hostConfig?.defaultModel ?? "kimi-k3"))" : settings.piHarnessModel)
                                        .font(.caption2.monospaced())
                                        .foregroundColor(FerriteSuiteTheme.neonGreen)
                                }
                                
                                Text("Choose from popular verified models or enter any custom model supported by pi (e.g. `anthropic/claude-3-7-sonnet`, `xai/grok-4.20-0309-reasoning`, `deepseek/deepseek-reasoner`).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let top1 = leaderboardService.leaderboard.first {
                                    Button(action: {
                                        settings.piHarnessModel = top1.id
                                        customPiModelInput = top1.id
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "trophy.fill")
                                                .foregroundColor(.yellow)
                                            Text("Use #1 Leaderboard: \(top1.name)")
                                                .font(.caption.bold())
                                            Text("(\(top1.id))")
                                                .font(.caption2.monospaced())
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if settings.piHarnessModel == top1.id {
                                                Text("ACTIVE")
                                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                    .foregroundColor(FerriteSuiteTheme.neonGreen)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(settings.piHarnessModel == top1.id ? FerriteSuiteTheme.neonGreen.opacity(0.15) : Color.black.opacity(0.3))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(settings.piHarnessModel == top1.id ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ForEach(AppSettings.piHarnessPresets, id: \.id) { preset in
                                    HStack(alignment: .top) {
                                        RadioButton(isSelected: settings.piHarnessModel == preset.id) {
                                            settings.piHarnessModel = preset.id
                                            customPiModelInput = preset.id
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(preset.name)
                                                .font(.subheadline.bold())
                                            Text(preset.desc)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(preset.id.isEmpty ? "default" : preset.id)
                                            .font(.caption2.monospaced())
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(settings.piHarnessModel == preset.id ? FerriteSuiteTheme.secondaryCardBackground : Color.clear)
                                    .cornerRadius(6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        settings.piHarnessModel = preset.id
                                        customPiModelInput = preset.id
                                    }
                                }
                                
                                // Custom Model Input Field
                                HStack {
                                    TextField("Custom model (e.g. anthropic/claude-3-7-sonnet)", text: $customPiModelInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption.monospaced())
                                    
                                    Button("Set Model") {
                                        settings.piHarnessModel = customPiModelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    if !settings.piHarnessModel.isEmpty {
                                        Button("Reset") {
                                            settings.piHarnessModel = ""
                                            customPiModelInput = ""
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(8)
                            
                            // Custom Binary Path Override
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Harness Executable Location")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField(HostTools.pi.map { $0 } ?? "path to pi", text: $customPiPathInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption.monospaced())
                                    
                                    Button("Apply") {
                                        settings.customPiBinaryPath = customPiPathInput
                                        piHarness.refreshStatus()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: {
                                        isTestingPiHarness = true
                                        piHarnessTestResult = nil
                                        Task {
                                            let res = await piHarness.testHarness()
                                            piHarnessTestSuccess = res.success
                                            piHarnessTestResult = res.message
                                            isTestingPiHarness = false
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            if isTestingPiHarness {
                                                ProgressView().controlSize(.small)
                                            } else {
                                                Image(systemName: "play.circle.fill")
                                            }
                                            Text("Test Harness")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isTestingPiHarness || !piHarness.isAvailable)
                                }
                            }
                            
                            if let testMsg = piHarnessTestResult {
                                HStack {
                                    Image(systemName: piHarnessTestSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(piHarnessTestSuccess ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                                    Text(testMsg)
                                        .font(.caption)
                                        .foregroundColor(piHarnessTestSuccess ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(20)
                .glassCard()
                
                // OpenRouter API Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text("OpenRouter AI Credentials")
                            .font(.headline)
                        Spacer()
                        Link("Get Free API Key ↗", destination: URL(string: "https://openrouter.ai/keys")!)
                            .font(.caption)
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                    }
                    
                    HStack {
                        if isApiKeyVisible {
                            TextField("sk-or-...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.body.monospaced())
                        } else {
                            SecureField("sk-or-...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.body.monospaced())
                        }
                        
                        Button(action: { isApiKeyVisible.toggle() }) {
                            Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                        }
                        
                        Button("Save Key") {
                            settings.openRouterApiKey = apiKeyInput
                            saveConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                saveConfirmation = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if saveConfirmation {
                        Text("✓ API Key Saved Successfully")
                            .font(.caption)
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                    }
                }
                .padding(20)
                .glassCard()
                
                // OpenRouter Model Intelligence & Live Rankings Leaderboard
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text("OpenRouter Model Leaderboard")
                                    .font(.headline)
                                
                                Link(destination: URL(string: "https://openrouter.ai/rankings")!) {
                                    HStack(spacing: 4) {
                                        Text("openrouter.ai/rankings")
                                            .font(.caption2.monospaced())
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 8))
                                    }
                                    .foregroundColor(FerriteSuiteTheme.accentCyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FerriteSuiteTheme.accentCyan.opacity(0.12))
                                    .cornerRadius(4)
                                }
                            }
                            
                            Text("Real-time token volume rankings from openrouter.ai/rankings. Top models auto-tune inference speed & context depth.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Live Sync Button
                        Button(action: {
                            Task {
                                await leaderboardService.fetchLiveLeaderboard()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if leaderboardService.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(leaderboardService.isLoading ? "Syncing..." : "Sync Rankings")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(FerriteSuiteTheme.accentCyan.opacity(0.18))
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(FerriteSuiteTheme.accentCyan.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(leaderboardService.isLoading)
                    }
                    
                    // Status & Timestamp Banner
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                        
                        Text(leaderboardService.statusMessage.isEmpty ? "Live Leaderboard Active" : leaderboardService.statusMessage)
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let lastUpdated = leaderboardService.lastUpdated {
                            Text("Updated: \(lastUpdated.formatted(date: .omitted, time: .standard))")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(6)
                    
                    // Ranked Models List
                    let modelsToDisplay = leaderboardService.leaderboard.isEmpty ? settings.effectiveLeaderboard : leaderboardService.leaderboard
                    
                    ForEach(modelsToDisplay) { model in
                        let isSelected = settings.selectedModel == model.id
                        HStack(alignment: .top, spacing: 12) {
                            RadioButton(isSelected: isSelected) {
                                settings.selectedModel = model.id
                                customOpenRouterModelInput = model.id
                            }
                            .padding(.top, 4)
                            
                            // Rank Badge
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(rankBadgeBackgroundColor(rank: model.rank))
                                    .frame(width: 38, height: 32)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(rankBadgeBorderColor(rank: model.rank), lineWidth: 1)
                                    )
                                
                                Text("#\(model.rank)")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundColor(rankBadgeTextColor(rank: model.rank))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(model.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(isSelected ? FerriteSuiteTheme.accentCyan : FerriteSuiteTheme.primaryTextColor)
                                    
                                    // Author Chip
                                    Text(model.author.uppercased())
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(4)
                                        .foregroundColor(.secondary)
                                    
                                    // Volume Chip
                                    Text(model.tokensProcessed)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(FerriteSuiteTheme.neonGreen.opacity(0.15))
                                        .cornerRadius(4)
                                        .foregroundColor(FerriteSuiteTheme.neonGreen)
                                    
                                    // Growth Chip
                                    if !model.growth.isEmpty {
                                        Text(model.growth)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(growthChipColor(model.growth).opacity(0.15))
                                            .cornerRadius(4)
                                            .foregroundColor(growthChipColor(model.growth))
                                    }
                                    
                                    // Context Chip
                                    Text(formatContextLength(model.contextLength))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(FerriteSuiteTheme.cyberPurple.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundColor(FerriteSuiteTheme.cyberPurple)
                                    
                                    if model.isFree {
                                        Text("FREE")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                if !model.description.isEmpty {
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                HStack {
                                    Text(model.id)
                                        .font(.caption2.monospaced())
                                        .foregroundColor(isSelected ? FerriteSuiteTheme.accentCyan : .secondary)
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(FerriteSuiteTheme.neonGreen)
                                                .frame(width: 6, height: 6)
                                            Text("ACTIVE INFERENCE MODEL")
                                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                .foregroundColor(FerriteSuiteTheme.neonGreen)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(isSelected ? FerriteSuiteTheme.accentCyan.opacity(0.08) : FerriteSuiteTheme.secondaryCardBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? FerriteSuiteTheme.accentCyan.opacity(0.7) : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            settings.selectedModel = model.id
                            customOpenRouterModelInput = model.id
                        }
                    }
                    
                    // Custom OpenRouter Model Input Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom OpenRouter Model Identifier")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("e.g. anthropic/claude-3-7-sonnet or x-ai/grok-4.7", text: $customOpenRouterModelInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                            
                            Button("Set Model") {
                                let trimmed = customOpenRouterModelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    settings.selectedModel = trimmed
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        // Quick Presets
                        HStack(spacing: 8) {
                            Text("Classics:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(["x-ai/grok-4.7", "anthropic/claude-sonnet-5.5", "nousresearch/hermes-4"], id: \.self) { preset in
                                Button(action: {
                                    settings.selectedModel = preset
                                    customOpenRouterModelInput = preset
                                }) {
                                    Text(preset.components(separatedBy: "/").last ?? preset)
                                        .font(.caption2.monospaced())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(settings.selectedModel == preset ? FerriteSuiteTheme.accentCyan.opacity(0.2) : Color.white.opacity(0.05))
                                        .cornerRadius(4)
                                        .foregroundColor(settings.selectedModel == preset ? FerriteSuiteTheme.accentCyan : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(8)
                }
                .padding(20)
                .glassCard()
                
                // Reasoning Effort
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text("Reasoning Effort")
                            .font(.headline)
                        Spacer()
                        Text("Active: \(settings.reasoningEffort.uppercased())")
                            .font(.caption.monospaced())
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                    }
                    
                    HStack(spacing: 12) {
                        ForEach(["low", "medium", "high"], id: \.self) { effort in
                            Button(action: { settings.reasoningEffort = effort }) {
                                HStack {
                                    Circle()
                                        .fill(settings.reasoningEffort == effort ? FerriteSuiteTheme.neonGreen : Color.clear)
                                        .frame(width: 8, height: 8)
                                    Text(effort.capitalized)
                                        .font(.subheadline)
                                        .fontWeight(settings.reasoningEffort == effort ? .bold : .regular)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(settings.reasoningEffort == effort ? FerriteSuiteTheme.accentCyan.opacity(0.15) : FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(settings.reasoningEffort == effort ? FerriteSuiteTheme.accentCyan : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Controls the thinking depth for reasoning models like Grok 4.7. 'Low' minimizes latency for fast tactical hardware execution.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .glassCard()
                
                // Autonomous Risk Limits
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                        Text("Autonomous Autopilot & Safety Engine")
                            .font(.headline)
                        Spacer()
                        Text(settings.autopilotMode.rawValue)
                            .font(.caption.monospaced())
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                    }
                    
                    // Autopilot Mode Picker
                    HStack(spacing: 12) {
                        ForEach(AutopilotMode.allCases, id: \.self) { mode in
                            Button(action: { settings.autopilotMode = mode }) {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.iconName)
                                        .font(.caption)
                                    Text(mode.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(settings.autopilotMode == mode ? .bold : .regular)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(settings.autopilotMode == mode ? FerriteSuiteTheme.neonGreen.opacity(0.18) : FerriteSuiteTheme.secondaryCardBackground)
                                .foregroundColor(settings.autopilotMode == mode ? FerriteSuiteTheme.neonGreen : .secondary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(settings.autopilotMode == mode ? FerriteSuiteTheme.neonGreen.opacity(0.6) : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Max Autonomous Steps Stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max Autonomous Mission Steps")
                                .font(.subheadline.bold())
                            Text("Maximum chained actions ferriteSuite can execute unattended before requesting operator review.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Stepper("\(settings.maxAutonomousIterations) Steps", value: $settings.maxAutonomousIterations, in: 3...30, step: 1)
                            .font(.subheadline.monospaced())
                    }
                    
                    Divider().background(FerriteSuiteTheme.subtleBorder)
                    
                    Toggle(isOn: $settings.autoApproveLow) {
                        VStack(alignment: .leading) {
                            Text("Auto-approve Low Risk Actions")
                                .font(.subheadline.bold())
                            Text("Directory listings, file reads, battery/storage queries, and LED indicators execute immediately without prompting.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider().background(FerriteSuiteTheme.subtleBorder)
                    
                    Toggle(isOn: $settings.autoApproveMedium) {
                        VStack(alignment: .leading) {
                            Text("Auto-approve Medium Risk Actions")
                                .font(.subheadline.bold())
                            Text("File writes, directory creation, RF transmissions, and app launching execute without manual confirmation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider().background(FerriteSuiteTheme.subtleBorder)
                    
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(FerriteSuiteTheme.neonRed)
                        VStack(alignment: .leading) {
                            Text("High Risk Actions Always Protected")
                                .font(.subheadline.bold())
                            Text("BadUSB payload executions, file deletions, and destructive operations will ALWAYS require your explicit double-tap confirmation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                }
                .padding(20)
                .glassCard()
                
                // WebMCP Server & AI Bridge
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text("WebMCP Server & AI Bridge")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(webMcp.isRunning ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                                .frame(width: 8, height: 8)
                            Text(webMcp.isRunning ? "RUNNING :\(webMcp.port)" : "STOPPED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(webMcp.isRunning ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.neonRed)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(webMcp.isRunning ? FerriteSuiteTheme.neonGreen.opacity(0.15) : FerriteSuiteTheme.neonRed.opacity(0.15))
                        .cornerRadius(6)
                    }
                    
                    Text("Expose Flipper Zero hardware controls (Sub-GHz, IR, BadUSB, SD card, GPIO) via standard Model Context Protocol (MCP) JSON-RPC 2.0 endpoints for Claude Desktop, Cursor, and web-based AI agents.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle(isOn: $settings.enableWebMcpServer) {
                        VStack(alignment: .leading) {
                            Text("Enable WebMCP HTTP/SSE Server")
                                .font(.subheadline.bold())
                            Text("Listens on localhost (127.0.0.1:\(settings.webMcpPort)) with CORS enabled.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    if settings.enableWebMcpServer {
                        Divider().background(FerriteSuiteTheme.subtleBorder)
                        
                        // Telemetry & Port Grid
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Listening Port")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("8765", value: $settings.webMcpPort, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Button("Restart") {
                                        webMcp.restart(port: settings.webMcpPort)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Live Telemetry")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                HStack(spacing: 12) {
                                    VStack(alignment: .center) {
                                        Text("\(webMcp.requestCount)")
                                            .font(.headline.monospaced())
                                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                                        Text("Requests")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    VStack(alignment: .center) {
                                        Text("\(webMcp.activeSseClients)")
                                            .font(.headline.monospaced())
                                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                                        Text("SSE Clients")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Divider().background(FerriteSuiteTheme.subtleBorder)
                        
                        // Integration snippet buttons
                        VStack(alignment: .leading, spacing: 8) {
                            Text("External AI Client Setup")
                                .font(.caption.bold())
                                .foregroundColor(FerriteSuiteTheme.primaryTextColor)
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    let cfg = """
                                    {
                                      "mcpServers": {
                                        "flipper-vesper": {
                                          "url": "http://127.0.0.1:\(settings.webMcpPort)/sse"
                                        }
                                      }
                                    }
                                    """
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(cfg, forType: .string)
                                    copiedMcpToast = "Copied Claude Desktop Config!"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedMcpToast = nil }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Claude Desktop JSON")
                                    }
                                    .font(.caption.bold())
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(FerriteSuiteTheme.cyberPurple)
                                
                                Button(action: {
                                    let curl = "curl -s http://127.0.0.1:\(settings.webMcpPort)/health | jq ."
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(curl, forType: .string)
                                    copiedMcpToast = "Copied curl health command!"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedMcpToast = nil }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "terminal")
                                        Text("Copy Health Check curl")
                                    }
                                    .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                                
                                if let toast = copiedMcpToast {
                                    Text("✓ \(toast)")
                                        .font(.caption.bold())
                                        .foregroundColor(FerriteSuiteTheme.neonGreen)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .glassCard()
            }
            .padding(20)
        }
        .background(FerriteSuiteTheme.darkBackground)
        .onAppear {
            apiKeyInput = settings.openRouterApiKey
            customPiPathInput = settings.customPiBinaryPath.isEmpty ? piHarness.executablePath : settings.customPiBinaryPath
            customPiModelInput = settings.piHarnessModel
            customOpenRouterModelInput = settings.selectedModel
            piHarness.refreshStatus()
            Task {
                await leaderboardService.fetchLiveLeaderboard()
            }
        }
    }
    
    // MARK: - Leaderboard Visual Helpers
    
    private func rankBadgeBackgroundColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow.opacity(0.2)
        case 2: return Color.white.opacity(0.15)
        case 3: return Color.orange.opacity(0.2)
        default: return FerriteSuiteTheme.cyberPurple.opacity(0.15)
        }
    }
    
    private func rankBadgeBorderColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.white.opacity(0.6)
        case 3: return Color.orange
        default: return FerriteSuiteTheme.subtleBorder
        }
    }
    
    private func rankBadgeTextColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.white
        case 3: return Color.orange
        default: return FerriteSuiteTheme.accentCyan
        }
    }
    
    private func growthChipColor(_ growth: String) -> Color {
        if growth.contains("-") {
            return Color.red.opacity(0.8)
        }
        return FerriteSuiteTheme.neonGreen
    }
    
    private func formatContextLength(_ len: Int) -> String {
        if len >= 1_000_000 {
            return String(format: "%.1fM ctx", Double(len) / 1_000_000.0).replacingOccurrences(of: ".0M", with: "M")
        } else if len >= 1_000 {
            return "\(len / 1_000)K ctx"
        }
        return "\(len) ctx"
    }
}

private struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .stroke(isSelected ? FerriteSuiteTheme.accentCyan : Color.secondary, lineWidth: 2)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(isSelected ? FerriteSuiteTheme.accentCyan : Color.clear)
                        .frame(width: 8, height: 8)
                )
        }
        .buttonStyle(.plain)
    }
}
