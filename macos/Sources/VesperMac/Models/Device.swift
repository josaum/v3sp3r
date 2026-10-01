import Foundation

public enum TransportType: String, Codable, CaseIterable {
    case usb = "USB Cable"
    case ble = "Bluetooth LE"
    
    public var iconName: String {
        switch self {
        case .usb: return "cable.connector"
        case .ble: return "antenna.radiowaves.left.and.right"
        }
    }
}

public enum ConnectionStatus: Equatable {
    case disconnected
    case scanning
    case connecting(TransportType)
    case connected(TransportType, deviceName: String)
    case error(String)
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .scanning: return "Scanning..."
        case .connecting(let transport): return "Connecting (\(transport.rawValue))..."
        case .connected(let transport, let name): return "\(name) via \(transport.rawValue)"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

public struct FlipperDevice: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let transportType: TransportType
    public let portOrIdentifier: String
    public var rssi: Int?
    
    public init(id: String, name: String, transportType: TransportType, portOrIdentifier: String, rssi: Int? = nil) {
        self.id = id
        self.name = name
        self.transportType = transportType
        self.portOrIdentifier = portOrIdentifier
        self.rssi = rssi
    }
}

public struct FlipperDeviceInfo: Codable, Equatable {
    public var hardwareModel: String = "Flipper Zero"
    public var firmwareVersion: String = "Unknown"
    public var firmwareBranch: String = "Unknown"
    public var firmwareCommit: String = ""
    public var firmwareOrigin: String = ""
    public var radioMode: String = ""
    public var batteryLevel: Int = 0
    public var isCharging: Bool = false
    public var sdCardPresent: Bool = false
    public var sdTotalBytes: Int64 = 0
    public var sdFreeBytes: Int64 = 0
    
    public var isFerriteOS: Bool {
        firmwareVersion.localizedCaseInsensitiveContains("FerriteOS") ||
        firmwareBranch.localizedCaseInsensitiveContains("FerriteOS") ||
        firmwareOrigin.localizedCaseInsensitiveContains("Rust")
    }
    
    public init(
        hardwareModel: String = "Flipper Zero",
        firmwareVersion: String = "Unknown",
        firmwareBranch: String = "Unknown",
        firmwareCommit: String = "",
        firmwareOrigin: String = "",
        radioMode: String = "",
        batteryLevel: Int = 0,
        isCharging: Bool = false,
        sdCardPresent: Bool = false,
        sdTotalBytes: Int64 = 0,
        sdFreeBytes: Int64 = 0
    ) {
        self.hardwareModel = hardwareModel
        self.firmwareVersion = firmwareVersion
        self.firmwareBranch = firmwareBranch
        self.firmwareCommit = firmwareCommit
        self.firmwareOrigin = firmwareOrigin
        self.radioMode = radioMode
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.sdCardPresent = sdCardPresent
        self.sdTotalBytes = sdTotalBytes
        self.sdFreeBytes = sdFreeBytes
    }
}

public struct FileItem: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    
    public init(name: String, path: String, isDirectory: Bool, size: Int64 = 0) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
    }
}
