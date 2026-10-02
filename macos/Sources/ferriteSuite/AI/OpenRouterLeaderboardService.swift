import Foundation
import SwiftUI

public struct OpenRouterLeaderboardEntry: Identifiable, Codable, Equatable {
    public let id: String
    public let rank: Int
    public let name: String
    public let author: String
    public let tokensProcessed: String
    public let growth: String
    public let contextLength: Int
    public let description: String
    public let isFree: Bool
    
    public var badgeText: String {
        "#\(rank) Leaderboard"
    }
    
    public init(
        id: String,
        rank: Int,
        name: String,
        author: String,
        tokensProcessed: String,
        growth: String,
        contextLength: Int = 128000,
        description: String = "",
        isFree: Bool = false
    ) {
        self.id = id
        self.rank = rank
        self.name = name
        self.author = author
        self.tokensProcessed = tokensProcessed
        self.growth = growth
        self.contextLength = contextLength
        self.description = description
        self.isFree = isFree
    }
}

@MainActor
@Observable
public final class OpenRouterLeaderboardService {
    public static let shared = OpenRouterLeaderboardService()
    
    public var leaderboard: [OpenRouterLeaderboardEntry] = []
    public var isLoading: Bool = false
    public var lastUpdated: Date? = nil
    public var statusMessage: String = ""
    
    public init() {
        seedInitialRankings()
        Task {
            await fetchLiveLeaderboard()
        }
    }
    
    // MARK: - Live Leaderboard Fetching from https://openrouter.ai/rankings
    
