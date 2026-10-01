import Foundation

public struct BadUsbScript: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public var script: String
    public let description: String
    public let targetOs: String
    
    public init(name: String, script: String, description: String, targetOs: String = "Windows/macOS") {
        self.name = name
        self.script = script
        self.description = description
        self.targetOs = targetOs
    }
}

public struct SubGhzSignal: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public var frequency: Int
    public var preset: String
    public var protocolName: String
    public var rawPulses: [Int]
    
    public init(name: String, frequency: Int = 433920000, preset: String = "FuriHalSubGhzPreset2FSKDev238Async", protocolName: String = "RAW", rawPulses: [Int] = []) {
        self.name = name
        self.frequency = frequency
        self.preset = preset
        self.protocolName = protocolName
        self.rawPulses = rawPulses
    }
    
    public func toSubFileContent() -> String {
        var content = """
        Filetype: Flipper SubGhz RAW File
        Version: 1
        Frequency: \(frequency)
        Preset: \(preset)
        Protocol: \(protocolName)
        
        """
        if !rawPulses.isEmpty {
            let chunked = stride(from: 0, to: rawPulses.count, by: 512).map {
                Array(rawPulses[$0..<min($0 + 512, rawPulses.count)])
            }
            for chunk in chunked {
                let line = chunk.map { "\($0)" }.joined(separator: " ")
                content += "RAW_Data: \(line)\n"
            }
        }
        return content
    }
}
