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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        rondinId = try c.decode(UUID.self, forKey: .rondinId)
        estructuraId = try c.decode(UUID.self, forKey: .estructuraId)
        accion = try c.decode(AccionIntervencion.self, forKey: .accion)
        tipoDano = try c.decodeIfPresent(TipoDano.self, forKey: .tipoDano)
        fotoAntesUrl = try c.decodeIfPresent(String.self, forKey: .fotoAntesUrl)
        fotoDespuesUrl = try c.decodeIfPresent(String.self, forKey: .fotoDespuesUrl)
        notas = try c.decodeIfPresent(String.self, forKey: .notas)
        estructuras = try c.decodeIfPresent(EstructuraResumen.self, forKey: .estructuras)
        rondines = try c.decodeIfPresent(RondinConPerfil.self, forKey: .rondines)
        let raw = try c.decode(String.self, forKey: .createdAt)
        createdAt = Self.parseDate(raw) ?? Date()
    }

    private static func parseDate(_ s: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd HH:mm:ssXXXXX"
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
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

    func debugFetchCambios() async throws -> Int {
        struct Row: Decodable { let id: UUID; let accion: String }
        let rows: [Row] = try await client
            .from("rondines_estructuras")
            .select("id, accion")
            .in("accion", values: ["cambio_coroplast", "reparacion_coroplast", "reactivacion"])
            .execute()
            .value
        print("[DEBUG] cambios encontrados: \(rows.count) — \(rows.map(\.accion))")
        return rows.count
    }

    func fetchHistorial(estructuraId: UUID, limit: Int = 8) async throws -> [IntervencionCompleta] {
        try await client
            .from("rondines_estructuras")
            .select(selectFields)
            .eq("estructura_id", value: estructuraId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
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
