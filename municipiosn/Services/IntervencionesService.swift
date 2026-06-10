import Foundation
import Supabase

enum FiltroFecha {
    case semana, mes, todo
}

struct IntervencionCompleta: Codable, Identifiable {
    let id: UUID
    let rondinId: UUID
    let estructuraId: UUID
    let accion: AccionIntervencion
    let tipoDano: TipoDano?
    let fotoAntesUrl: String?
    let fotoDespuesUrl: String?
    let notas: String?
    let createdAt: Date
    let estructuras: EstructuraResumen?
    let rondines: RondinConPerfil?

    enum CodingKeys: String, CodingKey {
        case id, accion, notas
        case rondinId = "rondin_id"
        case estructuraId = "estructura_id"
        case tipoDano = "tipo_dano"
        case fotoAntesUrl = "foto_antes_url"
        case fotoDespuesUrl = "foto_despues_url"
        case createdAt = "created_at"
        case estructuras, rondines
    }
}

struct EstructuraResumen: Codable, Identifiable {
    let id: UUID
    let numero: String
    let estado: EstadoEstructura?
    let parques: ParqueResumen?
}

struct ParqueResumen: Codable, Identifiable {
    let id: UUID
    let nombre: String
}

struct RondinConPerfil: Codable, Identifiable {
    let id: UUID
    let perfiles: Perfil?
}

private let selectFields = """
    *,
    estructuras(id, numero, estado, parques(id, nombre)),
    rondines(id, perfiles(id, nombre, rol))
"""

final class IntervencionesService {
    static let shared = IntervencionesService()
    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchCambiosRotoplas(filtro: FiltroFecha = .todo) async throws -> [IntervencionCompleta] {
        let acciones = ["cambio_coroplast", "reparacion_coroplast", "reactivacion"]
        return try await fetchIntervenciones(acciones: acciones, filtro: filtro)
    }

    func fetchDanos(filtro: FiltroFecha = .todo) async throws -> [IntervencionCompleta] {
        return try await fetchIntervenciones(acciones: ["reporte_dano"], filtro: filtro)
    }

    private func fetchIntervenciones(acciones: [String], filtro: FiltroFecha) async throws -> [IntervencionCompleta] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let calendar = Calendar.current
        let now = Date()

        let baseQuery = client
            .from("rondines_estructuras")
            .select(selectFields)
            .in("accion", values: acciones)

        switch filtro {
        case .semana:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return try await baseQuery
                .gte("created_at", value: formatter.string(from: start))
                .order("created_at", ascending: false)
                .execute().value
        case .mes:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return try await baseQuery
                .gte("created_at", value: formatter.string(from: start))
                .order("created_at", ascending: false)
                .execute().value
        case .todo:
            return try await baseQuery
                .order("created_at", ascending: false)
                .execute().value
        }
    }
}