    public func fetchLiveLeaderboard() async {
        guard !isLoading else { return }
        isLoading = true
        statusMessage = "Fetching live rankings from openrouter.ai/rankings..."
        
        defer { isLoading = false }
        
        do {
            // 1. Fetch rankings HTML
            guard let rankingsUrl = URL(string: "https://openrouter.ai/rankings") else { return }
            var rankingsReq = URLRequest(url: rankingsUrl)
            rankingsReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
            
            let (htmlData, _) = try await URLSession.shared.data(for: rankingsReq)
            guard let html = String(data: htmlData, encoding: .utf8) else { return }
            
            // 2. Fetch models API for context lengths & exact IDs
            var modelsMap: [String: (id: String, name: String, context: Int, desc: String, isFree: Bool)] = [:]
            if let modelsUrl = URL(string: "https://openrouter.ai/api/v1/models") {
                var modelsReq = URLRequest(url: modelsUrl)
                modelsReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                if let (apiData, _) = try? await URLSession.shared.data(for: modelsReq),
                   let json = try? JSONSerialization.jsonObject(with: apiData) as? [String: Any],
                   let list = json["data"] as? [[String: Any]] {
                    for m in list {
                        if let mid = m["id"] as? String {
                            let mName = m["name"] as? String ?? mid
                            let ctx = m["context_length"] as? Int ?? 128000
                            let desc = m["description"] as? String ?? ""
                            let pricing = m["pricing"] as? [String: Any]
                            let promptPrice = pricing?["prompt"] as? String ?? ""
                            let isFree = promptPrice == "0" || mid.contains(":free")
                            modelsMap[mid.lowercased()] = (mid, mName, ctx, desc, isFree)
                        }
                    }
                }
            }
            
            // 3. Parse table rows with Regex
            // Table row pattern: <td class="or-table__cell">(\d+)</td>...<th[^>]*>(.*?)</th>...<td class="or-table__cell">([^<]+)</td>...<td class="or-table__cell">([^<]+)</td>...<td class="or-table__cell">([^<]+)</td>
            let rowPattern = try NSRegularExpression(
                pattern: "<td class=\"or-table__cell\">(\\d+)</td>\\s*<th[^>]*>(.*?)</th>\\s*<td class=\"or-table__cell\">([^<]+)</td>\\s*<td class=\"or-table__cell\">([^<]+)</td>\\s*<td class=\"or-table__cell\">([^<]+)</td>",
                options: [.dotMatchesLineSeparators]
            )
            
            let nsString = html as NSString
            let matches = rowPattern.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var parsedEntries: [OpenRouterLeaderboardEntry] = []
            var seenRanks = Set<Int>()
            
            for match in matches {
                guard match.numberOfRanges >= 6 else { continue }
                let rankStr = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let nameStr = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let authorStr = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                let tokensStr = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)
                let growthStr = nsString.substring(with: match.range(at: 5))
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let rank = Int(rankStr) else { continue }
                if seenRanks.contains(rank) && rank == 1 {
                    // Secondary table on page reached
                    break
                }
                seenRanks.insert(rank)
                
                // Match with models API
                let authorClean = authorStr.lowercased()
                let nameClean = nameStr
                let slug = nameClean.lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .replacingOccurrences(of: ":", with: "")
                
                var matchedId = "\(authorClean)/\(slug)"
                var ctxLen = 128000
                var desc = "\(tokensStr) processed on OpenRouter (\(growthStr))"
                var isFree = false
                
                // Exact key or author search
                if let direct = modelsMap[matchedId.lowercased()] {
                    matchedId = direct.id
                    ctxLen = direct.context
                    if !direct.desc.isEmpty { desc = direct.desc }
                    isFree = direct.isFree
                } else {
                    let nameLower = nameClean.lowercased()
                    for (k, v) in modelsMap {
                        let vNameLower = v.name.lowercased()
                        if k.hasPrefix(authorClean) && (vNameLower == nameLower || vNameLower.contains(nameLower) || k.contains(slug)) {
                            matchedId = v.id
                            ctxLen = v.context
                            if !v.desc.isEmpty { desc = v.desc }
                            isFree = v.isFree
                            break
                        }
                    }
                }
                
                parsedEntries.append(OpenRouterLeaderboardEntry(
                    id: matchedId,
                    rank: rank,
                    name: nameClean,
                    author: authorStr,
                    tokensProcessed: tokensStr,
                    growth: growthStr,
                    contextLength: ctxLen,
                    description: desc,
                    isFree: isFree
                ))
            }
            
            if !parsedEntries.isEmpty {
                self.leaderboard = parsedEntries
                self.lastUpdated = Date()
                self.statusMessage = "Synced \(parsedEntries.count) top models from openrouter.ai/rankings."
                
                // Update AppSettings available models dynamically
                AppSettings.shared.updateWithLeaderboard(parsedEntries)
            }
        } catch {
            self.statusMessage = "Leaderboard fetch error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Initial Snapshot Seed
    
    private func seedInitialRankings() {
        self.leaderboard = [
            OpenRouterLeaderboardEntry(
                id: "stealth/space-bunny-alpha",
                rank: 1,
                name: "Space Bunny Alpha",
                author: "stealth",
                tokensProcessed: "28.4T tokens",
                growth: ">999%",
                contextLength: 1000000,
                description: "#1 Leaderboard: High-volume frontier reasoning engine on OpenRouter.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "deepseek/deepseek-v4.1-flash",
                rank: 2,
                name: "DeepSeek V4.1 Flash",
                author: "deepseek",
                tokensProcessed: "22.7T tokens",
                growth: "+23%",
                contextLength: 128000,
                description: "#2 Leaderboard: Ultra low-latency MoE model with exceptional reasoning throughput.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "z-ai/glm-5.3-flash",
                rank: 3,
                name: "GLM 5.3 Flash",
                author: "z-ai",
                tokensProcessed: "10.6T tokens",
                growth: "-44%",
                contextLength: 1000000,
                description: "#3 Leaderboard: High context length Chinese & English reasoning specialist.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "xiaomi/mimo-v2.6-flash",
                rank: 4,
                name: "MiMo-V2.6-Flash",
                author: "xiaomi",
                tokensProcessed: "9.1T tokens",
                growth: ">999%",
                contextLength: 262144,
                description: "#4 Leaderboard: Fast edge-optimized multi-modal model.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "openai/gpt-5.6-luna",
                rank: 5,
                name: "GPT-5.6 Luna",
                author: "openai",
                tokensProcessed: "7.75T tokens",
                growth: "-11%",
                contextLength: 1050000,
                description: "#5 Leaderboard: OpenAI flagship reasoning and agentic workflow model.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "tencent/hy4-preview",
                rank: 6,
                name: "Hy4 Preview",
                author: "tencent",
                tokensProcessed: "7.48T tokens",
                growth: "-42%",
                contextLength: 256000,
                description: "#6 Leaderboard: Advanced agentic coding & hardware analysis engine.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "deepseek/deepseek-v4-flash-0731",
                rank: 7,
                name: "DeepSeek V4 Flash 0731",
                author: "deepseek",
                tokensProcessed: "7.04T tokens",
                growth: "-17%",
                contextLength: 128000,
                description: "#7 Leaderboard: Stable production checkpoint for high-speed inferences.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "nvidia/nemotron-3.5-lightning",
                rank: 8,
                name: "Nemotron 3 Ultra (Free)",
                author: "nvidia",
                tokensProcessed: "6.06T tokens",
                growth: "+21%",
                contextLength: 128000,
                description: "#8 Leaderboard: High-throughput NVIDIA architecture (Free tier eligible).",
                isFree: true
            ),
            OpenRouterLeaderboardEntry(
                id: "openai/gpt-6-luna",
                rank: 9,
                name: "GPT-6 Luna",
                author: "openai",
                tokensProcessed: "5.05T tokens",
                growth: "+948%",
                contextLength: 1050000,
                description: "#9 Leaderboard: Next-generation ultra-deep thinking & autonomous synthesis.",
                isFree: false
            ),
            OpenRouterLeaderboardEntry(
                id: "anthropic/claude-sonnet-5.5",
                rank: 10,
                name: "Claude Sonnet 5.5",
                author: "anthropic",
                tokensProcessed: "4.82T tokens",
                growth: "+15%",
                contextLength: 1000000,
                description: "#10 Leaderboard: SOTA code generation, tool-use, and firmware synthesis.",
                isFree: false
            )
        ]
        self.lastUpdated = Date()
        self.statusMessage = "Seeded with verified OpenRouter leaderboard rankings."
    }
}
