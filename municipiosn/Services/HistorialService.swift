import Foundation
import Supabase

struct EstructuraVisitada: Identifiable {
    let id: UUID
    let numero: String
    let parque: String?
    let colonia: String?
}

struct DiaVisita: Identifiable {
    let id: String
    let fecha: Date
    let estructuras: [EstructuraVisitada]
}

final class HistorialService {
    static let shared = HistorialService()
    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    // userId nil = all workers (admin view)
    func fetchDias(userId: UUID? = nil, desde: Date, hasta: Date) async throws -> [DiaVisita] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let desdeStr = formatter.string(from: desde)
        let hastaStr = formatter.string(from: hasta)

        struct RondinRaw: Codable {
            let id: UUID
            let fecha: String
            let rondinEstructuras: [RondinEstructuraRaw]

            enum CodingKeys: String, CodingKey {
                case id, fecha
                case rondinEstructuras = "rondines_estructuras"
            }
        }

        struct RondinEstructuraRaw: Codable {
            let estructuras: EstructuraRaw?

            enum CodingKeys: String, CodingKey {
                case estructuras
            }
        }

        struct EstructuraRaw: Codable {
            let id: UUID
            let numero: String
            let parques: ParqueRaw?

            enum CodingKeys: String, CodingKey {
                case id, numero, parques
            }
        }

        struct ParqueRaw: Codable {
            let nombre: String
            let colonias: ColoniaRaw?

            enum CodingKeys: String, CodingKey {
                case nombre, colonias
            }
        }

        struct ColoniaRaw: Codable {
            let nombre: String
        }

        var query = client
            .from("rondines")
            .select("id, fecha, rondines_estructuras(estructuras(id, numero, parques(nombre, colonias(nombre))))")
            .gte("fecha", value: desdeStr)
            .lte("fecha", value: hastaStr)

        if let userId {
            query = query.eq("created_by", value: userId.uuidString)
        }

        let rondines: [RondinRaw] = try await query
            .order("fecha", ascending: false)
            .execute()
            .value

        var porFecha: [String: [EstructuraVisitada]] = [:]
        for rondin in rondines {
            var visitadas = porFecha[rondin.fecha] ?? []
            for re in rondin.rondinEstructuras {
                guard let e = re.estructuras else { continue }
                let ev = EstructuraVisitada(
                    id: e.id,
                    numero: e.numero,
                    parque: e.parques?.nombre,
                    colonia: e.parques?.colonias?.nombre
                )
                if !visitadas.contains(where: { $0.id == ev.id }) {
                    visitadas.append(ev)
                }
            }
            porFecha[rondin.fecha] = visitadas
        }

        return porFecha.compactMap { fechaStr, estructuras -> DiaVisita? in
            guard let date = formatter.date(from: fechaStr) else { return nil }
            return DiaVisita(id: fechaStr, fecha: date, estructuras: estructuras)
        }
        .sorted { $0.fecha > $1.fecha }
    }
}
