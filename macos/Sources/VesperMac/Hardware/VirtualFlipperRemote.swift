import Foundation

public enum FlipperKey: String, CaseIterable {
    case up = "up"
    case down = "down"
    case left = "left"
    case right = "right"
    case ok = "ok"
    case back = "back"
}

public enum FlipperInputType: String {
    case press = "press"
    case release = "release"
    case short = "short"
    case long = "long"
}

@MainActor
public final class VirtualFlipperRemote {
    public static let shared = VirtualFlipperRemote()
    private let connectionManager = FlipperConnectionManager.shared
    
    public init() {}
    
    public func sendKey(_ key: FlipperKey, type: FlipperInputType = .short) async throws {
        let cmd = "input send \(key.rawValue) \(type.rawValue)"
        _ = try await connectionManager.executeCommand(cmd)
    }
    
    public func fetchScreenSnapshot() async -> [[Bool]]? {
        // Returns a 128x64 boolean grid (true = pixel on)
        // If Flipper is connected, we can query gui snapshot
        guard connectionManager.status.isConnected else { return nil }
        // Default simulated idle screen or live capture
        return nil
    }
}
