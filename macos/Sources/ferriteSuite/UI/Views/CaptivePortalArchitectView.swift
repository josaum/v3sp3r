import SwiftUI
import WebKit

/// Live interactive WebKit preview for captive portal HTML rendering.
public struct HtmlLivePreview: NSViewRepresentable {
    public let htmlContent: String
    
    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Allow dark background to show through if desired
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

public struct CaptivePortalArchitectView: View {
    @State private var service = CaptivePortalService.shared
    @State private var aiPromptInput: String = ""
    @State private var isMobilePreview: Bool = true
    @State private var deployToast: String?
    @State private var copiedToast: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar HUD
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 28))
                        .foregroundColor(FerriteSuiteTheme.accentCyan)
                        .frame(width: 48, height: 48)
                        .background(FerriteSuiteTheme.accentCyan.opacity(0.12))
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Captive Portal Architect & Compliance Studio")
                            .font(.title3.bold())
                        Text("Design, preview, and stage responsive 802.11 HTML captive landing pages with AI assistance.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 10) {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(service.currentHtml, forType: .string)
                            copiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToast = false }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: copiedToast ? "checkmark" : "doc.on.doc")
                                Text(copiedToast ? "Copied" : "Copy Code")
                            }
                            .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: deployPortal) {
                            HStack(spacing: 6) {
                                if service.isDeploying {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.up.doc.fill")
                                }
                                Text("Deploy to Flipper SD")
                            }
                            .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(service.isDeploying)
                    }
                }
                
                // AI Prompt Guidance Input
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(FerriteSuiteTheme.cyberPurple)
                        TextField("Instruct AI: e.g. 'Redesign for ACME Corp with dark mode, Acceptable Use Policy, and 12-hour session notice'...", text: $aiPromptInput)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .onSubmit { generateWithAi() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FerriteSuiteTheme.cyberPurple.opacity(0.5), lineWidth: 1)
                    )
                    
                    Button(action: generateWithAi) {
                        HStack(spacing: 6) {
                            if service.isGenerating {
                                ProgressView().controlSize(.small)
                                Text("Designing...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("Design with AI")
                            }
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FerriteSuiteTheme.cyberPurple)
                    .disabled(service.isGenerating || aiPromptInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                // Status / Toast Banner
                if let status = deployToast ?? service.lastStatus {
                    HStack {
                        Image(systemName: status.contains("✅") ? "checkmark.circle.fill" : "info.circle.fill")
                            .foregroundColor(status.contains("✅") ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.accentCyan)
                        Text(status)
                            .font(.caption.monospaced())
                            .foregroundColor(status.contains("✅") ? FerriteSuiteTheme.neonGreen : FerriteSuiteTheme.accentCyan)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
                }
            }
            .padding(16)
            .glassCard()
            .padding([.horizontal, .top], 16)
            
            // Template Quick Selector Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Text("Templates:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach(service.templates) { template in
                        Button(action: { service.selectTemplate(template) }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(service.selectedTemplate.id == template.id ? FerriteSuiteTheme.accentCyan : Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text(template.title)
                                    .font(.caption)
                                    .fontWeight(service.selectedTemplate.id == template.id ? .bold : .regular)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(service.selectedTemplate.id == template.id ? FerriteSuiteTheme.accentCyan.opacity(0.18) : FerriteSuiteTheme.secondaryCardBackground)
                            .foregroundColor(service.selectedTemplate.id == template.id ? FerriteSuiteTheme.accentCyan : .secondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(service.selectedTemplate.id == template.id ? FerriteSuiteTheme.accentCyan.opacity(0.6) : FerriteSuiteTheme.subtleBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            
            Divider().background(FerriteSuiteTheme.subtleBorder)
            
            // Split-Pane Workspace: Left Code Editor, Right Live Preview
            HSplitView {
                // Left: HTML/CSS Source Code Editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "curlybraces")
                            .foregroundColor(FerriteSuiteTheme.accentCyan)
                        Text("index.html Source")
                            .font(.caption.bold())
                        
                        Spacer()
                        
                        Text("\(service.currentHtml.count) bytes")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    TextEditor(text: $service.currentHtml)
                        .font(.system(.caption, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(FerriteSuiteTheme.terminalBackground)
                        .cornerRadius(8)
                        .padding([.horizontal, .bottom], 10)
                }
                .frame(minWidth: 320)
                .background(FerriteSuiteTheme.darkBackground)
                
                // Right: Interactive Live Rendering Preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "safari.fill")
                            .foregroundColor(FerriteSuiteTheme.neonGreen)
                        Text("Live Portal Preview")
                            .font(.caption.bold())
                        
                        Spacer()
                        
                        // Device View Toggle
                        HStack(spacing: 4) {
                            Button(action: { isMobilePreview = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "iphone")
                                    Text("Mobile")
                                }
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isMobilePreview ? FerriteSuiteTheme.neonGreen.opacity(0.2) : Color.clear)
                                .foregroundColor(isMobilePreview ? FerriteSuiteTheme.neonGreen : .secondary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { isMobilePreview = false }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "macbook")
                                    Text("Desktop")
                                }
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(!isMobilePreview ? FerriteSuiteTheme.neonGreen.opacity(0.2) : Color.clear)
                                .foregroundColor(!isMobilePreview ? FerriteSuiteTheme.neonGreen : .secondary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(FerriteSuiteTheme.secondaryCardBackground)
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    // Render Container
                    ZStack {
                        Color(red: 0.05, green: 0.07, blue: 0.1)
                        
                        if isMobilePreview {
                            // Centered Smartphone Mockup Frame
                            VStack(spacing: 0) {
                                // Phone speaker bar
                                Capsule()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 48, height: 4)
                                    .padding(.vertical, 6)
                                
                                HtmlLivePreview(htmlContent: service.currentHtml)
                                    .cornerRadius(12)
                            }
                            .padding(8)
                            .frame(width: 375, height: 620)
                            .background(Color.black)
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.7), radius: 20)
                            .padding(.vertical, 16)
                        } else {
                            // Fluid Full Desktop Canvas
                            HtmlLivePreview(htmlContent: service.currentHtml)
                                .cornerRadius(8)
                                .padding(10)
                        }
                    }
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom], 10)
                }
                .frame(minWidth: 380)
                .background(FerriteSuiteTheme.darkBackground)
            }
        }
        .background(FerriteSuiteTheme.darkBackground)
    }
    
    private func generateWithAi() {
        let prompt = aiPromptInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        Task {
            do {
                _ = try await service.generatePortalWithAi(prompt: prompt)
                aiPromptInput = ""
            } catch {
                service.lastError = error.localizedDescription
                service.lastStatus = "AI Generation error: \(error.localizedDescription)"
            }
        }
    }
    
    private func deployPortal() {
        Task {
            do {
                let msg = try await service.deployPortalToFlipper(html: service.currentHtml)
                deployToast = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    deployToast = nil
                }
            } catch {
                deployToast = "Deployment Failed: \(error.localizedDescription)"
            }
        }
    }
}
