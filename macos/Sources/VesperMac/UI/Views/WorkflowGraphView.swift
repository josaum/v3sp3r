import SwiftUI

public struct WorkflowGraphView: View {
    @State private var engine = WorkflowEngine.shared
    @State private var connection = FlipperConnectionManager.shared
    @State private var selectedTemplateIndex: Int = 0
    @State private var showLogsDrawer: Bool = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top HUD Bar with Controls
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workflow Subgraphs & Tasks")
                        .font(.headline)
                    Text(engine.activeWorkflow?.title ?? "No Active Workflow")
                        .font(.subheadline)
                        .foregroundColor(VesperTheme.accentCyan)
                }
                
                Spacer()
                
                // Template Picker
                Picker("Template", selection: $selectedTemplateIndex) {
                    ForEach(engine.availableTemplates.indices, id: \.self) { idx in
                        Text(engine.availableTemplates[idx].title).tag(idx)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
                .onChange(of: selectedTemplateIndex) { _, newIdx in
                    engine.activeWorkflow = engine.availableTemplates[newIdx]
                }
                
                // Controls Group: Run, Pause/Resume, Step, Reset
                HStack(spacing: 8) {
                    if !engine.isExecuting {
                        Button(action: { engine.start() }) {
                            Label("Run", systemImage: "play.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VesperTheme.neonGreen.opacity(0.2))
                                .foregroundColor(VesperTheme.neonGreen)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if engine.isPaused {
                        Button(action: { engine.resume() }) {
                            Label("Resume", systemImage: "play.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VesperTheme.neonGreen.opacity(0.2))
                                .foregroundColor(VesperTheme.neonGreen)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { engine.pause() }) {
                            Label("Pause", systemImage: "pause.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VesperTheme.neonAmber.opacity(0.25))
                                .foregroundColor(VesperTheme.neonAmber)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(VesperTheme.neonAmber, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: { engine.step() }) {
                        Label("Step", systemImage: "forward.frame.fill")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isExecuting && !engine.isPaused)
                    .help("Execute single next task and pause")
                    
                    Button(action: { engine.stop() }) {
                        Image(systemName: "stop.fill")
                            .padding(8)
                            .background(VesperTheme.secondaryCardBackground)
                            .foregroundColor(engine.isExecuting ? VesperTheme.neonRed : .secondary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!engine.isExecuting)
                    .help("Stop Workflow")
                    
                    Button(action: { engine.reset() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .padding(8)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Reset Tasks to Initial State")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(VesperTheme.cardBackground)
            
            // Progress Ticker
            if let wf = engine.activeWorkflow {
                HStack(spacing: 12) {
                    ProgressView(value: wf.progressFraction)
                        .progressViewStyle(.linear)
                        .tint(wf.executionState.color)
                    
                    Text("\(wf.completedTasksCount)/\(wf.totalTasksCount) Tasks")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    
                    Text(wf.executionState.rawValue)
                        .font(.caption.bold().monospaced())
                        .foregroundColor(wf.executionState.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(wf.executionState.color.opacity(0.15))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(VesperTheme.darkBackground)
            }
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Subgraph Canvas
            ScrollView {
                VStack(spacing: 20) {
                    if let workflow = engine.activeWorkflow {
                        ForEach(workflow.subgraphs.indices, id: \.self) { sgIndex in
                            let subgraph = workflow.subgraphs[sgIndex]
                            SubgraphCard(subgraph: subgraph, sgIndex: sgIndex, isCurrent: workflow.currentSubgraphIndex == sgIndex && engine.isExecuting)
                            
                            // Arrow connector between subgraphs
                            if sgIndex < workflow.subgraphs.count - 1 {
                                Image(systemName: "arrow.down")
                                    .font(.caption.bold())
                                    .foregroundColor(VesperTheme.accentCyan.opacity(0.6))
                                    .padding(.vertical, -6)
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            // Live Execution Log Console
            if showLogsDrawer {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("Workflow Execution Telemetry")
                            .font(.caption.bold())
                        Spacer()
                        Button(action: { showLogsDrawer.toggle() }) {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(engine.executionLogs.indices, id: \.self) { idx in
                                    Text(engine.executionLogs[idx])
                                        .font(.caption2.monospaced())
                                        .foregroundColor(engine.executionLogs[idx].contains("❌") ? VesperTheme.neonRed : (engine.executionLogs[idx].contains("✓") ? VesperTheme.neonGreen : .secondary))
                                        .id(idx)
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                        .onChange(of: engine.executionLogs.count) { _, _ in
                            if let last = engine.executionLogs.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
                .padding(12)
                .background(VesperTheme.cardBackground)
                .border(VesperTheme.subtleBorder, width: 1)
            }
        }
        .background(VesperTheme.darkBackground)
    }
}

// MARK: - Subgraph Card View

private struct SubgraphCard: View {
    let subgraph: WorkflowSubgraph
    let sgIndex: Int
    let isCurrent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subgraph Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(subgraph.isCompleted ? VesperTheme.neonGreen : (subgraph.isRunning ? VesperTheme.accentCyan : (subgraph.isPaused ? VesperTheme.neonAmber : .secondary)))
                        .frame(width: 10, height: 10)
                    
                    Text(subgraph.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(subgraph.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Tasks in Subgraph
            VStack(spacing: 8) {
                ForEach(subgraph.tasks) { task in
                    TaskRow(task: task)
                }
            }
        }
        .padding(16)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? VesperTheme.accentCyan.opacity(0.8) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Task Row View

private struct TaskRow: View {
    let task: WorkflowTask
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Status icon
                Image(systemName: task.status.iconName)
                    .foregroundColor(task.status.color)
                    .font(.body)
                    .frame(width: 20)
                
                // Type icon
                Image(systemName: task.type.iconName)
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                // Title & Command
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(task.status == .running ? .bold : .regular)
                    
                    if !task.command.isEmpty {
                        Text(task.command)
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Timing & Status label
                if task.executionTimeMs > 0 {
                    Text("\(task.executionTimeMs)ms")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
                
                Text(task.status.label)
                    .font(.caption2.monospaced())
                    .foregroundColor(task.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(task.status.color.opacity(0.12))
                    .cornerRadius(4)
                
                if !task.output.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(VesperTheme.secondaryCardBackground)
            .cornerRadius(8)
            
            // Telemetry Badges Flow
            if !task.telemetryBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(task.telemetryBadges.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                            HStack(spacing: 4) {
                                Text(key)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(val)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(key.contains("Vulnerab") || key.contains("Risk") || key.contains("Fixed") ? VesperTheme.neonRed : VesperTheme.accentCyan)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(VesperTheme.cardBackground)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(VesperTheme.subtleBorder, lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            
            // Interactive Action Decision / Disambiguation Box
            if !task.options.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if let prompt = task.interactivePrompt {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundColor(VesperTheme.neonAmber)
                            Text(prompt)
                                .font(.caption.bold())
                                .foregroundColor(VesperTheme.neonAmber)
                        }
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(task.options, id: \.self) { opt in
                            Button(action: {
                                WorkflowEngine.shared.selectOption(taskId: task.id, option: opt)
                            }) {
                                HStack {
                                    Text(opt)
                                        .font(.caption.bold())
                                        .foregroundColor(task.selectedOption == opt ? VesperTheme.neonGreen : .primary)
                                    Spacer()
                                    if task.selectedOption == opt {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(VesperTheme.neonGreen)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(task.selectedOption == opt ? VesperTheme.neonGreen.opacity(0.15) : VesperTheme.cardBackground)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(task.selectedOption == opt ? VesperTheme.neonGreen : VesperTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(task.selectedOption != nil && task.selectedOption != opt)
                        }
                    }
                }
                .padding(10)
                .background(VesperTheme.neonAmber.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(VesperTheme.neonAmber.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 10)
            }
            
            // Web Insights & Protocol Documentation
            if !task.webInsights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "globe.badge.chevron.backward")
                            .font(.caption)
                            .foregroundColor(VesperTheme.accentCyan)
                        Text("Web & Protocol Intelligence")
                            .font(.caption2.bold())
                            .foregroundColor(VesperTheme.accentCyan)
                    }
                    
                    ForEach(task.webInsights) { insight in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(insight.title)
                                    .font(.caption2.bold())
                                    .foregroundColor(.primary)
                                Spacer()
                                if let url = URL(string: insight.url) {
                                    Link(destination: url) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption2)
                                            .foregroundColor(VesperTheme.accentCyan)
                                    }
                                }
                            }
                            Text(insight.snippet)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                            
                            if !insight.tags.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(insight.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(VesperTheme.cardBackground)
                                            .cornerRadius(3)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(VesperTheme.cardBackground.opacity(0.7))
                        .cornerRadius(6)
                    }
                }
                .padding(10)
                .background(VesperTheme.secondaryCardBackground)
                .cornerRadius(8)
                .padding(.horizontal, 10)
            }
            
            // Output disclosure
            if isExpanded && !task.output.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task Output:")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    Text(task.output)
                        .font(.caption2.monospaced())
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }
}
