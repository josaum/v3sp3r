import Foundation
import SwiftUI

public enum FirmwareTargetType: String, Codable, CaseIterable {
    case flipper = "Flipper Zero"
    case gpioBoard = "GPIO & Devboard"
}

public enum FlipperFirmwareDistro: String, Codable, CaseIterable, Identifiable {
    case unleashed = "Unleashed (Recommended)"
    case official = "Official Flipper"
    case momentum = "Momentum (Xtreme)"
    case rogueMaster = "RogueMaster"
    case ferriteOs = "FerriteOS (Bare-Metal)"
    
    public var id: String { rawValue }
    
    public var repoOwner: String {
        switch self {
        case .unleashed: return "DarkFlippers"
        case .official: return "flipperdevices"
        case .momentum: return "Next-Flip"
        case .rogueMaster: return "RogueMaster"
        case .ferriteOs: return "josaum"
        }
    }
    
    public var repoName: String {
        switch self {
        case .unleashed: return "unleashed-firmware"
        case .official: return "flipperzero-firmware"
        case .momentum: return "Momentum-Firmware"
        case .rogueMaster: return "flipperzero-firmware-wPlugins"
        case .ferriteOs: return "FerriteOS"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .unleashed: return VesperTheme.neonGreen
        case .official: return VesperTheme.accentCyan
        case .momentum: return VesperTheme.cyberPurple
        case .rogueMaster: return VesperTheme.neonRed
        case .ferriteOs: return VesperTheme.neonAmber
        }
    }
    
    public var iconName: String {
        switch self {
        case .unleashed: return "flame.fill"
        case .official: return "checkmark.shield.fill"
        case .momentum: return "bolt.fill"
        case .rogueMaster: return "crown.fill"
        case .ferriteOs: return "atom"
        }
    }
    
    public var description: String {
        switch self {
        case .unleashed: return "Unrestricted Sub-GHz transmit, regional bypass, extended rolling codes, and tactical apps."
        case .official: return "Stable, certified standard release from Flipper Devices Inc."
        case .momentum: return "Modern high-speed UI customizations, animations, and modular asset packages."
        case .rogueMaster: return "Expansive community build with hundreds of bundled plugins, games, and payload suites."
        case .ferriteOs: return "Standalone Cortex-M4 bare-metal firmware linked at 0x08000000. Replaces stock bootloader."
        }
    }
}

extension Notification.Name {
    public static let navigateToSection = Notification.Name("ferriteSuiteNavigateToSection")
}

public enum GPIOBoardType: String, Codable, CaseIterable, Identifiable {
    case esp32s2 = "WiFi Devboard (ESP32-S2)"
    case esp32wroom = "ESP32-WROOM / Generic"
    case esp32cam = "ESP32-CAM (Video Feed)"
    case nrf24 = "NRF24L01+ 2.4GHz Transceiver"
    case cc1101 = "CC1101 External Sub-GHz Booster"
    case rp2040 = "Raspberry Pi Pico (RP2040)"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .esp32s2: return "wifi.circle.fill"
        case .esp32wroom: return "cpu"
        case .esp32cam: return "camera.fill"
        case .nrf24: return "antenna.radiowaves.left.and.right"
        case .cc1101: return "waveform.path.ecg"
        case .rp2040: return "memorychip.fill"
        }
    }
    
    public var defaultChip: String {
        switch self {
        case .esp32s2: return "esp32s2"
        case .esp32wroom, .esp32cam: return "esp32"
        case .nrf24, .cc1101, .rp2040: return "raw"
        }
    }
}

public struct FirmwareRelease: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let tagName: String
    public let repoName: String
    public let distro: FlipperFirmwareDistro?
    public let boardType: GPIOBoardType?
    public let publishedAt: Date
    public let changelog: String
    public let downloadUrl: String
    public let assetName: String
    public let fileSize: Int64
    public let targetType: FirmwareTargetType
    public var isInstalled: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        tagName: String,
        repoName: String,
        distro: FlipperFirmwareDistro? = nil,
        boardType: GPIOBoardType? = nil,
        publishedAt: Date = Date(),
        changelog: String = "",
        downloadUrl: String = "",
        assetName: String = "",
        fileSize: Int64 = 0,
        targetType: FirmwareTargetType,
        isInstalled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.tagName = tagName
        self.repoName = repoName
        self.distro = distro
        self.boardType = boardType
        self.publishedAt = publishedAt
        self.changelog = changelog
        self.downloadUrl = downloadUrl
        self.assetName = assetName
        self.fileSize = fileSize
        self.targetType = targetType
        self.isInstalled = isInstalled
    }
}
