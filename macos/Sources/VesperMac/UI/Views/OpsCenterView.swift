import SwiftUI

public struct OpsCenterView: View {
    @State private var connection = FlipperConnectionManager.shared
    @State private var commandInput: String = ""
    @State private var commandHistory: [String] = []
    @State private var consoleOutput: String = "Vesper Hardware Console Initialized.\nReady for direct Flipper CLI commands (type 'help' for built-in commands).\n"
    @State private var isExecuting: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Diagnostic Bar
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(connection.status.isConnected ? VesperTheme.neonGreen : VesperTheme.neonRed)
                        .frame(width: 8, height: 8)
                    Text("Transport: \(connection.status.description)")
                        .font(.caption.monospaced())
                }
                
                Spacer()
                
                Button(action: {
                    consoleOutput = ""
                }) {
                    Label("Clear Console", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(VesperTheme.cardBackground)
            
            Divider()
                .background(VesperTheme.subtleBorder)
            
            // Console Terminal Output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(consoleOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(VesperTheme.accentCyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                        .id("consoleBottom")
                }
                .background(Color.black.opacity(0.85))
                .onChange(of: consoleOutput) {
                    withAnimation {
                        proxy.scrollTo("consoleBottom", anchor: .bottom)
                    }
                }
            }
            
            Divider()
                .background(VesperTheme.subtleBorder)
            
            // CLI Input Box
            HStack(spacing: 8) {
                Text(">:")
                    .font(.body.monospaced().bold())
                    .foregroundColor(VesperTheme.flipperOrange)
                
                TextField("Enter Flipper CLI command (e.g. 'help', 'info device', 'storage info /ext')...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.body.monospaced())
                    .onSubmit {
                        submitCliCommand()
                    }
                
                Button(action: submitCliCommand) {
                    if isExecuting {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Image(systemName: "return")
                            .font(.body)
                            .foregroundColor(VesperTheme.accentCyan)
                    }
                }
                .buttonStyle(.plain)
                .disabled(commandInput.isEmpty || isExecuting)
            }
            .padding(12)
            .background(VesperTheme.cardBackground)
        }
        .background(VesperTheme.darkBackground)
    }
    
    private func submitCliCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        
        commandInput = ""
        consoleOutput += "\n>: \(cmd)\n"
        isExecuting = true
        
        Task {
            do {
                let out = try await connection.executeCommand(cmd)
                DispatchQueue.main.async {
                    self.consoleOutput += out
                    self.isExecuting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.consoleOutput += "Error: \(error.localizedDescription)\n"
                    self.isExecuting = false
                }
            }
        }
    }
}
