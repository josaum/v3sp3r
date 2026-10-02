import Foundation

public enum SignalProtocolType: String, CaseIterable, Identifiable {
    case subghz = "Sub-GHz RF"
    case infrared = "Infrared (IR)"
    case nfc = "NFC (13.56 MHz)"
    case rfid = "RFID (125 kHz)"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .subghz: return "antenna.radiowaves.left.and.right"
        case .infrared: return "rays"
        case .nfc: return "wave.3.forward"
        case .rfid: return "creditcard"
        }
    }
}

public struct VaultSignal: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: SignalProtocolType
    public let frequencyText: String
    public let protocolName: String
    public let path: String
    public let description: String
    
    public init(id: String = UUID().uuidString, name: String, type: SignalProtocolType, frequencyText: String, protocolName: String, path: String, description: String) {
        self.id = id
        self.name = name
        self.type = type
        self.frequencyText = frequencyText
        self.protocolName = protocolName
        self.path = path
        self.description = description
    }
}

public struct KnownProtocolDef: Identifiable {
    public var id: String { name }
    public let name: String
    public let frequency: String
    public let modulation: String
    public let securityTier: String
    public let description: String
    public let isReplayable: Bool
}
