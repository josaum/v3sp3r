import SwiftUI

public struct PayloadLabView: View {
    @State private var connection = FlipperConnectionManager.shared
    @State private var payloadName: String = "macos_open_terminal"
    @State private var payloadScript: String = """
REM macOS Terminal Launcher
DELAY 1000
GUI SPACE
DELAY 400
STRING Terminal
DELAY 400
ENTER
DELAY 800
STRING echo "Hello from Vesper on Flipper Zero!"
ENTER
"""
    @State private var statusMessage: String = ""
    @State private var isDeploying: Bool = false
    
    private let templates: [BadUsbScript] = [
        BadUsbScript(
            name: "macos_open_terminal",
            script: "REM Open Terminal on macOS\nDELAY 1000\nGUI SPACE\nDELAY 400\nSTRING Terminal\nDELAY 400\nENTER\nDELAY 800\nSTRING echo 'Controlled by Vesper AI'\nENTER\n",
            description: "Launches macOS Terminal via Spotlight and prints a banner",
            targetOs: "macOS"
        ),
        BadUsbScript(
            name: "rickroll_macos",
            script: "REM Rickroll on macOS\nDELAY 1000\nGUI SPACE\nDELAY 400\nSTRING Terminal\nDELAY 400\nENTER\nDELAY 800\nSTRING open https://www.youtube.com/watch?v=dQw4w9WgXcQ\nENTER\n",
            description: "Opens default browser to the classic Rick Astley video",
            targetOs: "macOS"
        ),
        BadUsbScript(
            name: "windows_notepad",
            script: "REM Windows Notepad Banner\nDELAY 1000\nGUI r\nDELAY 400\nSTRING notepad\nDELAY 300\nENTER\nDELAY 800\nSTRING Vesper: Hardware hacking simplified.\n",
            description: "Spawns Notepad on Windows and types a message",
            targetOs: "Windows"
        )
    ]
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Template List
            VStack(alignment: .leading, spacing: 12) {
                Text("Payload Templates")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                List(templates) { template in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(template.name)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(template.targetOs)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        Text(template.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        payloadName = template.name
                        payloadScript = template.script
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 260)
            .background(VesperTheme.cardBackground)
            
            // Editor & Deployment
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payload Script Editor (DuckyScript)")
                            .font(.headline)
                        TextField("Payload Name", text: $payloadName)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(payloadScript, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(7)
                            .background(VesperTheme.secondaryCardBackground)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Copy script to clipboard")
                    
                    Button(action: deployPayload) {
                        if isDeploying {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("Push to SD Card", systemImage: "arrow.up.doc.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VesperTheme.secondaryCardBackground)
                                .foregroundColor(VesperTheme.accentCyan)
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeploying)
                    
                    Button(action: runPayloadOnFlipper) {
                        Label("Execute Now", systemImage: "play.fill")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(VesperTheme.neonAmber)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Deploy and run BadUSB on Flipper")
                }
                
                TextEditor(text: $payloadScript)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundColor(VesperTheme.primaryTextColor)
                    .padding(8)
                    .background(VesperTheme.codeBlockBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                    )
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VesperTheme.accentCyan)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VesperTheme.terminalBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(VesperTheme.subtleBorder, lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .frame(minWidth: 400)
        }
        .background(VesperTheme.darkBackground)
    }
    
    private func deployPayload() {
        isDeploying = true
        statusMessage = "Writing payload to Flipper /ext/badusb/\(payloadName).txt..."
        
        Task {
            let path = "/ext/badusb/\(payloadName).txt"
            let executor = FlipperToolExecutor.shared
            let res = await executor.execute(action: "write_file", params: ["path": path, "content": payloadScript])
            
            DispatchQueue.main.async {
                self.isDeploying = false
                if res.isError {
                    self.statusMessage = "Deployment error: \(res.output)"
                } else {
                    self.statusMessage = "Success! Deployed to \(path). Ready to launch via Bad USB."
                }
            }
        }
    }
    
    private func runPayloadOnFlipper() {
        deployPayload()
        let path = "/ext/badusb/\(payloadName).txt"
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            let executor = FlipperToolExecutor.shared
            let res = await executor.execute(action: "badusb_execute", params: ["path": path])
            DispatchQueue.main.async {
                if res.isError {
                    self.statusMessage = "Execution error: \(res.output)"
                } else {
                    self.statusMessage = "Running '\(payloadName)' via Flipper Bad USB..."
                }
            }
        }
    }
}
