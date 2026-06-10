import Foundation
import Supabase

private struct RutaEstructuraRaw: Codable {
    let id: UUID
    let orden: Int
    let estructuras: EstructuraConParque

    enum CodingKeys: String, CodingKey {
        case id, orden
        case estructuras = "estructuras"
    }
}

private struct VisitaHoy: Codable {
    let estructuraId: UUID

    enum CodingKeys: String, CodingKey {
        case estructuraId = "estructura_id"
    }
}

final class RutasService {
    static let shared = RutasService()
    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchSemanasRecientes() async throws -> [RutaSemana] {
        let todas: [RutaSemana] = try await client
            .from("rutas_semanas")
            .select("id, numero, color, generado_at")
            .order("generado_at", ascending: false)
            .execute()
            .value

        var vistas: Set<Int> = []
        var resultado: [RutaSemana] = []
        for semana in todas {
            if !vistas.contains(semana.numero) {
                vistas.insert(semana.numero)
                resultado.append(semana)
            }
        }
        return resultado.sorted { $0.numero < $1.numero }
    }

    func fetchEstructurasEnRuta(rutaSemanaId: UUID, userId: UUID) async throws -> [RutaEstructuraItem] {
        let raw: [RutaEstructuraRaw] = try await client
            .from("rutas_estructuras")
            .select("id, orden, estructuras(*, parques(id, nombre, colonias(id, nombre, activo)))")
            .eq("ruta_semana_id", value: rutaSemanaId.uuidString)
            .order("orden", ascending: true)
            .execute()
            .value

        let estructuraIds = raw.map { $0.estructuras.id.uuidString }
        guard !estructuraIds.isEmpty else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let hoy = formatter.string(from: Date())

        let visitas: [VisitaHoy] = try await client
            .from("rondines_estructuras")
            .select("estructura_id, rondines!inner(created_by, fecha)")
            .eq("rondines.created_by", value: userId.uuidString)
            .eq("rondines.fecha", value: hoy)
            .in("estructura_id", values: estructuraIds)
            .execute()
            .value

        let visitadasIds = Set(visitas.map { $0.estructuraId })

        return raw.map { item in
            RutaEstructuraItem(
                id: item.id,
                orden: item.orden,
                estructura: item.estructuras,
                visitada: visitadasIds.contains(item.estructuras.id)
            )
        }
    }

    func fetchEstructuraSemanaMap() async throws -> [UUID: RutaSemana] {
        let semanas = try await fetchSemanasRecientes()
        guard !semanas.isEmpty else { return [:] }
        let semanaById = Dictionary(uniqueKeysWithValues: semanas.map { ($0.id, $0) })

        struct Link: Codable {
            let estructuraId: UUID
            let rutaSemanaId: UUID
            enum CodingKeys: String, CodingKey {
                case estructuraId = "estructura_id"
                case rutaSemanaId = "ruta_semana_id"
            }
        }

        let links: [Link] = try await client
            .from("rutas_estructuras")
            .select("estructura_id, ruta_semana_id")
            .in("ruta_semana_id", values: semanas.map { $0.id.uuidString })
            .execute()
            .value

        var result: [UUID: RutaSemana] = [:]
        for link in links {
            if let semana = semanaById[link.rutaSemanaId] {
                result[link.estructuraId] = semana
            }
        }
        return result
    }

    func marcarRevision(estructuraId: UUID, rutaSemanaId: UUID, userId: UUID) async throws {
        try await CoroplastService.shared.registrarRevision(
            estructuraId: estructuraId,
            rutaSemanaId: rutaSemanaId,
            userId: userId
        )
    }
}
