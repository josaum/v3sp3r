import Foundation

@MainActor
public protocol FlipperTransportDelegate: AnyObject {
    func transportDidConnect(_ transport: any FlipperTransport)
    func transportDidDisconnect(_ transport: any FlipperTransport, error: Error?)
    func transport(_ transport: any FlipperTransport, didReceiveLine line: String)
    func transport(_ transport: any FlipperTransport, didReceiveRawData data: Data)
}

public protocol FlipperTransport: AnyObject, Sendable {
    var delegate: (any FlipperTransportDelegate)? { get set }
    var transportType: TransportType { get }
    var isConnected: Bool { get }
    
    func connect() async throws
    func disconnect() async
    func send(command: String) async throws -> String
    func sendRaw(data: Data) async throws
}
