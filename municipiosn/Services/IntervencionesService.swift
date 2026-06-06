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
        case fotoAntesUrl = "foto_antes_url"
        case fotoDespuesUrl = "foto_despues_url"
        case createdAt = "created_at"
        case estructuras, rondines
    }
}

struct EstructuraResumen: Codable, Identifiable {
    let id: UUID
    let numero: String
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

final class IntervencionesService {
    static let shared = IntervencionesService()
    private let db = SupabaseService.shared.client.database

    private init() {}

    func fetchCambiosRotoplas(filtro: FiltroFecha = .todo) async throws -> [IntervencionCompleta] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let calendar = Calendar.current
        let now = Date()

        let baseQuery = db
            .from("rondines_estructuras")
            .select("""
                *,
                estructuras(id, numero, parques(id, nombre)),
                rondines(id, perfiles(id, nombre, rol))
            """)
            .eq("accion", value: "cambio_rotoplas")

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
