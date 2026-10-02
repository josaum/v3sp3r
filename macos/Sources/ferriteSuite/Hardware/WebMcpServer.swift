import Foundation
import Network
import SwiftUI

// MARK: - MCP Tool Schema Types
public struct McpToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: McpToolInputSchema
}

public struct McpToolInputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: McpPropertyDefinition]
    public let required: [String]?
}

public struct McpPropertyDefinition: Codable, Sendable {
    public let type: String
    public let description: String
    
    public init(type: String, description: String) {
        self.type = type
        self.description = description
    }
}

// MARK: - WebMCP Server Implementation
@MainActor
@Observable
public final class WebMcpServer {
    public static let shared = WebMcpServer()
    
    public private(set) var isRunning: Bool = false
    public private(set) var port: Int = 8768
    public private(set) var requestCount: Int = 0
    public private(set) var lastRequestTime: Date?
    public private(set) var lastMethod: String = "None"
    public private(set) var activeSseClients: Int = 0
    public private(set) var statusMessage: String = "Ready"
    public private(set) var logs: [String] = []
    
    private var listener: NWListener?
    private var sseConnections: [ObjectIdentifier: NWConnection] = [:]
    private let toolExecutor = FlipperToolExecutor.shared
    private let connectionManager = FlipperConnectionManager.shared
    
    public init() {}
    
