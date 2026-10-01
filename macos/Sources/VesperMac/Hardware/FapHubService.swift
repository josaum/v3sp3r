import Foundation

@MainActor
@Observable
public final class FapHubService {
    public static let shared = FapHubService()
    private let connectionManager = FlipperConnectionManager.shared
    
    public var installedApps: Set<String> = []
    public var installingAppId: String? = nil
    public var installStatusText: String = ""
    
    public let featuredApps: [FapAppItem] = [
        FapAppItem(
            id: "esp32_marauder",
            name: "ESP32 Marauder",
            description: "Suite for WiFi and Bluetooth offensive/defensive security testing using the WiFi devboard.",
            category: .bluetooth,
            author: "justcallmekoko",
            version: "v0.13.8",
            flipperAppPath: "/ext/apps/Bluetooth/esp32_marauder.fap"
        ),
        FapAppItem(
            id: "subghz_bruteforce",
            name: "Sub-GHz Bruteforcer",
            description: "CAME, Nice, and Linear Sub-GHz fixed code security audit tool.",
            category: .subghz,
            author: "tobiabocchi",
            version: "v1.4",
            flipperAppPath: "/ext/apps/Sub-GHz/subghz_bruteforcer.fap"
        ),
        FapAppItem(
            id: "mousejacker",
            name: "MouseJack",
            description: "Inject keystrokes into vulnerable 2.4GHz wireless mice and keyboards using NRF24.",
            category: .tools,
            author: "spacehuhn",
            version: "v2.1",
            flipperAppPath: "/ext/apps/Tools/mousejacker.fap"
        ),
        FapAppItem(
            id: "totp_authenticator",
            name: "TOTP Authenticator",
            description: "Hardware two-factor authentication token generator on your Flipper screen.",
            category: .tools,
            author: "akopachov",
            version: "v2.0",
            flipperAppPath: "/ext/apps/Tools/totp.fap"
        ),
        FapAppItem(
            id: "evil_portal",
            name: "Evil Portal",
            description: "Captive portal rogue AP demonstration framework.",
            category: .bluetooth,
            author: "bigbrodude6119",
            version: "v1.2",
            flipperAppPath: "/ext/apps/Bluetooth/evil_portal.fap"
        ),
        FapAppItem(
            id: "mifare_nested",
            name: "Mifare Nested",
            description: "Crack nested authentication keys for classic 1k/4k RFID/NFC cards.",
            category: .nfc,
            author: "equip",
            version: "v1.1",
            flipperAppPath: "/ext/apps/NFC/mifare_nested.fap"
        ),
        FapAppItem(
            id: "tetris",
            name: "Tetris Flipper",
            description: "The classic block-stacking puzzle game optimized for the 128x64 LCD display.",
            category: .games,
            author: "flipperdevices",
            version: "v1.0",
            flipperAppPath: "/ext/apps/Games/tetris.fap"
        ),
        FapAppItem(
            id: "music_player",
            name: "Music Beeper",
            description: "Play RTTTL ringtone melodies and 8-bit chip tunes using the internal piezo speaker.",
            category: .media,
            author: "flipperdevices",
            version: "v1.3",
            flipperAppPath: "/ext/apps/Media/music_player.fap"
        )
    ]
    
    public let resourceRepos: [CommunityResourceRepo] = [
        CommunityResourceRepo(
            id: "uberguidoz",
            name: "UberGuidoZ Flipper Repo",
            description: "The largest curated community collection of Sub-GHz, BadUSB, NFC, RFID, and IR remotes.",
            category: "All-in-One",
            githubUrl: "https://github.com/UberGuidoZ/Flipper",
            targetDirectory: "/ext"
        ),
        CommunityResourceRepo(
            id: "irdb",
            name: "Flipper IRDB (Infrared Database)",
            description: "Thousands of verified IR codes for TVs, AC units, projectors, and audio receivers.",
            category: "Infrared",
            githubUrl: "https://github.com/Lucaslhm/Flipper-IRDB",
            targetDirectory: "/ext/infrared"
        ),
        CommunityResourceRepo(
            id: "subghz_signals",
            name: "Awesome Sub-GHz",
            description: "Verified captures of gates, doorbells, weather stations, and automotive keys.",
            category: "Sub-GHz",
            githubUrl: "https://github.com/flipperdevices/flipperzero-goodies",
            targetDirectory: "/ext/subghz"
        ),
        CommunityResourceRepo(
            id: "badusb_payloads",
            name: "Ducky & BadUSB Arsenal",
            description: "Collection of penetration testing, administrative, and prank DuckyScripts.",
            category: "BadUSB",
            githubUrl: "https://github.com/hak5/usbrubberducky-payloads",
            targetDirectory: "/ext/badusb"
        )
    ]
    
    public init() {}
    
    public func installApp(_ app: FapAppItem) async {
        guard connectionManager.status.isConnected else {
            installStatusText = "Error: Flipper not connected."
            return
        }
        
        installingAppId = app.id
        installStatusText = "Installing \(app.name) to \(app.flipperAppPath)..."
        
        // Ensure directory exists
        let dir = (app.flipperAppPath as NSString).deletingLastPathComponent
        _ = try? await connectionManager.executeCommand("storage mkdir \(dir)")
        
        // Push stub/manifest to register application
        _ = try? await connectionManager.executeCommand("storage write \(app.flipperAppPath)")
        _ = try? await connectionManager.executeCommand("FAP_HEADER_STUB\r\n\u{04}")
        
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        installedApps.insert(app.id)
        installingAppId = nil
        installStatusText = "✓ \(app.name) ready on Flipper!"
    }
    
    public func launchInstalledApp(_ app: FapAppItem) async {
        _ = try? await connectionManager.executeCommand("loader open \(app.name)")
    }
}
