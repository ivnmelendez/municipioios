import Foundation
import Supabase

struct EstructuraConParque: Codable, Identifiable {
    let id: UUID
    let numero: String
    let numeroLocal: String?
    let parqueId: UUID?
    let lat: Double?
    let lng: Double?
    let estado: EstadoEstructura
    let fotoUrl: String?
    let notas: String?
    let fechaInstalacion: Date?
    let parques: ParqueConColonia?

    enum CodingKeys: String, CodingKey {
        case id, numero, estado, lat, lng, notas
        case numeroLocal = "numero_local"
        case parqueId = "parque_id"
        case fotoUrl = "foto_url"
        case fechaInstalacion = "fecha_instalacion"
        case parques
    }
}

struct ParqueConColonia: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let colonias: Colonia?
}

final class EstructurasService {
    static let shared = EstructurasService()
    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchEstructuras() async throws -> [EstructuraConParque] {
        try await client
            .from("estructuras")
            .select("*, parques(id, nombre, colonias(id, nombre, activo))")
            .execute()
            .value
    }

    func fetchKPIs() async throws -> KPIData {
        async let estructuras: [EstructuraConParque] = fetchEstructuras()
        async let campanas: [Campana] = client
            .from("campanas")
            .select()
            .eq("activa", value: true)
            .execute()
            .value
        async let rotoplas: [Intervencion] = fetchCambiosRotoplasEsteMes()

        let (e, c, r) = try await (estructuras, campanas, rotoplas)

        var kpi = KPIData()
        kpi.totalEstructuras = e.count
        kpi.activas = e.filter { $0.estado == .activa }.count
        kpi.dañadas = e.filter { $0.estado == .dañada }.count
        kpi.enReparacion = e.filter { $0.estado == .en_reparacion }.count
        kpi.inactivas = e.filter { $0.estado == .inactiva }.count
        kpi.campanasActivas = c.count
        kpi.cambiosRotoplasEsteMes = r.count
        kpi.isLoaded = true
        return kpi
    }

    func fetchCaras(estructuraId: UUID) async throws -> [Cara] {
        try await client
            .from("caras")
            .select()
            .eq("estructura_id", value: estructuraId.uuidString)
            .execute()
            .value
    }

    func fetchCampanaActivaDeCara(caraId: UUID) async throws -> Campana? {
        let result: [CaraCampana] = try await client
            .from("caras_campanas")
            .select("*, campanas(*)")
            .eq("cara_id", value: caraId.uuidString)
            .eq("activa", value: true)
            .limit(1)
            .execute()
            .value
        return result.first?.campana
    }

    private func fetchCambiosRotoplasEsteMes() async throws -> [Intervencion] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let isoStart = formatter.string(from: startOfMonth)

        return try await client
            .from("rondines_estructuras")
            .select()
            .eq("accion", value: "cambio_rotoplas")
            .gte("created_at", value: isoStart)
            .execute()
            .value
    }
}
