@preconcurrency import CoreBluetooth

public final class BleTransport: NSObject, @unchecked Sendable, FlipperTransport, CBCentralManagerDelegate, CBPeripheralDelegate {
    public weak var delegate: (any FlipperTransportDelegate)?
    public let transportType: TransportType = .ble
    
    private(set) public var isConnected: Bool = false
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    public static var serialServiceUUID: CBUUID { CBUUID(string: "19ed8270-ed37-49ac-82e5-5b8d1ebf373e") }
    public static var serialTxUUID: CBUUID { CBUUID(string: "19ed8272-ed37-49ac-82e5-5b8d1ebf373e") }
    public static var serialRxUUID: CBUUID { CBUUID(string: "19ed8271-ed37-49ac-82e5-5b8d1ebf373e") }
    
    private var incomingBuffer = ""
    private var pendingContinuations: [CheckedContinuation<String, Error>] = []
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()
    
    private let targetDeviceName: String?
    
    public init(targetDeviceName: String? = nil) {
        self.targetDeviceName = targetDeviceName
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "com.vesper.ble", qos: .userInitiated))
    }
    
    public func connect() async throws {
        guard !isConnected else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.lock.lock()
            self.connectionContinuation = continuation
            self.lock.unlock()
            
            if centralManager.state == .poweredOn {
                startScan()
            }
        }
    }
    
    private func startScan() {
        centralManager.scanForPeripherals(withServices: [Self.serialServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    public func disconnect() async {
        guard let peripheral = targetPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        targetPeripheral = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        isConnected = false
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transportDidDisconnect(self, error: nil)
        }
    }
    
    public func send(command: String) async throws -> String {
        guard isConnected, let tx = txCharacteristic, let peripheral = targetPeripheral else {
            throw NSError(domain: "BleTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "BLE not connected"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            incomingBuffer = ""
            pendingContinuations.append(continuation)
            lock.unlock()
            
            let cmdString = command.trimmingCharacters(in: .whitespacesAndNewlines) + "\r\n"
            guard let data = cmdString.data(using: .utf8) else { return }
            
            let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
            let chunkSize = max(20, min(mtu, 512))
            
            var offset = 0
            while offset < data.count {
                let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
                peripheral.writeValue(chunk, for: tx, type: .withoutResponse)
                offset += chunk.count
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                if let idx = self.pendingContinuations.firstIndex(where: { _ in true }) {
                    let cont = self.pendingContinuations.remove(at: idx)
                    self.lock.unlock()
                    cont.resume(throwing: NSError(domain: "BleTransport", code: -2, userInfo: [NSLocalizedDescriptionKey: "BLE command timed out"]))
                } else {
                    self.lock.unlock()
                }
            }
        }
    }
    
    public func sendRaw(data: Data) async throws {
        guard isConnected, let tx = txCharacteristic, let peripheral = targetPeripheral else { return }
        peripheral.writeValue(data, for: tx, type: .withoutResponse)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && connectionContinuation != nil {
            startScan()
        } else if central.state != .poweredOn && isConnected {
            isConnected = false
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.delegate?.transportDidDisconnect(self, error: NSError(domain: "BleTransport", code: -3, userInfo: [NSLocalizedDescriptionKey: "Bluetooth powered off"]))
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Flipper Zero"
        if let target = targetDeviceName, !name.localizedCaseInsensitiveContains(target) {
            return
        }
        
        central.stopScan()
        targetPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serialServiceUUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lock.lock()
        let cont = connectionContinuation
        connectionContinuation = nil
        lock.unlock()
        cont?.resume(throwing: error ?? NSError(domain: "BleTransport", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to connect"]))
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        txCharacteristic = nil
        rxCharacteristic = nil
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transportDidDisconnect(self, error: error)
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serialServiceUUID {
            peripheral.discoverCharacteristics([Self.serialTxUUID, Self.serialRxUUID], for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == Self.serialTxUUID {
                self.txCharacteristic = char
            } else if char.uuid == Self.serialRxUUID {
                self.rxCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        
        if txCharacteristic != nil && rxCharacteristic != nil {
            self.isConnected = true
            lock.lock()
            let cont = connectionContinuation
            connectionContinuation = nil
            lock.unlock()
            cont?.resume()
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.delegate?.transportDidConnect(self)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.delegate?.transport(self, didReceiveRawData: data)
        }
        
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return }
        
        lock.lock()
        incomingBuffer.append(text)
        let cleaned = incomingBuffer.replacingOccurrences(of: "\r", with: "")
        let hasPrompt = cleaned.hasSuffix(">: ") || cleaned.contains("\n>: ")
        
        if hasPrompt && !pendingContinuations.isEmpty {
            let output = incomingBuffer
            incomingBuffer = ""
            let continuation = pendingContinuations.removeFirst()
            lock.unlock()
            continuation.resume(returning: output)
            return
        }
        lock.unlock()
        
        let lines = text.components(separatedBy: "\n")
        for line in lines where !line.isEmpty {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.delegate?.transport(self, didReceiveLine: line)
            }
        }
    }
}
