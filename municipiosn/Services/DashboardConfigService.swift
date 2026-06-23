import Foundation
import Supabase

struct DashboardConfigService {
    static let shared = DashboardConfigService()
    private init() {}

    private struct PerfilConfig: Decodable {
        let dashboard_config: [DashboardCardItem]?
    }

    private struct ConfigUpdate: Encodable {
        let dashboard_config: [DashboardCardItem]
    }

    func fetch(userId: UUID) async -> [DashboardCardItem] {
        do {
            let result: PerfilConfig = try await SupabaseService.shared.client
                .from("perfiles")
                .select("dashboard_config")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            if let saved = result.dashboard_config, !saved.isEmpty {
                return mergeWithDefaults(saved: saved)
            }
        } catch {}
        return DashboardCardItem.defaults
    }

    func save(userId: UUID, config: [DashboardCardItem]) async {
        do {
            try await SupabaseService.shared.client
                .from("perfiles")
                .update(ConfigUpdate(dashboard_config: config))
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {}
    }

    // New cards added by dev automatically appear at the end, active by default
    private func mergeWithDefaults(saved: [DashboardCardItem]) -> [DashboardCardItem] {
        var result = saved
        let savedIDs = Set(saved.map { $0.id })
        for card in DashboardCardItem.defaults where !savedIDs.contains(card.id) {
            result.append(card)
        }
        return result
    }
}
