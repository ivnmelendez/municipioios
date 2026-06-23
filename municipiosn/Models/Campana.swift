import Foundation

struct UsoCampana: Identifiable {
    let id: UUID
    let nombre: String
    let totalEstructuras: Int
    let fotoUrl: String?
}

struct Campana: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let descripcion: String?
    let fechaInicio: Date?
    let fechaFin: Date?
    let activa: Bool
    let categoria: String?
    let fotoUrl: String?
    let anio: Int?

    enum CodingKeys: String, CodingKey {
        case id, nombre, descripcion, activa, categoria, anio
        case fechaInicio = "fecha_inicio"
        case fechaFin = "fecha_fin"
        case fotoUrl = "foto_url"
    }
}

struct Cara: Codable, Identifiable {
    let id: UUID
    let estructuraId: UUID
    let tipo: String
    let estado: String
    let fotoUrl: String?

    var campanaActiva: Campana?

    enum CodingKeys: String, CodingKey {
        case id, tipo, estado
        case estructuraId = "estructura_id"
        case fotoUrl = "foto_url"
    }
}

struct CaraCampana: Codable, Identifiable {
    let id: UUID
    let caraId: UUID
    let campanaId: UUID
    let fechaInicio: Date?
    let fechaFin: Date?
    let activa: Bool

    var campana: Campana?

    enum CodingKeys: String, CodingKey {
        case id, activa
        case caraId = "cara_id"
        case campanaId = "campana_id"
        case fechaInicio = "fecha_inicio"
        case fechaFin = "fecha_fin"
        case campana = "campanas"
    }
}
