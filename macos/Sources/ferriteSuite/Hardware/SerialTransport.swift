import Foundation
import Darwin

public final class SerialTransport: @unchecked Sendable, FlipperTransport {
    public weak var delegate: (any FlipperTransportDelegate)?
    public let transportType: TransportType = .usb
    
    private(set) public var isConnected: Bool = false
    private var fileDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let readQueue = DispatchQueue(label: "com.vesper.flipper.serial.read", qos: .userInitiated)
    private let writeQueue = DispatchQueue(label: "com.vesper.flipper.serial.write", qos: .userInitiated)
    
    private var incomingBuffer = ""
    private struct PendingCommand {
        let id: UUID
        let continuation: CheckedContinuation<String, Error>
    }
    private var pendingCommands: [PendingCommand] = []
    private let stateLock = NSLock()
    
    public let portPath: String
    public let baudRate: speed_t
    
    public init(portPath: String, baudRate: Int = 230400) {
        self.portPath = portPath
        switch baudRate {
        case 115200: self.baudRate = speed_t(B115200)
        case 230400: self.baudRate = speed_t(B230400)
        default: self.baudRate = speed_t(B230400)
        }
    }
    
    public static func findFlipperPorts() -> [String] {
        let devPath = "/dev"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: devPath) else {
            return []
        }
        return files
            .filter { $0.hasPrefix("cu.usbmodem") }
            .map { "\(devPath)/\($0)" }
    }
    
    public func connect() async throws {
        guard !isConnected else { return }
        
        let fd = open(portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            let err = String(cString: strerror(errno))
            throw NSError(domain: "SerialTransport", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to open port \(portPath): \(err)"])
        }
        
        var options = termios()
        if tcgetattr(fd, &options) != 0 {
            close(fd)
            throw NSError(domain: "SerialTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get termios attributes"])
        }
        
        cfmakeraw(&options)
        cfsetspeed(&options, baudRate)
        options.c_cflag |= tcflag_t(CLOCAL | CREAD | CS8)
        options.c_cflag &= ~tcflag_t(PARENB | CSTOPB)
        
        #if os(macOS)
        options.c_cflag &= ~tcflag_t(CRTS_IFLOW | CCTS_OFLOW)
        #endif
        
        options.c_cc.16 = 0 // VMIN
        options.c_cc.17 = 1 // VTIME (100ms)
        
        if tcsetattr(fd, TCSANOW, &options) != 0 {
            close(fd)
            throw NSError(domain: "SerialTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to set termios attributes"])
        }
        
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        
        self.fileDescriptor = fd
        self.isConnected = true
        
        setupReadSource()
        
        // Wake up CLI by sending newline
        _ = try? await sendRaw(data: Data([0x0D, 0x0A]))
        
        // Wait briefly for initial banner to stream in and clear incoming buffer
        try? await Task.sleep(nanoseconds: 600_000_000)
        clearIncomingBuffer()
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transportDidConnect(self)
        }
    }
    
    private func clearIncomingBuffer() {
        stateLock.lock()
        incomingBuffer = ""
        stateLock.unlock()
    }
    
    private func setupReadSource() {
        let source = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: readQueue)
        source.setEventHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(self.fileDescriptor, &buffer, buffer.count)
            
            if bytesRead > 0 {
                let data = Data(buffer[0..<bytesRead])
                self.handleIncomingData(data)
            } else if bytesRead < 0 && errno != EAGAIN {
                self.handleDisconnect(error: NSError(domain: "SerialTransport", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Read error: \(errno)"]))
            }
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        
        self.readSource = source
        source.resume()
    }
    
    private func handleIncomingData(_ data: Data) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transport(self, didReceiveRawData: data)
        }
        
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return }
        
        stateLock.lock()
        incomingBuffer.append(text)
        
        let cleaned = incomingBuffer.replacingOccurrences(of: "\r", with: "")
        let noAnsi = cleaned.replacingOccurrences(of: #"\x1B\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression)
        let trimmed = noAnsi.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPrompt = noAnsi.hasSuffix(">: ") ||
                        noAnsi.hasSuffix(">:") ||
                        noAnsi.contains("\n>: ") ||
                        noAnsi.contains("\n>:") ||
                        trimmed.hasSuffix(">:") ||
                        trimmed.hasSuffix(">")
        
        if hasPrompt && !pendingCommands.isEmpty {
            let output = incomingBuffer
            incomingBuffer = ""
            let cmd = pendingCommands.removeFirst()
            stateLock.unlock()
            cmd.continuation.resume(returning: output)
            return
        }
        stateLock.unlock()
        
        let lines = text.components(separatedBy: "\n")
        for line in lines where !line.isEmpty {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.delegate?.transport(self, didReceiveLine: line)
            }
        }
    }
    
    public func send(command: String) async throws -> String {
        guard isConnected, fileDescriptor >= 0 else {
            throw NSError(domain: "SerialTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Serial not connected"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let reqId = UUID()
            let cmdItem = PendingCommand(id: reqId, continuation: continuation)
            
            stateLock.lock()
            incomingBuffer = ""
            pendingCommands.append(cmdItem)
            stateLock.unlock()
            
            writeQueue.async { [weak self] in
                guard let self = self, self.fileDescriptor >= 0 else {
                    self?.stateLock.lock()
                    if let idx = self?.pendingCommands.firstIndex(where: { $0.id == reqId }) {
                        self?.pendingCommands.remove(at: idx)
                    }
                    self?.stateLock.unlock()
                    continuation.resume(throwing: NSError(domain: "SerialTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Disconnected"]))
                    return
                }
                let cmdString = command.trimmingCharacters(in: .whitespacesAndNewlines) + "\r\n"
                guard let data = cmdString.data(using: .utf8) else { return }
                
                data.withUnsafeBytes { ptr in
                    _ = write(self.fileDescriptor, ptr.baseAddress, data.count)
                }
                tcdrain(self.fileDescriptor)
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self else { return }
                self.stateLock.lock()
                if let idx = self.pendingCommands.firstIndex(where: { $0.id == reqId }) {
                    let item = self.pendingCommands.remove(at: idx)
                    self.stateLock.unlock()
                    item.continuation.resume(throwing: NSError(domain: "SerialTransport", code: -2, userInfo: [NSLocalizedDescriptionKey: "Command timed out"]))
                } else {
                    self.stateLock.unlock()
                }
            }
        }
    }
    
    public func sendRaw(data: Data) async throws {
        guard isConnected, fileDescriptor >= 0 else { return }
        writeQueue.async { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            data.withUnsafeBytes { ptr in
                _ = write(self.fileDescriptor, ptr.baseAddress, data.count)
            }
        }
    }
    
    private func cancelPendingCommands(error: Error? = nil) {
        stateLock.lock()
        let err = error ?? NSError(domain: "SerialTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Disconnected"])
        for cmd in pendingCommands {
            cmd.continuation.resume(throwing: err)
        }
        pendingCommands.removeAll()
        stateLock.unlock()
    }
    
    public func disconnect() async {
        guard isConnected else { return }
        isConnected = false
        readSource?.cancel()
        readSource = nil
        cancelPendingCommands()
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transportDidDisconnect(self, error: nil)
        }
    }
    
    private func handleDisconnect(error: Error?) {
        guard isConnected else { return }
        isConnected = false
        readSource?.cancel()
        readSource = nil
        cancelPendingCommands(error: error)
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transportDidDisconnect(self, error: error)
        }
    }
}
