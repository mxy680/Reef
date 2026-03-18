import Foundation
import Supabase

struct SupabaseUsageStatsRepository: UsageStatsRepository {
    func fetchUsageStats() async throws -> UsageStats {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        let docResponse = try await supabase
            .from("documents")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()

        let courseResponse = try await supabase
            .from("courses")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()

        return UsageStats(
            documentCount: docResponse.count ?? 0,
            courseCount: courseResponse.count ?? 0
        )
    }
}
