import SwiftUI

public struct SignalLabView: View {
    @State private var connection = FlipperConnectionManager.shared
    @State private var signalName: String = "custom_test"
    @State private var frequency: Double = 433.92
    @State private var pulseCount: Int = 16
    @State private var pulseWidth: Double = 400
    @State private var statusText: String = ""
    @State private var isSending: Bool = false
    
    private let frequencies: [Double] = [315.00, 433.92, 868.35, 915.00]
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("RF Signal Alchemy & Waveform Lab")
                                .font(.title2.bold())
                            
                            if connection.isFerriteOS {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(FerriteSuiteTheme.neonGreen)
                                    Text("FERRITEOS DIRECT RF ACCELERATION")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(FerriteSuiteTheme.neonGreen)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(FerriteSuiteTheme.neonGreen.opacity(0.12))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(FerriteSuiteTheme.neonGreen.opacity(0.35), lineWidth: 1)
                                )
                            }
                        }
                        Text("Synthesize, preview, and transmit Sub-GHz RF waveforms directly to Flipper Zero.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: transmitSignal) {
                        if isSending {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("Transmit RF Now", systemImage: "antenna.radiowaves.left.and.right")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(FerriteSuiteTheme.neonAmber)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
                .padding(20)
                .glassCard()
                
                // Real-time Waveform Canvas
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Digital Waveform Preview")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(frequency * 1_000_000)) Hz • \(pulseCount) Pulses • \(Int(pulseWidth)) µs")
                            .font(.caption.monospaced())
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                    }
                    
                    WaveformCanvas(pulseCount: pulseCount, pulseWidth: pulseWidth)
                        .frame(height: 140)
                        .background(FerriteSuiteTheme.terminalBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                        )
                }
                .padding(20)
                .glassCard()
                
                // Controls
                VStack(alignment: .leading, spacing: 16) {
                    Text("Signal Synthesis Parameters")
                        .font(.headline)
                    
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Carrier Frequency:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $frequency) {
                                ForEach(frequencies, id: \.self) { freq in
                                    Text("\(String(format: "%.2f", freq)) MHz").tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 320)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pulse Count: \(pulseCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: Binding(get: { Double(pulseCount) }, set: { pulseCount = Int($0) }), in: 4...64, step: 2)
                                .frame(maxWidth: 200)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pulse Width: \(Int(pulseWidth)) µs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $pulseWidth, in: 100...2000, step: 50)
                                .frame(maxWidth: 200)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        TextField("Signal File Name", text: $signalName)
                            .font(.subheadline.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)
                        
                        Button(action: saveToSdCard) {
                            Label("Save .sub to SD Card", systemImage: "square.and.arrow.down")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(FerriteSuiteTheme.secondaryCardBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .glassCard()
                
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FerriteSuiteTheme.terminalBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                        )
                }
            }
            .padding(20)
        }
        .background(FerriteSuiteTheme.darkBackground)
    }
    
    private func generateSubFile() -> String {
        let freqHz = Int(frequency * 1_000_000)
        var pulses: [Int] = []
        for _ in 0..<pulseCount {
            pulses.append(Int(pulseWidth))
            pulses.append(-Int(pulseWidth))
        }
        let signal = SubGhzSignal(name: signalName, frequency: freqHz, rawPulses: pulses)
        return signal.toSubFileContent()
    }
    
    private func saveToSdCard() {
        let content = generateSubFile()
        let path = "/ext/subghz/\(signalName).sub"
        statusText = "Saving to \(path)..."
        
        Task {
            let res = await FlipperToolExecutor.shared.execute(action: "write_file", params: ["path": path, "content": content])
            DispatchQueue.main.async {
                self.statusText = res.isError ? "Save error: \(res.output)" : "Successfully saved waveform to \(path)"
            }
        }
    }
    
    private func transmitSignal() {
        isSending = true
        statusText = "Synthesizing and deploying for transmission..."
        
        Task {
            let freqHz = Int(frequency * 1_000_000)
            let widthUs = Int(pulseWidth)
            let count = pulseCount
            
            if connection.isFerriteOS {
                // First-party FerriteOS Direct Zero-Latency RF Acceleration
                let cmd = "subghz tx_raw \(freqHz) \(widthUs) \(count)"
                let out = (try? await connection.executeCommand(cmd)) ?? ""
                let cleanOut = out.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.isSending = false
                    self.statusText = "⚡️ [FerriteOS Native Core] \(cleanOut.isEmpty ? "Sub-GHz RF emitted successfully." : cleanOut)"
                }
            } else {
                // Stock Flipper Legacy Fallback
                let content = generateSubFile()
                let path = "/ext/subghz/\(signalName).sub"
                _ = await FlipperToolExecutor.shared.execute(action: "write_file", params: ["path": path, "content": content])
                let txRes = await FlipperToolExecutor.shared.execute(action: "subghz_transmit", params: ["path": path])
                
                DispatchQueue.main.async {
                    self.isSending = false
                    self.statusText = txRes.isError ? "Transmit error: \(txRes.output)" : "RF Signal Transmitted! Output: \(txRes.output)"
                }
            }
        }
    }
}

private struct WaveformCanvas: View {
    let pulseCount: Int
    let pulseWidth: Double
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h / 2
            let topY = h * 0.25
            let bottomY = h * 0.75
            
            // Draw grid
            var gridPath = Path()
            for x in stride(from: 0, to: w, by: 40) {
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.addLine(to: CGPoint(x: x, y: h))
            }
            gridPath.move(to: CGPoint(x: 0, y: midY))
            gridPath.addLine(to: CGPoint(x: w, y: midY))
            context.stroke(gridPath, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)
            
            // Draw pulses
            var wavePath = Path()
            let totalSteps = pulseCount * 2
            let stepWidth = w / CGFloat(totalSteps)
            
            var currentX: CGFloat = 0
            var isHigh = true
            
            wavePath.move(to: CGPoint(x: 0, y: isHigh ? topY : bottomY))
            
            for _ in 0..<totalSteps {
                let nextX = currentX + stepWidth
                let y = isHigh ? topY : bottomY
                wavePath.addLine(to: CGPoint(x: nextX, y: y))
                
                isHigh.toggle()
                let newY = isHigh ? topY : bottomY
                wavePath.addLine(to: CGPoint(x: nextX, y: newY))
                
                currentX = nextX
            }
            
            context.stroke(wavePath, with: .color(FerriteSuiteTheme.accentCyan), lineWidth: 2)
        }
    }
}
