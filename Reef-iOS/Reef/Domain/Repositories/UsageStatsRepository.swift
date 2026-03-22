import Foundation

protocol UsageStatsRepository: Sendable {
    func fetchUsageStats() async throws -> UsageStats
}
