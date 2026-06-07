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

struct CaraDetalle: Identifiable {
    let id: UUID
    let tipo: String
    let fotoUrl: String?
    let campana: CampanaDetalle?
    let fotoCampana: String?

    struct CampanaDetalle: Identifiable {
        let id: UUID
        let nombre: String
        let fotoUrl: String?
    }
}

private struct CaraRaw: Codable {
    let id: UUID
    let tipo: String
    let fotoUrl: String?
    let carasCampanas: [CaraCampanaRaw]

    struct CaraCampanaRaw: Codable {
        let activa: Bool
        let fotoUrl: String?
        let campanas: CampanaRaw?

        struct CampanaRaw: Codable {
            let id: UUID
            let nombre: String
            let fotoUrl: String?

            enum CodingKeys: String, CodingKey {
                case id, nombre
                case fotoUrl = "foto_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case activa
            case fotoUrl = "foto_url"
            case campanas
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, tipo
        case fotoUrl = "foto_url"
        case carasCampanas = "caras_campanas"
    }
}

private struct CaraCampanaItem: Codable {
    let campanaId: UUID
    let campanas: CampanaResumen

    struct CampanaResumen: Codable {
        let id: UUID
        let nombre: String
    }

    enum CodingKeys: String, CodingKey {
        case campanaId = "campana_id"
        case campanas
    }
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

    func fetchCarasDetalle(estructuraId: UUID) async throws -> [CaraDetalle] {
        let raw: [CaraRaw] = try await client
            .from("caras")
            .select("id, tipo, foto_url, caras_campanas(activa, foto_url, campanas(id, nombre, foto_url))")
            .eq("estructura_id", value: estructuraId.uuidString)
            .execute()
            .value

        return raw.map { cara in
            let activa = cara.carasCampanas.first(where: { $0.activa })
            return CaraDetalle(
                id: cara.id,
                tipo: cara.tipo,
                fotoUrl: cara.fotoUrl,
                campana: activa?.campanas.map { c in
                    CaraDetalle.CampanaDetalle(id: c.id, nombre: c.nombre, fotoUrl: c.fotoUrl)
                },
                fotoCampana: activa?.fotoUrl
            )
        }
    }

    func fetchCampanaActivaDeCara(caraId: UUID) async throws -> Campana? {
        let result: [CaraCampana] = try await client
            .from("caras_campanas")
            .select("*, campanas(*)")
            .eq("cara_id", value: caraId.uuidString)
            .limit(1)
            .execute()
            .value
        print("🔍 caraId=\(caraId) → \(result.count) registros, campana=\(String(describing: result.first?.campana?.nombre))")
        return result.first?.campana
    }

    func fetchTotalColonias() async throws -> Int {
        let response = try await client
            .from("colonias")
            .select("*", head: true, count: .exact)
            .eq("activo", value: true)
            .execute()
        return response.count ?? 0
    }

    func fetchUsoColonias() async throws -> [UsoColonia] {
        let estructuras = try await fetchEstructuras()
        var counts: [UUID: (nombre: String, count: Int)] = [:]
        for e in estructuras {
            guard let colonia = e.parques?.colonias else { continue }
            counts[colonia.id] = (colonia.nombre, (counts[colonia.id]?.count ?? 0) + 1)
        }
        return counts.map { id, val in
            UsoColonia(id: id, nombre: val.nombre, totalEstructuras: val.count)
        }.sorted { $0.totalEstructuras > $1.totalEstructuras }
    }

    func fetchUsoCampanas() async throws -> [UsoCampana] {
        let items: [CaraCampanaItem] = try await client
            .from("caras_campanas")
            .select("campana_id, campanas(id, nombre)")
            .eq("activa", value: true)
            .execute()
            .value

        var counts: [UUID: (nombre: String, count: Int)] = [:]
        for item in items {
            let id = item.campanas.id
            counts[id] = (item.campanas.nombre, (counts[id]?.count ?? 0) + 1)
        }

        return counts.map { id, val in
            UsoCampana(id: id, nombre: val.nombre, totalCaras: val.count)
        }.sorted { $0.totalCaras > $1.totalCaras }
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
