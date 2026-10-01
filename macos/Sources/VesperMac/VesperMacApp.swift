import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.center()
            }
        }
    }
}

@main
struct VesperMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("V3SP3R — Flipper Zero AI Command Center") {
            MainContentView()
                .frame(minWidth: 950, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            
            // MARK: - Firmware Menu
            CommandMenu("Firmware") {
                Button("Firmware & Flashing Hub") {
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.firmwareHub)
                }
                .keyboardShortcut("F", modifiers: [.command])
                
                Divider()
                
                Button("Check GitHub Firmware Releases...") {
                    Task { @MainActor in
                        await FirmwareFlashService.shared.syncGitHubReleases()
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.firmwareHub)
                    }
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
                
                Menu("Quick Flash Flipper Zero") {
                    Button("Flash Unleashed Firmware (Latest)") {
                        Task { @MainActor in
                            let svc = FirmwareFlashService.shared
                            if let rel = svc.flipperReleases.first(where: { $0.distro == .unleashed }) {
                                try? await svc.flashFlipper(release: rel)
                            }
                        }
                    }
                    Button("Flash Momentum Firmware (Latest)") {
                        Task { @MainActor in
                            let svc = FirmwareFlashService.shared
                            if let rel = svc.flipperReleases.first(where: { $0.distro == .momentum }) {
                                try? await svc.flashFlipper(release: rel)
                            }
                        }
                    }
                    Button("Flash Official Flipper Firmware") {
                        Task { @MainActor in
                            let svc = FirmwareFlashService.shared
                            if let rel = svc.flipperReleases.first(where: { $0.distro == .official }) {
                                try? await svc.flashFlipper(release: rel)
                            }
                        }
                    }
                    Button("Flash RogueMaster Firmware") {
                        Task { @MainActor in
                            let svc = FirmwareFlashService.shared
                            if let rel = svc.flipperReleases.first(where: { $0.distro == .rogueMaster }) {
                                try? await svc.flashFlipper(release: rel)
                            }
                        }
                    }
                    Divider()
                    Button("Flash FerriteOS Bare-Metal (0x08000000)...") {
                        Task { @MainActor in
                            try? await FirmwareFlashService.shared.flashFerriteOsDfu()
                        }
                    }
                }
                
                Menu("GPIO & Devboard Flashing") {
                    Button("Diagnose Devboard UART / Pinout") {
                        Task { @MainActor in
                            _ = await FirmwareFlashService.shared.diagnoseDevboard()
                            NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.firmwareHub)
                        }
                    }
                    Button("Upload & Stage 802.11 Diagnostic Firmware") {
                        Task { @MainActor in
                            let svc = FirmwareFlashService.shared
                            if let rel = svc.gpioReleases.first {
                                try? await svc.uploadGpioFirmwareToFlipper(release: rel)
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Reboot to DFU Bootloader") {
                    Task { @MainActor in
                        _ = try? await FlipperConnectionManager.shared.executeCommand("power reboot2dfu")
                    }
                }
                .keyboardShortcut("D", modifiers: [.command, .option])
                
                Button("Reboot Flipper OS") {
                    Task { @MainActor in
                        _ = try? await FlipperConnectionManager.shared.executeCommand("power reboot")
                    }
                }
                .keyboardShortcut("R", modifiers: [.command, .option])
                
                Button("Power Off Flipper") {
                    Task { @MainActor in
                        _ = try? await FlipperConnectionManager.shared.executeCommand("power off")
                    }
                }
            }
            
            // MARK: - Diagnostics Menu
            CommandMenu("Diagnostics") {
                Button("Run System & Firmware Diagnostics") {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.firmwareHub)
                        _ = await FirmwareFlashService.shared.runComprehensiveDiagnostics()
                    }
                }
                .keyboardShortcut("D", modifiers: [.command])
                
                Button("Hardware Self-Test (Workflow DAG)") {
                    WorkflowEngine.shared.start(workflow: WorkflowEngine.createDiagnosticHealthWorkflow())
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.workflows)
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
                
                Button("Sub-GHz Full Spectrum Recon") {
                    WorkflowEngine.shared.start(workflow: WorkflowEngine.createSubGhzReconWorkflow())
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.workflows)
                }
                
                Button("Access Control & Badge Auditor") {
                    WorkflowEngine.shared.start(workflow: WorkflowEngine.createAccessControlAuditWorkflow())
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.workflows)
                }
                
                Divider()
                
                Button("Probe GPIO Devboard Link (UART)") {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.marauder)
                        _ = await FirmwareFlashService.shared.diagnoseDevboard()
                    }
                }
                
                Button("Scan USB DFU Devices (dfu-util -l)") {
                    Task { @MainActor in
                        _ = await FerriteOSService.shared.scanDfuDevices()
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                    }
                }
                
                Button("Scan SWD Debug Probes (probe-rs)") {
                    Task { @MainActor in
                        _ = await FerriteOSService.shared.scanProbeDevices()
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                    }
                }
                
                Divider()
                
                Button("FerriteOS Pre-Flight Image Check") {
                    Task { @MainActor in
                        _ = await FerriteOSService.shared.runPreflightCheck()
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                    }
                }
                
                Button("FerriteOS 33 Unit Test Suite") {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                        _ = await FerriteOSService.shared.runUnitTests()
                    }
                }
            }
            
            // MARK: - FerriteOS Menu
            CommandMenu("FerriteOS") {
                Button("Open FerriteOS Workbench") {
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])
                
                Button("Natural Language Intent Parser...") {
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                }
                
                Button("Decode Signal File (.sub / .nfc / .rfid)...") {
                    NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                }
                
                Divider()
                
                Button("Run Standalone Image Pre-Flight (check_image.py)") {
                    Task { @MainActor in
                        _ = await FerriteOSService.shared.runPreflightCheck()
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                    }
                }
                
                Button("Run Firmware Test Suite (test_build.py)") {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                        _ = await FerriteOSService.shared.runUnitTests()
                    }
                }
                
                Button("Build Bare-Metal Firmware (build.sh)") {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .navigateToSection, object: NavigationSection.ferriteWorkbench)
                        _ = await FerriteOSService.shared.buildFirmware()
                    }
                }
                
                Divider()
                
                Button("Flash FerriteOS to 0x08000000 via DFU...") {
                    Task { @MainActor in
                        try? await FirmwareFlashService.shared.flashFerriteOsDfu()
                    }
                }
            }
        }
    }
}
