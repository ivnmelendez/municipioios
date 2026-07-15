import Foundation
import Supabase

enum FiltroFecha: Equatable {
    case semana, mes, todo
    case mesElegido(Date)

    static func == (lhs: FiltroFecha, rhs: FiltroFecha) -> Bool {
        switch (lhs, rhs) {
        case (.semana, .semana), (.mes, .mes), (.todo, .todo): return true
        case (.mesElegido(let a), .mesElegido(let b)):
            return Calendar.current.isDate(a, equalTo: b, toGranularity: .month)
        default: return false
        }
    }

    var cacheKey: String {
        switch self {
        case .semana:          return "semana"
        case .mes:             return "mes"
        case .todo:            return "todo"
        case .mesElegido(let d):
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
            return "mes_\(fmt.string(from: d))"
        }
    }
}

struct IntervencionCompleta: Codable, Identifiable, Hashable {
    static func == (lhs: IntervencionCompleta, rhs: IntervencionCompleta) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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

    func fetchTodasIntervencionesDelPeriodo(filtro: FiltroFecha) async throws -> [IntervencionCompleta] {
        let acciones = ["cambio_coroplast", "reparacion_coroplast", "reporte_dano",
                        "reactivacion", "reparacion", "reporte_mantenimiento",
                        "mantenimiento_realizado", "reporte_coroplast"]
        return try await fetchIntervenciones(acciones: acciones, filtro: filtro)
    }

    func fetchIntervencionesDelDia(fecha: Date, estructuraIds: [UUID]) async throws -> [IntervencionCompleta] {
        guard !estructuraIds.isEmpty else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Monterrey")!
        let start = cal.startOfDay(for: fecha)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let all: [IntervencionCompleta] = try await client
            .from("rondines_estructuras")
            .select(selectFields)
            .in("estructura_id", values: estructuraIds.map { $0.uuidString })
            .gte("created_at", value: fmt.string(from: start))
            .lt("created_at", value: fmt.string(from: end))
            .order("created_at", ascending: false)
            .execute()
            .value
        let excluidas: Set<String> = ["revision", "cambio_campana", "instalacion"]
        return all.filter { !excluidas.contains($0.accion.rawValue) }
    }

    func fetchHistorial(estructuraId: UUID) async throws -> [IntervencionCompleta] {
        let accionesExcluidas = ["revision", "cambio_campana", "instalacion"]
        let all: [IntervencionCompleta] = try await client
            .from("rondines_estructuras")
            .select(selectFields)
            .eq("estructura_id", value: estructuraId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return all.filter { !accionesExcluidas.contains($0.accion.rawValue) }
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
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "America/Monterrey")!
            cal.firstWeekday = 2
            let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
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
        case .mesElegido(let fecha):
            let comps = calendar.dateComponents([.year, .month], from: fecha)
            let start = calendar.date(from: comps)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return try await baseQuery
                .gte("created_at", value: formatter.string(from: start))
                .lt("created_at", value: formatter.string(from: end))
                .order("created_at", ascending: false)
                .execute().value
        }
    }
}
