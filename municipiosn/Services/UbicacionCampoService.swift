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

final class UbicacionCampoService {
    static let shared = UbicacionCampoService()
    private var client: SupabaseClient { SupabaseService.shared.client }
    private init() {}

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