    // MARK: - Start / Stop
    public func start(port: Int = 8768) {
        guard !isRunning else { return }
        self.port = port
        
        do {
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                appendLog("[WebMCP] Invalid port number: \(port)")
                return
            }
            
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 10
            
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true
            
            let listener = try NWListener(using: params, on: nwPort)
            self.listener = listener
            
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    switch state {
                    case .ready:
                        self.isRunning = true
                        self.statusMessage = "Listening on port \(port)"
                        self.appendLog("[WebMCP] Server listening at http://127.0.0.1:\(port)")
                    case .failed(let error):
                        self.isRunning = false
                        self.statusMessage = "Error: \(error.localizedDescription)"
                        self.appendLog("[WebMCP] Server failed: \(error)")
                    case .cancelled:
                        self.isRunning = false
                        self.statusMessage = "Stopped"
                        self.appendLog("[WebMCP] Server stopped")
                    default:
                        break
                    }
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleIncomingConnection(connection)
                }
            }
            
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            self.isRunning = false
            self.statusMessage = "Startup failed: \(error.localizedDescription)"
            self.appendLog("[WebMCP] Startup error: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        listener?.cancel()
        listener = nil
        
        for (_, conn) in sseConnections {
            conn.cancel()
        }
        sseConnections.removeAll()
        activeSseClients = 0
        isRunning = false
        statusMessage = "Stopped"
        appendLog("[WebMCP] Service stopped.")
    }
    
    public func restart(port: Int = 8768) {
        stop()
        start(port: port)
    }
    
    private func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(timestamp)] \(message)")
        if logs.count > 100 {
            logs.removeFirst(logs.count - 100)
        }
    }
    
    // MARK: - Connection Handler
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 131072) { [weak self, weak connection] data, _, _, error in
            guard let connection = connection else { return }
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.appendLog("[WebMCP] Receive error: \(error)")
                }
                connection.cancel()
                return
            }
            
            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.processHttpRequest(data: data, on: connection)
            }
        }
    }
    
    // MARK: - HTTP Request Processing
    private func processHttpRequest(data: Data, on connection: NWConnection) {
        guard let rawRequest = String(data: data, encoding: .utf8) else {
            sendHttpResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid UTF-8\"}")
            return
        }
        
        let lines = rawRequest.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendHttpResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Malformed HTTP request\"}")
            return
        }
        
        let requestParts = requestLine.components(separatedBy: " ")
        guard requestParts.count >= 2 else {
            sendHttpResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Malformed request line\"}")
            return
        }
        
        let method = requestParts[0].uppercased()
        let path = requestParts[1]
        
        self.requestCount += 1
        self.lastRequestTime = Date()
        self.lastMethod = "\(method) \(path)"
        
        // Handle CORS Preflight
        if method == "OPTIONS" {
            sendCorsPreflight(connection: connection)
            return
        }
        
        // Handle GET /health or GET /
        if method == "GET" && (path == "/health" || path == "/" || path == "/status") {
            let healthJson = generateHealthReport()
            sendHttpResponse(connection: connection, statusCode: 200, contentType: "application/json; charset=utf-8", body: healthJson)
            return
        }
        
        // Handle SSE Stream: GET /sse
        if method == "GET" && path.starts(with: "/sse") {
            setupSseStream(connection: connection)
            return
        }
        
        // Handle MCP JSON-RPC: POST /mcp or POST /
        if method == "POST" && (path == "/mcp" || path == "/" || path.starts(with: "/mcp")) {
            // Find request body after \r\n\r\n
            if let bodyRange = rawRequest.range(of: "\r\n\r\n") {
                let bodyString = String(rawRequest[bodyRange.upperBound...])
                if let bodyData = bodyString.data(using: .utf8), !bodyData.isEmpty {
                    handleJsonRpc(bodyData: bodyData, connection: connection)
                    return
                }
            }
            sendHttpResponse(connection: connection, statusCode: 400, body: "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32700,\"message\":\"Parse error: Empty body\"},\"id\":null}")
            return
        }
        
        // Default 404
        sendHttpResponse(connection: connection, statusCode: 404, body: "{\"error\":\"Not Found\",\"available_endpoints\":[\"/mcp\",\"/sse\",\"/health\"]}")
    }
    
    // MARK: - SSE Connection Setup
    private func setupSseStream(connection: NWConnection) {
        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/event-stream",
            "Cache-Control: no-cache",
            "Connection: keep-alive",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: *",
            "\r\n"
        ].joined(separator: "\r\n")
        
        connection.send(content: headers.data(using: .utf8), completion: .contentProcessed({ [weak self, weak connection] error in
            guard error == nil else { return }
            Task { @MainActor [weak self, weak connection] in
                guard let self = self, let connection = connection else { return }
                
                let connId = ObjectIdentifier(connection)
                self.sseConnections[connId] = connection
                self.activeSseClients = self.sseConnections.count
                self.appendLog("[WebMCP] New SSE client connected (Total: \(self.activeSseClients))")
                
                // Inform client of endpoint for JSON-RPC messages (Standard MCP SSE handshake)
                let endpointEvent = "event: endpoint\r\ndata: /mcp\r\n\r\n"
                connection.send(content: endpointEvent.data(using: .utf8), completion: .contentProcessed({ _ in }))
                
                connection.stateUpdateHandler = { [weak self, weak connection] state in
                    if state == .cancelled || state == .failed(NWError.posix(.ECONNRESET)) {
                        Task { @MainActor [weak self, weak connection] in
                            guard let self = self, let connection = connection else { return }
                            let id = ObjectIdentifier(connection)
                            self.sseConnections.removeValue(forKey: id)
                            self.activeSseClients = self.sseConnections.count
                            self.appendLog("[WebMCP] SSE client disconnected (Remaining: \(self.activeSseClients))")
                        }
                    }
                }
            }
        }))
    }
    
    // MARK: - Broadcast Message via SSE
    public func broadcastSse(event: String = "message", data: String) {
        let message = "event: \(event)\r\ndata: \(data)\r\n\r\n"
        guard let rawData = message.data(using: .utf8) else { return }
        
        for (id, conn) in sseConnections {
            conn.send(content: rawData, completion: .contentProcessed({ [weak self] error in
                if error != nil {
                    Task { @MainActor [weak self] in
                        self?.sseConnections.removeValue(forKey: id)
                        self?.activeSseClients = self?.sseConnections.count ?? 0
                    }
                }
            }))
        }
    }
    
    // MARK: - JSON-RPC 2.0 Handler
    private func handleJsonRpc(bodyData: Data, connection: NWConnection) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                sendJsonRpcError(connection: connection, id: nil, code: -32600, message: "Invalid Request: Expected JSON object")
                return
            }
            
            let requestId = json["id"]
            guard let method = json["method"] as? String else {
                sendJsonRpcError(connection: connection, id: requestId, code: -32600, message: "Missing method")
                return
            }
            
            let params = json["params"] as? [String: Any] ?? [:]
            appendLog("[WebMCP] MCP Method: \(method)")
            
            switch method {
            case "initialize":
                let initResult: [String: Any] = [
                    "protocolVersion": "2024-11-05",
                    "capabilities": [
                        "tools": [
                            "listChanged": false
                        ],
                        "resources": [
                            "subscribe": false,
                            "listChanged": false
                        ]
                    ],
                    "serverInfo": [
                        "name": "vesper-flipper-bridge",
                        "version": "1.0.0",
                        "device": connectionManager.deviceInfo.hardwareModel.isEmpty ? "Flipper Zero" : connectionManager.deviceInfo.hardwareModel
                    ]
                ]
                sendJsonRpcResponse(connection: connection, id: requestId, result: initResult)
                
            case "notifications/initialized":
                // Standard notification acknowledgement
                sendJsonRpcResponse(connection: connection, id: requestId, result: [:])
                
            case "ping":
                sendJsonRpcResponse(connection: connection, id: requestId, result: [:])
                
            case "tools/list":
                let tools = buildMcpToolsList()
                sendJsonRpcResponse(connection: connection, id: requestId, result: ["tools": tools])
                
            case "tools/call":
                Task { [weak self, weak connection] in
                    guard let self = self, let connection = connection else { return }
                    await self.handleToolCall(params: params, requestId: requestId, connection: connection)
                }
                
            case "resources/list":
                let resources = buildMcpResourcesList()
                sendJsonRpcResponse(connection: connection, id: requestId, result: ["resources": resources])
                
            case "resources/read":
                let uri = params["uri"] as? String ?? ""
                let resourceContent = readMcpResource(uri: uri)
                sendJsonRpcResponse(connection: connection, id: requestId, result: ["contents": [resourceContent]])
                
            default:
                sendJsonRpcError(connection: connection, id: requestId, code: -32601, message: "Method '\(method)' not found")
            }
        } catch {
            sendJsonRpcError(connection: connection, id: nil, code: -32700, message: "Parse error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Execute Tool Call
    private func handleToolCall(params: [String: Any], requestId: Any?, connection: NWConnection) async {
        guard let toolName = params["name"] as? String else {
            sendJsonRpcError(connection: connection, id: requestId, code: -32602, message: "Missing tool name in tools/call")
            return
        }
        
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        
        // Normalize tool name (strip flipper_ prefix if present)
        var action = toolName
        if action.hasPrefix("flipper_") {
            action = String(action.dropFirst(8))
        }
        
        // Convert all arguments to string map
        var stringParams: [String: String] = [:]
        for (k, v) in arguments {
            if let strVal = v as? String {
                stringParams[k] = strVal
            } else if let intVal = v as? Int {
                stringParams[k] = String(intVal)
            } else if let boolVal = v as? Bool {
                stringParams[k] = boolVal ? "true" : "false"
            } else if let dblVal = v as? Double {
                stringParams[k] = String(dblVal)
            } else {
                stringParams[k] = "\(v)"
            }
        }
        
        appendLog("[WebMCP] Executing Tool: \(action) with \(stringParams.count) params")
        
        // Execute tool directly on Flipper hardware
        let result = await toolExecutor.execute(action: action, params: stringParams)
        
        let contentObj: [String: Any] = [
            "type": "text",
            "text": result.output
        ]
        
        let mcpResult: [String: Any] = [
            "content": [contentObj],
            "isError": result.isError
        ]
        
        sendJsonRpcResponse(connection: connection, id: requestId, result: mcpResult)
        
        // Also broadcast tool output to active SSE clients
        if let outputData = try? JSONSerialization.data(withJSONObject: mcpResult),
           let outputStr = String(data: outputData, encoding: .utf8) {
            broadcastSse(event: "tool_executed", data: outputStr)
        }
    }
    
    // MARK: - Resource Handler
    private func readMcpResource(uri: String) -> [String: Any] {
        switch uri {
        case "flipper://device/status":
            let dev = connectionManager.deviceInfo
            let status: [String: Any] = [
                "connected": connectionManager.status.isConnected,
                "hardware": dev.hardwareModel,
                "firmware": dev.firmwareVersion,
                "battery": dev.batteryLevel,
                "charging": dev.isCharging,
                "status": connectionManager.status.description
            ]
            let json = (try? String(data: JSONSerialization.data(withJSONObject: status, options: .prettyPrinted), encoding: .utf8)) ?? "{}"
            return ["uri": uri, "mimeType": "application/json", "text": json]
            
        case "flipper://memory/vault":
            let memories = VesperMemoryStore.shared.memories
            let md = "# ferriteSuite Memory Vault Export\n\n" + memories.map { mem in
                "### [\(mem.category.rawValue)] \(mem.title)\n*\(mem.timestamp.formatted())*\n\n\(mem.content)\n"
            }.joined(separator: "\n---\n\n")
            return ["uri": uri, "mimeType": "text/markdown", "text": md]
            
        case "flipper://ferrite/status":
            let f = FerriteOSService.shared
            let state: [String: Any] = [
                "available": f.isAvailable,
                "lastIntent": f.lastUnderstanding?.intent ?? "None",
                "lastDomain": f.lastUnderstanding?.domain ?? "None",
                "recentCount": f.recentOutputs.count
            ]
            let json = (try? String(data: JSONSerialization.data(withJSONObject: state, options: .prettyPrinted), encoding: .utf8)) ?? "{}"
            return ["uri": uri, "mimeType": "application/json", "text": json]
            
        case "flipper://portal/current":
            let service = CaptivePortalService.shared
            return ["uri": uri, "mimeType": "text/html", "text": service.currentHtml]
            
        default:
            return ["uri": uri, "mimeType": "text/plain", "text": "Resource not found for uri: \(uri)"]
        }
    }
    
    // MARK: - Built-in Tools Schema
    private func buildMcpToolsList() -> [[String: Any]] {
        return [
            [
                "name": "flipper_list_directory",
                "description": "List files and directories on the Flipper Zero SD card.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute SD card path, e.g. /ext, /ext/subghz, /ext/nfc"]
                    ]
                ]
            ],
            [
                "name": "flipper_read_file",
                "description": "Read text content of a file on the Flipper Zero SD card.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "File path, e.g. /ext/subghz/gate.sub"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "flipper_write_file",
                "description": "Write text content to a file on the Flipper Zero SD card.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Target file path"],
                        "content": ["type": "string", "description": "Text payload to write"]
                    ],
                    "required": ["path", "content"]
                ]
            ],
            [
                "name": "flipper_delete",
                "description": "Delete a file or empty directory from the Flipper Zero SD card.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to delete"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "flipper_get_device_info",
                "description": "Retrieve Flipper Zero device hardware info, architecture, and battery health.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "flipper_get_storage_info",
                "description": "Retrieve Flipper Zero SD card capacity and free space.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "flipper_execute_cli",
                "description": "Execute any raw CLI command over Flipper Zero USB CDC serial session (e.g., uptime, date, ps, free).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "command": ["type": "string", "description": "Flipper CLI command string"]
                    ],
                    "required": ["command"]
                ]
            ],
            [
                "name": "flipper_launch_app",
                "description": "Launch an on-device application on Flipper Zero screen (e.g. Sub-GHz, NFC, BadUSB).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "app_name": ["type": "string", "description": "Application name or path"]
                    ],
                    "required": ["app_name"]
                ]
            ],
            [
                "name": "flipper_subghz_transmit",
                "description": "Transmit a recorded Sub-GHz .sub signal file via internal CC1101 transceiver.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to .sub file on SD card"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "flipper_ir_transmit",
                "description": "Transmit a recorded Infrared .ir signal file via IR LED.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to .ir file on SD card"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "flipper_badusb_execute",
                "description": "Execute a DuckyScript payload file via USB HID emulation.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to BadUSB script on SD card"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "flipper_led_control",
                "description": "Set Flipper Zero RGB notification LED color (r, g, b from 0 to 255).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "r": ["type": "string", "description": "Red intensity 0-255"],
                        "g": ["type": "string", "description": "Green intensity 0-255"],
                        "b": ["type": "string", "description": "Blue intensity 0-255"]
                    ]
                ]
            ],
            [
                "name": "flipper_vibro_control",
                "description": "Control Flipper Zero haptic vibration motor (enable: true/false).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "enable": ["type": "string", "description": "true to turn on, false to turn off"]
                    ],
                    "required": ["enable"]
                ]
            ],
            [
                "name": "ferrite_understand",
                "description": "Parse natural language command using FerriteOS deterministic offline model.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "phrase": ["type": "string", "description": "Natural language tactical request"]
                    ],
                    "required": ["phrase"]
                ]
            ],
            [
                "name": "ferrite_decode",
                "description": "Run FerriteOS high-speed Rust decoder against captured RF/Sub-GHz raw signals.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to capture file on SD card"],
                        "phrase": ["type": "string", "description": "Optional context phrase"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "record_memory",
                "description": "Save security findings, access credentials, and RF observations into ferriteSuite memory vault.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "Note title"],
                        "content": ["type": "string", "description": "Detailed notes or payload"],
                        "category": ["type": "string", "description": "Category: RF Analysis, Access Control, Hardware Pinout, Payload, Operator Knowledge"]
                    ],
                    "required": ["title", "content"]
                ]
            ],
            [
                "name": "trigger_workflow",
                "description": "Trigger an autonomous DAG multi-step hardware workflow (Sub-GHz Recon, Diagnostic Self-Test, Badge Auditor).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "workflow_name": ["type": "string", "description": "Workflow identifier: subghz, diagnostic, access_control"]
                    ],
                    "required": ["workflow_name"]
                ]
            ],
            [
                "name": "check_firmware_updates",
                "description": "Query latest official, Unleashed, Momentum, and RogueMaster GitHub firmware releases.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "flash_flipper_firmware",
                "description": "Trigger automated download and flashing of Flipper Zero firmware release.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "distro": ["type": "string", "description": "Firmware distribution: unleashed, official, momentum, roguemaster"]
                    ],
                    "required": ["distro"]
                ]
            ],
            [
                "name": "flash_gpio_board",
                "description": "Upload ESP32 802.11 Diagnostic Suite or NRF24 telemetry firmware to Flipper SD card ready for GPIO staging.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "diagnose_gpio_devboard",
                "description": "Test GPIO header pinout and UART connectivity to external devboard.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "run_diagnostics",
                "description": "Run comprehensive 7-point hardware, power, storage, GPIO, FerriteOS image, and DFU/SWD toolchain diagnostics.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "ferrite_preflight",
                "description": "Verify FerriteOS bare-metal binary (check_image.py, 225KB, 0x08000000 base, SHA256 integrity).",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "ferrite_unit_tests",
                "description": "Execute the automated 33 unit test suite for FerriteOS firmware and parser modules.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "ferrite_dfu_scan",
                "description": "Scan USB bus for STM32 DFU bootloader devices via dfu-util.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "ferrite_probe_scan",
                "description": "Scan attached SWD debug probes using probe-rs.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "probe_inspect",
                "description": "Directly inspect target MCU silicon UID, device signature, and vector table via attached SWD probe.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "chip": [
                            "type": "string",
                            "description": "Target MCU chip (default: STM32WB55RGVx)"
                        ]
                    ]
                ]
            ],
            [
                "name": "probe_read_memory",
                "description": "Read 32-bit memory words from target MCU address via SWD debug probe.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "address": [
                            "type": "string",
                            "description": "Hex address (e.g. 0x1FFF7580, 0x08000000, 0x20000000)"
                        ],
                        "words": [
                            "type": "integer",
                            "description": "Number of 32-bit words to read (1-64)"
                        ]
                    ],
                    "required": ["address"]
                ]
            ],
            [
                "name": "probe_reset",
                "description": "Issue hardware SWD reset to attached MCU target.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "halt": [
                            "type": "boolean",
                            "description": "Whether to halt execution / connect under reset"
                        ]
                    ]
                ]
            ],
            [
                "name": "probe_dump_flash",
                "description": "Dump binary snapshot of MCU flash memory directly to local disk for forensics and recovery.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "address": [
                            "type": "string",
                            "description": "Start address in hex (default: 0x08000000)"
                        ],
                        "words": [
                            "type": "integer",
                            "description": "Word count (default: 16384 for 64KB)"
                        ],
                        "destination": [
                            "type": "string",
                            "description": "Output file path on host"
                        ]
                    ]
                ]
            ],
            [
                "name": "pi_harness_status",
                "description": "Inspect host Pi Coding Agent harness executable, path, and ~/.pi/agent configurations.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "pi_harness_test",
                "description": "Run execution diagnostic on host Pi coding agent harness.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "portal_list_templates",
                "description": "List all built-in defensive captive portal templates (AUP, audit scope, maintenance, event).",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "portal_design_with_ai",
                "description": "Instruct AI to design or refine an offline, responsive single-file HTML/CSS captive portal page.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "prompt": ["type": "string", "description": "Design guidance, styling instructions, or corporate branding requirements"],
                        "template_id": ["type": "string", "description": "Optional starting template ID: corporate_aup, audit_scope, network_maintenance, event_wifi"]
                    ],
                    "required": ["prompt"]
                ]
            ],
            [
                "name": "portal_deploy_to_flipper",
                "description": "Stage and deploy the captive portal index.html file to Flipper Zero SD card (/ext/apps_data/evil_portal).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "html": ["type": "string", "description": "Optional custom HTML content. If omitted, deploys current architect HTML."],
                        "target_folder": ["type": "string", "description": "Target folder on SD card, defaults to /ext/apps_data/evil_portal"]
                    ]
                ]
            ]
        ]
    }
    
    private func buildMcpResourcesList() -> [[String: Any]] {
        return [
            [
                "uri": "flipper://device/status",
                "name": "Flipper Zero Device Telemetry",
                "description": "Live battery, connection state, and firmware build",
                "mimeType": "application/json"
            ],
            [
                "uri": "flipper://memory/vault",
                "name": "ferriteSuite Tactical Memory Vault",
                "description": "Export of all recorded operator memories, credentials, and RF notes",
                "mimeType": "text/markdown"
            ],
            [
                "uri": "flipper://ferrite/status",
                "name": "FerriteOS Local Model Status",
                "description": "FerriteOS intent engine availability and latest plan",
                "mimeType": "application/json"
            ],
            [
                "uri": "flipper://portal/current",
                "name": "Captive Portal HTML Active Draft",
                "description": "Live HTML/CSS content currently staged in Captive Portal Architect",
                "mimeType": "text/html"
            ]
        ]
    }
    
    // MARK: - Health & Status
    private func generateHealthReport() -> String {
        let dev = connectionManager.deviceInfo
        let model = dev.hardwareModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let report: [String: Any] = [
            "status": "online",
            "server": "ferriteSuite WebMCP Bridge",
            "version": "1.0.0",
            "port": port,
            "flipper_connected": connectionManager.status.isConnected,
            "flipper_model": model.isEmpty ? "Flipper Zero" : model,
            "flipper_firmware": dev.firmwareVersion.trimmingCharacters(in: .whitespacesAndNewlines),
            "battery_percent": dev.batteryLevel,
            "is_charging": dev.isCharging,
            "tools_count": buildMcpToolsList().count,
            "active_sse_clients": activeSseClients,
            "total_requests": requestCount,
            "claude_desktop_config": [
                "mcpServers": [
                    "vesper": [
                        "url": "http://127.0.0.1:\(port)/sse"
                    ]
                ]
            ]
        ]
        
        let data = (try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - HTTP Helpers
    private func sendCorsPreflight(connection: NWConnection) {
        let headers = [
            "HTTP/1.1 204 No Content",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS, HEAD",
            "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, baggage, sentry-trace",
            "Access-Control-Max-Age: 86400",
            "Content-Length: 0",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")
        
        connection.send(content: headers.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendHttpResponse(connection: NWConnection, statusCode: Int, contentType: String = "application/json; charset=utf-8", body: String) {
        guard let bodyData = body.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        let statusText = statusCode == 200 ? "OK" : (statusCode == 404 ? "Not Found" : (statusCode == 400 ? "Bad Request" : "Internal Error"))
        let headers = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Content-Type: \(contentType)",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: *",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")
        
        var packet = headers.data(using: .utf8) ?? Data()
        packet.append(bodyData)
        
        connection.send(content: packet, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendJsonRpcResponse(connection: NWConnection, id: Any?, result: [String: Any]) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id = id {
            response["id"] = id
        } else {
            response["id"] = NSNull()
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: response),
           let body = String(data: data, encoding: .utf8) {
            sendHttpResponse(connection: connection, statusCode: 200, contentType: "application/json; charset=utf-8", body: body)
        } else {
            sendHttpResponse(connection: connection, statusCode: 500, body: "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32603,\"message\":\"Failed to serialize response\"},\"id\":null}")
        }
    }
    
    private func sendJsonRpcError(connection: NWConnection, id: Any?, code: Int, message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ]
        ]
        if let id = id {
            response["id"] = id
        } else {
            response["id"] = NSNull()
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: response),
           let body = String(data: data, encoding: .utf8) {
            sendHttpResponse(connection: connection, statusCode: 200, contentType: "application/json; charset=utf-8", body: body)
        }
    }
}
