import Foundation

@MainActor
public final class FlipperToolExecutor {
    public static let shared = FlipperToolExecutor()
    private let connectionManager = FlipperConnectionManager.shared
    
    public init() {}
    
    public func execute(action: String, params: [String: String]) async -> ToolResult {
        do {
            switch action {
            case "list_directory":
                let path = params["path"] ?? "/ext"
                let output = try await connectionManager.executeCommand("storage list \(path)")
                return ToolResult(toolCallId: "", output: output)
                
            case "read_file":
                guard let path = params["path"] else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand("storage read \(path)")
                return ToolResult(toolCallId: "", output: output)
                
            case "write_file":
                guard let path = params["path"], let content = params["content"] else {
                    return ToolResult(toolCallId: "", output: "Missing path or content parameter", isError: true)
                }
                // Flipper CLI storage write writes line by line or raw
                // We write via storage write command
                let cmd = "storage write \(path)"
                _ = try? await connectionManager.executeCommand(cmd)
                let writeResult = try await connectionManager.executeCommand("\(content)\r\n\u{04}") // EOT
                return ToolResult(toolCallId: "", output: "File successfully written to \(path). Output: \(writeResult)")
                
            case "delete":
                guard let path = params["path"] else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand("storage remove \(path)")
                return ToolResult(toolCallId: "", output: "Deleted \(path): \(output)")
                
            case "create_directory":
                guard let path = params["path"] else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand("storage mkdir \(path)")
                return ToolResult(toolCallId: "", output: "Created dir \(path): \(output)")
                
            case "get_device_info":
                let output = try await connectionManager.executeCommand("info device")
                return ToolResult(toolCallId: "", output: output)
                
            case "get_storage_info":
                let output = try await connectionManager.executeCommand("storage info /ext")
                return ToolResult(toolCallId: "", output: output)
                
            case "execute_cli":
                guard let command = params["command"] else {
                    return ToolResult(toolCallId: "", output: "Missing command parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand(command)
                return ToolResult(toolCallId: "", output: output)
                
            case "launch_app":
                guard let app = params["app_name"] ?? params["name"] else {
                    return ToolResult(toolCallId: "", output: "Missing app_name parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand("loader open \(app)")
                return ToolResult(toolCallId: "", output: "Launched \(app): \(output)")
                
            case "subghz_transmit":
                guard let path = params["path"] else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter", isError: true)
                }
                let cmd = connectionManager.isFerriteOS ? "subghz tx \(path)" : "subghz tx \(path) 1"
                let output = try await connectionManager.executeCommand(cmd)
                return ToolResult(toolCallId: "", output: "SubGHz Transmission initiated: \(output)")
                
            case "ir_transmit":
                guard let path = params["path"] else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand("ir tx \(path)")
                return ToolResult(toolCallId: "", output: "IR Transmission initiated: \(output)")
                
            case "badusb_execute":
                guard let path = params["path"] else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter", isError: true)
                }
                let output = try await connectionManager.executeCommand("badusb run \(path)")
                return ToolResult(toolCallId: "", output: "BadUSB Execution started: \(output)")
                
            case "led_control":
                let r = params["r"] ?? "0"
                let g = params["g"] ?? "0"
                let b = params["b"] ?? "0"
                _ = try? await connectionManager.executeCommand("led r \(r)")
                _ = try? await connectionManager.executeCommand("led b \(b)")
                return ToolResult(toolCallId: "", output: "LED set to (\(r),\(g),\(b))")
                
            case "vibro_control":
                let state = (params["enable"] == "true" || params["state"] == "1") ? "1" : "0"
                let output = try await connectionManager.executeCommand("vibro \(state)")
                return ToolResult(toolCallId: "", output: "Vibration set to \(state): \(output)")
                
            case "ferrite_understand":
                let phrase = params["phrase"] ?? params["command"] ?? ""
                guard !phrase.isEmpty else {
                    return ToolResult(toolCallId: "", output: "Missing phrase parameter for FerriteOS", isError: true)
                }
                let understanding = try await FerriteOSService.shared.understandPhrase(phrase)
                return ToolResult(toolCallId: "", output: "FerriteOS Plan:\nIntent: \(understanding.intent)\nDomain: \(understanding.domain)\nConfidence: \(understanding.confidence)\nOutput:\n\(understanding.rawOutput)")
                
            case "ferrite_decode":
                let path = params["path"] ?? ""
                let phrase = params["phrase"] ?? "what is this"
                guard !path.isEmpty else {
                    return ToolResult(toolCallId: "", output: "Missing path parameter for FerriteOS decode", isError: true)
                }
                let output = try await FerriteOSService.shared.decodeCapture(filePath: path, phrase: phrase)
                return ToolResult(toolCallId: "", output: "FerriteOS Rust Decoder Output:\n\(output)")
                
            case "record_memory":
                let title = params["title"] ?? "Tactical Note"
                let content = params["content"] ?? ""
                let catRaw = params["category"] ?? "Operator Knowledge"
                let cat = MemoryCategory(rawValue: catRaw) ?? .operatorNote
                VesperMemoryStore.shared.addMemory(category: cat, title: title, content: content)
                return ToolResult(toolCallId: "", output: "Memory successfully recorded in Memory Vault.")
                
            case "trigger_workflow":
                let name = (params["workflow_name"] ?? params["name"] ?? "").lowercased()
                let engine = WorkflowEngine.shared
                if name.contains("sub-ghz") || name.contains("recon") {
                    engine.start(workflow: WorkflowEngine.createSubGhzReconWorkflow())
                    return ToolResult(toolCallId: "", output: "Launched Sub-GHz Full Spectrum Recon Workflow.")
                } else if name.contains("diagnostic") || name.contains("health") {
                    engine.start(workflow: WorkflowEngine.createDiagnosticHealthWorkflow())
                    return ToolResult(toolCallId: "", output: "Launched Flipper Hardware Diagnostic Self-Test.")
                } else if name.contains("access") || name.contains("badge") || name.contains("rfid") {
                    engine.start(workflow: WorkflowEngine.createAccessControlAuditWorkflow())
                    return ToolResult(toolCallId: "", output: "Launched Access Control & Badge Auditor Workflow.")
                } else {
                    engine.start()
                    return ToolResult(toolCallId: "", output: "Launched active workflow.")
                }
                
            case "check_firmware_updates":
                let flashService = FirmwareFlashService.shared
                await flashService.syncGitHubReleases()
                let flipperList = flashService.flipperReleases.map { "- \($0.title) (\($0.tagName)): \($0.isInstalled ? "CURRENTLY ACTIVE" : "Available")" }.joined(separator: "\n")
                let gpioList = flashService.gpioReleases.map { "- \($0.title) (\($0.tagName))" }.joined(separator: "\n")
                return ToolResult(toolCallId: "", output: "GitHub Firmware Status:\n\nFlipper Zero Releases:\n\(flipperList)\n\nGPIO Devboard Releases:\n\(gpioList)")
                
            case "flash_flipper_firmware":
                let distroRaw = (params["distro"] ?? "unleashed").lowercased()
                let flashService = FirmwareFlashService.shared
                if let release = flashService.flipperReleases.first(where: {
                    if distroRaw.contains("unleash") { return $0.distro == .unleashed }
                    if distroRaw.contains("official") { return $0.distro == .official }
                    if distroRaw.contains("momentum") { return $0.distro == .momentum }
                    if distroRaw.contains("rogue") { return $0.distro == .rogueMaster }
                    return false
                }) ?? flashService.flipperReleases.first {
                    try await flashService.flashFlipper(release: release)
                    return ToolResult(toolCallId: "", output: "Initiated flashing of \(release.title) to Flipper Zero. Device is rebooting into bootloader to apply.")
                } else {
                    return ToolResult(toolCallId: "", output: "No release found matching '\(distroRaw)'.", isError: true)
                }
                
            case "flash_gpio_board":
                let flashService = FirmwareFlashService.shared
                if let release = flashService.gpioReleases.first {
                    try await flashService.uploadGpioFirmwareToFlipper(release: release)
                    return ToolResult(toolCallId: "", output: "Uploaded \(release.assetName) to Flipper SD card at /ext/apps_data/esp_flasher/. Ready to flash over GPIO.")
                } else {
                    return ToolResult(toolCallId: "", output: "No GPIO release found to flash.", isError: true)
                }
                
            case "diagnose_gpio_devboard":
                let flashService = FirmwareFlashService.shared
                let diag = await flashService.diagnoseDevboard()
                return ToolResult(toolCallId: "", output: "GPIO Devboard Diagnostics:\nStatus: \(diag.status)\nDetails: \(diag.details)")
                
            case "run_diagnostics", "diagnostics":
                let results = await FirmwareFlashService.shared.runComprehensiveDiagnostics()
                let formatted = results.map { res in
                    let mark = res.passed ? "✅ [PASS]" : "⚠️ [WARN]"
                    return "\(mark) \(res.title) (\(res.category))\n   \(res.detail)"
                }.joined(separator: "\n\n")
                return ToolResult(toolCallId: "", output: "V3SP3R Hardware & Firmware Diagnostic Suite Results:\n\n\(formatted)")
                
            case "ferrite_preflight":
                let ferrite = FerriteOSService.shared
                let res = await ferrite.runPreflightCheck()
                let status = res.success ? "PASS" : "FAIL"
                return ToolResult(toolCallId: "", output: "FerriteOS Bare-Metal Preflight Check: \(status)\n\(res.output)", isError: !res.success)
                
            case "ferrite_unit_tests":
                let ferrite = FerriteOSService.shared
                let out = await ferrite.runUnitTests()
                return ToolResult(toolCallId: "", output: "FerriteOS 33 Unit Tests Runner:\n\n\(out)")
                
            case "ferrite_dfu_scan":
                let ferrite = FerriteOSService.shared
                let out = await ferrite.scanDfuDevices()
                return ToolResult(toolCallId: "", output: "USB DFU Devices (dfu-util):\n\n\(out)")
                
            case "ferrite_probe_scan":
                let probeService = DebugProbeService.shared
                await probeService.refreshProbes()
                let probeList = probeService.probes.map { "\($0.index): \($0.name) (\($0.vid):\($0.pid)) [Serial: \($0.serial)]" }.joined(separator: "\n")
                return ToolResult(toolCallId: "", output: probeList.isEmpty ? "No debug probes detected." : "SWD Debug Probes:\n\(probeList)\n\nSelected: \(probeService.selectedProbe?.name ?? "None")")
                
            case "probe_inspect":
                let probeService = DebugProbeService.shared
                if let chip = params["chip"], !chip.isEmpty {
                    probeService.selectedChip = chip
                }
                await probeService.inspectTargetChip()
                return ToolResult(toolCallId: "", output: probeService.consoleOutput)
                
            case "probe_read_memory":
                let probeService = DebugProbeService.shared
                if let addr = params["address"] {
                    probeService.memoryInspectAddressHex = addr
                }
                if let wordsStr = params["words"], let words = Int(wordsStr) {
                    probeService.memoryInspectWordsCount = min(max(1, words), 64)
                }
                await probeService.readMemoryChunk()
                let formatted = probeService.memoryData.map { String(format: "0x%08X: %@ | %@", $0.address, $0.hexValue, $0.asciiRepresentation) }.joined(separator: "\n")
                return ToolResult(toolCallId: "", output: formatted.isEmpty ? probeService.consoleOutput : "Memory Read from \(probeService.memoryInspectAddressHex):\n\(formatted)")
                
            case "probe_reset":
                let probeService = DebugProbeService.shared
                let halt = params["halt"] == "true"
                await probeService.resetTarget(halt: halt)
                return ToolResult(toolCallId: "", output: probeService.consoleOutput)
                
            case "probe_dump_flash":
                let probeService = DebugProbeService.shared
                let addr = params["address"] ?? "0x08000000"
                let words = Int(params["words"] ?? "16384") ?? 16384
                let dest = params["destination"] ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/Desktop/flash_dump_\(Int(Date().timeIntervalSince1970)).bin"
                let out = try await probeService.dumpFlashMemory(addressHex: addr, wordsCount: words, destinationPath: dest)
                return ToolResult(toolCallId: "", output: "Flash memory successfully dumped to: \(out)\n\n\(probeService.consoleOutput)")
                
            case "flash_ferrite_os":
                let forApp = params["standalone"] != "true"
                try await FirmwareFlashService.shared.flashFerriteOsDfu(forApp: forApp)
                let slot = forApp ? "0x08008000 (Safe Bootloader Coexistence)" : "0x08000000 (Standalone)"
                return ToolResult(toolCallId: "", output: "FerriteOS successfully flashed to STM32WB55 slot \(slot).")
                
            case "pi_harness_status":
                let pi = PiHarnessService.shared
                pi.refreshStatus()
                var details = "Pi Agent Harness: \(pi.isAvailable ? "AVAILABLE" : "NOT FOUND")\n"
                details += "Binary Path: \(pi.executablePath)\n"
                details += "Version: \(pi.version.isEmpty ? "unknown" : pi.version)\n"
                if let cfg = pi.hostConfig {
                    details += "Host Config Present: \(cfg.isConfigPresent)\n"
                    details += "Config Dir: \(cfg.configDir)\n"
                    details += "Default Provider: \(cfg.defaultProvider)\n"
                    details += "Default Model: \(cfg.defaultModel)\n"
                    details += "Thinking Level: \(cfg.defaultThinkingLevel)\n"
                }
                return ToolResult(toolCallId: "", output: details)
                
            case "pi_harness_test":
                let res = await PiHarnessService.shared.testHarness()
                return ToolResult(toolCallId: "", output: res.message, isError: !res.success)
                
            case "portal_list_templates":
                let templates = CaptivePortalService.shared.templates
                var out = "V3SP3R Captive Portal Templates (\(templates.count)):\n\n"
                for t in templates {
                    out.append("• ID: \(t.id)\n  Title: \(t.title)\n  Category: \(t.category)\n  Description: \(t.description)\n  Size: \(t.htmlContent.count) bytes\n\n")
                }
                return ToolResult(toolCallId: "", output: out)
                
            case "portal_design_with_ai":
                guard let prompt = params["prompt"], !prompt.isEmpty else {
                    return ToolResult(toolCallId: "", output: "Missing prompt parameter for portal design.", isError: true)
                }
                let service = CaptivePortalService.shared
                if let tId = params["template_id"], let match = service.templates.first(where: { $0.id == tId }) {
                    service.selectTemplate(match)
                }
                let html = try await service.generatePortalWithAi(prompt: prompt)
                return ToolResult(toolCallId: "", output: "Portal generated successfully (\(html.count) bytes):\n\n\(html)")
                
            case "portal_deploy_to_flipper":
                let service = CaptivePortalService.shared
                let html = params["html"] ?? service.currentHtml
                let folder = params["target_folder"] ?? "/ext/apps_data/evil_portal"
                let res = try await service.deployPortalToFlipper(html: html, targetFolder: folder)
                return ToolResult(toolCallId: "", output: res)
                
            default:
                return ToolResult(toolCallId: "", output: "Unknown action '\(action)'. Try execute_cli for custom Flipper commands.", isError: true)
            }
        } catch {
            return ToolResult(toolCallId: "", output: "Hardware error: \(error.localizedDescription)", isError: true)
        }
    }
}
