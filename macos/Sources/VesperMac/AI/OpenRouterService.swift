import Foundation

public struct StreamChunk: Sendable {
    public let textDelta: String?
    public let toolCallDelta: (id: String?, name: String?, args: String?)?
    public let isFinished: Bool
    
    public init(textDelta: String?, toolCallDelta: (id: String?, name: String?, args: String?)?, isFinished: Bool) {
        self.textDelta = textDelta
        self.toolCallDelta = toolCallDelta
        self.isFinished = isFinished
    }
}

@MainActor
public final class OpenRouterService {
    public static let shared = OpenRouterService()
    private let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    public init() {}
    
    public func streamChat(
        messages: [[String: Any]],
        apiKey: String,
        model: String,
        reasoningEffort: String = AppSettings.shared.reasoningEffort,
        onDelta: @escaping @MainActor (StreamChunk) -> Void
    ) async throws {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenRouterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenRouter API Key not set. Please enter it in Settings."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://github.com/vesper-flipper/vesper", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Vesper macOS Desktop", forHTTPHeaderField: "X-Title")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": [VesperPrompts.toolDefinition()],
            "tool_choice": "auto",
            "stream": true,
            "max_tokens": 4096,
            "temperature": 0.2
        ]
        
        if !reasoningEffort.isEmpty {
            payload["reasoning"] = ["effort": reasoningEffort]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenRouterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid network response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            var errBody = ""
            for try await line in bytes.lines {
                errBody += line
            }
            throw NSError(domain: "OpenRouterService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errBody)"])
        }
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if jsonString == "[DONE]" {
                onDelta(StreamChunk(textDelta: nil, toolCallDelta: nil, isFinished: true))
                break
            }
            
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first else {
                continue
            }
            
            let delta = firstChoice["delta"] as? [String: Any] ?? [:]
            let text = delta["content"] as? String
            
            var toolCallInfo: (id: String?, name: String?, args: String?)? = nil
            if let toolCalls = delta["tool_calls"] as? [[String: Any]], let firstTool = toolCalls.first {
                let id = firstTool["id"] as? String
                let function = firstTool["function"] as? [String: Any]
                let name = function?["name"] as? String
                let args = function?["arguments"] as? String
                toolCallInfo = (id, name, args)
            }
            
            onDelta(StreamChunk(textDelta: text, toolCallDelta: toolCallInfo, isFinished: false))
        }
    }
}
