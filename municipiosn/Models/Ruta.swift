import Foundation

struct RutaSemana: Codable, Identifiable {
    let id: UUID
    let numero: Int
    let color: String
    let generadoAt: Date

    enum CodingKeys: String, CodingKey {
        case id, numero, color
        case generadoAt = "generado_at"
    }
}

struct RutaEstructuraItem: Identifiable {
    let id: UUID
    let orden: Int
    let estructura: EstructuraConParque
    var visitada: Bool
}
