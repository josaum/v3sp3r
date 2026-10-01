import Foundation
import SwiftUI

public enum MemoryCategory: String, Codable, CaseIterable {
    case hardware = "Hardware Telemetry"
    case signal = "RF & Signal Observation"
    case securityFinding = "Security & Audit Finding"
    case operatorNote = "Operator Knowledge"
    case ferritePlan = "FerriteOS Plan"
    
    public var iconName: String {
        switch self {
        case .hardware: return "cpu"
        case .signal: return "waveform.path.ecg"
        case .securityFinding: return "shield.checkered"
        case .operatorNote: return "note.text"
        case .ferritePlan: return "gearshape.arrow.triangle.2.circlepath"
        }
    }
    
    public var color: Color {
        switch self {
        case .hardware: return VesperTheme.accentCyan
        case .signal: return VesperTheme.neonAmber
        case .securityFinding: return VesperTheme.neonRed
        case .operatorNote: return VesperTheme.neonGreen
        case .ferritePlan: return VesperTheme.cyberPurple
        }
    }
}

public struct VesperMemory: Identifiable, Codable, Equatable {
    public let id: String
    public var category: MemoryCategory
    public var title: String
    public var content: String
    public var timestamp: Date
    public var isPinned: Bool
    
    public init(
        id: String = UUID().uuidString,
        category: MemoryCategory,
        title: String,
        content: String,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}

@MainActor
@Observable
public final class VesperMemoryStore {
    public static let shared = VesperMemoryStore()
    
    public var memories: [VesperMemory] = []
    private let storageUrl: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vesperDir = appSupport.appendingPathComponent("Vesper", isDirectory: true)
        try? FileManager.default.createDirectory(at: vesperDir, withIntermediateDirectories: true)
        self.storageUrl = vesperDir.appendingPathComponent("memories.json")
        
        load()
        if memories.isEmpty {
            seedInitialMemories()
        }
    }
    
    public func addMemory(category: MemoryCategory, title: String, content: String, isPinned: Bool = false) {
        let memory = VesperMemory(category: category, title: title, content: content, isPinned: isPinned)
        self.memories.insert(memory, at: 0)
        save()
    }
    
    public func deleteMemory(id: String) {
        self.memories.removeAll { $0.id == id }
        save()
    }
    
    public func togglePin(id: String) {
        if let idx = memories.firstIndex(where: { $0.id == id }) {
            memories[idx].isPinned.toggle()
            save()
        }
    }
    
    public func clearAll() {
        self.memories.removeAll()
        save()
    }
    
    public func search(query: String) -> [VesperMemory] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return memories }
        let q = query.lowercased()
        return memories.filter {
            $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q) || $0.category.rawValue.lowercased().contains(q)
        }
    }
    
    public func generateMemoryContextPrompt() -> String {
        guard !memories.isEmpty else { return "" }
        
        // Take pinned memories first, then 8 most recent
        let pinned = memories.filter { $0.isPinned }
        let recent = memories.filter { !$0.isPinned }.prefix(8)
        let selection = (pinned + recent)
        
        var buffer = "\n### PERSISTENT LONG-TERM MEMORY (Observed Hardware & Tactical Knowledge):\n"
        for mem in selection {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let dateStr = df.string(from: mem.timestamp)
            buffer += "- [\(mem.category.rawValue.uppercased()) | \(dateStr)] \(mem.title): \(mem.content)\n"
        }
        return buffer
    }
    
    // Auto-recording hooks
    public func autoRecordDevice(info: FlipperDeviceInfo, port: String) {
        let title = "Connected Hardware: \(info.hardwareModel)"
        let content = "Firmware: \(info.firmwareVersion) (\(info.firmwareBranch)), Commit: \(info.firmwareCommit), Serial Port: \(port), Radio Stack: \(info.radioMode)"
        
        if let idx = memories.firstIndex(where: { $0.title == title }) {
            memories[idx].content = content
            memories[idx].timestamp = Date()
        } else {
            addMemory(category: .hardware, title: title, content: content, isPinned: true)
        }
    }
    
    public func autoRecordSignal(frequency: String, modulation: String, protocolName: String, data: String) {
        let title = "Signal: \(protocolName) @ \(frequency)"
        let content = "Modulation: \(modulation), Decoded payload: \(data)"
        addMemory(category: .signal, title: title, content: content)
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: storageUrl) else { return }
        if let decoded = try? JSONDecoder().decode([VesperMemory].self, from: data) {
            self.memories = decoded
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(memories) {
            try? data.write(to: storageUrl, options: .atomic)
        }
    }
    
    private func seedInitialMemories() {
        addMemory(
            category: .hardware,
            title: "Physical Flipper Profile",
            content: "Primary device: Flipper Zero running Unleashed firmware with frequency limits removed. Connected via USB CDC on macOS.",
            isPinned: true
        )
        addMemory(
            category: .signal,
            title: "Common ISM Garage & Gate Band",
            content: "Standard US gate openers operate at 315.00 MHz and 433.92 MHz with AM650 / AM270 OOK modulation.",
            isPinned: false
        )
        addMemory(
            category: .operatorNote,
            title: "Vesper Mission Directives",
            content: "Always prioritize non-destructive hardware inspection, autonomous risk confirmation, and multi-subgraph execution.",
            isPinned: true
        )
    }
}
