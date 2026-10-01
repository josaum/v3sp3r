import SwiftUI
import AppKit

public struct QuickstartSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 0
    @State private var connection = FlipperConnectionManager.shared
    @State private var server = WebMcpServer.shared
    @State private var copiedConfirmation: Bool = false
    
    let totalSteps = 5
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("V3SP3R OPERATOR ONBOARDING")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(VesperTheme.accentCyan)
                    Text("Interactive System Walkthrough")
                        .font(.title3.bold())
                        .foregroundColor(VesperTheme.primaryTextColor)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(VesperTheme.cardBackground)
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Step Body
            VStack(spacing: 20) {
                switch currentStep {
                case 0:
                    stepHardwareConnection
                case 1:
                    stepWorkflows
                case 2:
                    stepFerrite
                case 3:
                    stepWebMcp
                case 4:
                    stepReady
                default:
                    EmptyView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider().background(VesperTheme.subtleBorder)
            
            // Footer Navigation
            HStack {
                // Progress Dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentStep ? VesperTheme.accentCyan : VesperTheme.subtleBorder)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                if currentStep > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                if currentStep < totalSteps - 1 {
                    Button("Next Step") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VesperTheme.accentCyan)
                } else {
                    Button("Finish & Launch") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VesperTheme.neonGreen)
                }
            }
            .padding(20)
            .background(VesperTheme.cardBackground)
        }
        .frame(width: 620, height: 490)
        .background(VesperTheme.darkBackground)
    }
    
    // Step 0: Hardware Connection
    private var stepHardwareConnection: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector.horizontal")
                .font(.system(size: 42))
                .foregroundColor(connection.status.isConnected ? VesperTheme.neonGreen : VesperTheme.flipperOrange)
            
            Text("Step 1: Connect Your Flipper Zero")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            Text("Plug in your Flipper Zero using USB-C. V3SP3R automatically scans serial ports (`/dev/cu.usbmodemflip_*`) and starts bidirectional CLI communication.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(connection.status.isConnected ? VesperTheme.neonGreen : VesperTheme.neonRed)
                    .frame(width: 10, height: 10)
                Text(connection.status.isConnected ? "Hardware Online: \(connection.deviceInfo.hardwareModel) (\(connection.deviceInfo.firmwareVersion))" : "Waiting for Flipper connection...")
                    .font(.caption.bold().monospaced())
                    .foregroundColor(connection.status.isConnected ? VesperTheme.neonGreen : .secondary)
            }
            .padding(10)
            .background(VesperTheme.cardBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(VesperTheme.subtleBorder, lineWidth: 1))
        }
    }
    
    // Step 1: Workflows & DAG
    private var stepWorkflows: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .foregroundColor(VesperTheme.flipperOrange)
            
            Text("Step 2: Autonomous Workflows & Subgraphs")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            Text("Execute multi-stage hardware DAGs with real-time telemetry streaming in chat. Pause, resume, or single-step execution safely with automatic safety guardrails.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 6) {
                workflowBullet("Sub-GHz Full Spectrum Recon", desc: "Checks SD storage, scans 433 & 868 MHz, validates raw captures")
                workflowBullet("Hardware Diagnostic Self-Test", desc: "Queries firmware, battery, storage, and tests RGB LED and vibro")
                workflowBullet("Access Control Badge Auditor", desc: "Audits RFID & NFC keys and generates safety reports")
            }
            .padding(12)
            .background(VesperTheme.cardBackground)
            .cornerRadius(8)
        }
    }
    
    // Step 2: FerriteOS
    private var stepFerrite: some View {
        VStack(spacing: 16) {
            Image(systemName: "atom")
                .font(.system(size: 42))
                .foregroundColor(VesperTheme.cyberPurple)
            
            Text("Step 3: FerriteOS Offline Intent Engine")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            Text("FerriteOS is a deterministic Rust-based natural language model running locally on your Mac. Type commands like 'scan 433mhz' or 'dump memory vault' to trigger actions instantly without cloud latency or internet.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(VesperTheme.neonGreen)
                Text("Zero API tokens required • 100% Air-Gapped Capable")
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.neonGreen)
            }
            .padding(8)
            .background(VesperTheme.neonGreen.opacity(0.12))
            .cornerRadius(6)
        }
    }
    
    // Step 3: WebMCP Protocol
    private var stepWebMcp: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 42))
                .foregroundColor(VesperTheme.accentCyan)
            
            Text("Step 4: WebMCP AI Bridge (Claude Desktop / Cursor)")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            Text("V3SP3R runs an embedded Model Context Protocol (MCP) server on port \(server.port). Connect Claude Desktop or Cursor to pilot your Flipper Zero from external AI environments.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Button(action: {
                let json = """
                {
                  "mcpServers": {
                    "flipper-vesper": {
                      "url": "http://127.0.0.1:\(server.port)/sse"
                    }
                  }
                }
                """
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(json, forType: .string)
                copiedConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copiedConfirmation = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: copiedConfirmation ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copiedConfirmation ? "Copied Claude Config!" : "Copy Claude Desktop JSON Config")
                }
                .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(copiedConfirmation ? VesperTheme.neonGreen : VesperTheme.accentCyan)
        }
    }
    
    // Step 4: Ready
    private var stepReady: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46))
                .foregroundColor(VesperTheme.neonGreen)
            
            Text("Ready for Field Operations")
                .font(.title3.bold())
                .foregroundColor(VesperTheme.primaryTextColor)
            
            Text("You are ready to command your Flipper Zero with full AI autonomy, visual workflows, and tactical memory persistence. You can re-open this guide anytime via the '?' icon.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                Label("Memory Vault Active", systemImage: "brain")
                Text("•").foregroundColor(.secondary)
                Label("WebMCP Online", systemImage: "network")
                Text("•").foregroundColor(.secondary)
                Label("FerriteOS Ready", systemImage: "atom")
            }
            .font(.caption.bold())
            .foregroundColor(VesperTheme.accentCyan)
            .padding(10)
            .background(VesperTheme.cardBackground)
            .cornerRadius(8)
        }
    }
    
    private func workflowBullet(_ title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(VesperTheme.flipperOrange)
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(VesperTheme.primaryTextColor)
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
