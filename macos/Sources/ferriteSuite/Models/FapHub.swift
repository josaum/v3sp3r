import Foundation

public enum FapCategory: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case subghz = "Sub-GHz"
    case nfc = "NFC"
    case rfid = "RFID"
    case infrared = "Infrared"
    case bluetooth = "Bluetooth"
    case tools = "Tools"
    case games = "Games"
    case gpio = "GPIO"
    case media = "Media"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .subghz: return "antenna.radiowaves.left.and.right"
        case .nfc: return "wave.3.forward"
        case .rfid: return "creditcard"
        case .infrared: return "rays"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .tools: return "hammer"
        case .games: return "gamecontroller"
        case .gpio: return "bolt.fill"
        case .media: return "music.note"
        }
    }
}

public struct FapAppItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let category: FapCategory
    public let author: String
    public let version: String
    public let flipperAppPath: String
    public var isInstalled: Bool = false
    
    public init(id: String, name: String, description: String, category: FapCategory, author: String, version: String, flipperAppPath: String) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.author = author
        self.version = version
        self.flipperAppPath = flipperAppPath
    }
}

public struct CommunityResourceRepo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let category: String
    public let githubUrl: String
    public let targetDirectory: String
    
    public init(id: String, name: String, description: String, category: String, githubUrl: String, targetDirectory: String) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.githubUrl = githubUrl
        self.targetDirectory = targetDirectory
    }
}
