import Foundation
import Supabase
import CoreLocation

struct UbicacionActiva: Codable {
    let userId: UUID
    let lat: Double
    let lng: Double
    let updatedAt: Date
    let perfiles: PerfilNombre?

    struct PerfilNombre: Codable { let nombre: String }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lat, lng
        case updatedAt = "updated_at"
        case perfiles
    }
}

private struct UbicacionPayload: Encodable {
    let userId: String
    let lat: Double
    let lng: Double
    let updatedAt: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"; case lat, lng; case updatedAt = "updated_at"
    }
}

@MainActor
final class UbicacionCampoService {
    static let shared = UbicacionCampoService()
    private var client: SupabaseClient { SupabaseService.shared.client }
    private var locationChannel: RealtimeChannelV2?
    private var locationSubInsert: RealtimeSubscription?
    private var locationSubUpdate: RealtimeSubscription?
    private var pollingTask: Task<Void, Never>?
    private init() {}

    func suscribirUbicaciones() -> AsyncStream<[UbicacionActiva]> {
        AsyncStream { continuation in
            Task {
                // Initial fetch
                if let activas = try? await self.fetchActivas() {
                    continuation.yield(activas)
                }

                if let existing = self.locationChannel {
                    await self.client.realtimeV2.removeChannel(existing)
                }
                let channel = self.client.realtimeV2.channel("ubicaciones_campo_live")
                self.locationChannel = channel

                self.locationSubInsert = channel.onPostgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "ubicaciones_campo"
                ) { [weak self] _ in
                    Task {
                        if let activas = try? await self?.fetchActivas() {
                            continuation.yield(activas)
                        }
                    }
                }

                self.locationSubUpdate = channel.onPostgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "ubicaciones_campo"
                ) { [weak self] _ in
                    Task {
                        if let activas = try? await self?.fetchActivas() {
                            continuation.yield(activas)
                        }
                    }
                }

                try? await channel.subscribeWithError()

                // Fallback polling every 30s in case Realtime not enabled on table
                self.pollingTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(30))
                        if Task.isCancelled { break }
                        if let activas = try? await self.fetchActivas() {
                            continuation.yield(activas)
                        }
                    }
                }

                continuation.onTermination = { _ in
                    Task { @MainActor in
                        self.pollingTask?.cancel()
                        self.pollingTask = nil
                        self.locationSubInsert = nil
                        self.locationSubUpdate = nil
                        await self.client.realtimeV2.removeChannel(channel)
                    }
                }
            }
        }
    }

    func actualizar(userId: UUID, coord: CLLocationCoordinate2D) async {
        let fmt = ISO8601DateFormatter()
        let payload = UbicacionPayload(
            userId: userId.uuidString,
            lat: coord.latitude,
            lng: coord.longitude,
            updatedAt: fmt.string(from: Date())
        )
        _ = try? await client.from("ubicaciones_campo").upsert(payload).execute()
    }

    func fetchActivas() async throws -> [UbicacionActiva] {
        let hace10min = Date().addingTimeInterval(-600)
        let fmt = ISO8601DateFormatter()
        return try await client
            .from("ubicaciones_campo")
            .select("user_id, lat, lng, updated_at, perfiles(nombre)")
            .gte("updated_at", value: fmt.string(from: hace10min))
            .execute()
            .value
    }
}
