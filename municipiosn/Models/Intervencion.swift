import Foundation

enum AccionIntervencion: String, Codable {
    case revision
    case cambio_campana
    case reparacion
    case instalacion
    case cambio_coroplast
    case reparacion_coroplast
    case reporte_dano
}

struct Perfil: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let rol: String
}

struct Rondin: Codable, Identifiable {
    let id: UUID
    let fecha: Date?
    let notas: String?
    let createdBy: UUID?

    var perfil: Perfil?

    enum CodingKeys: String, CodingKey {
        case id, fecha, notas
        case createdBy = "created_by"
        case perfil = "perfiles"
    }
}

struct Intervencion: Codable, Identifiable {
    let id: UUID
    let rondinId: UUID
    let estructuraId: UUID
    let accion: AccionIntervencion
    let fotoAntesUrl: String?
    let fotoDespuesUrl: String?
    let notas: String?
    let createdAt: Date

    var estructura: Estructura?
    var rondin: Rondin?

    enum CodingKeys: String, CodingKey {
        case id, accion, notas
        case rondinId = "rondin_id"
        case estructuraId = "estructura_id"
        case fotoAntesUrl = "foto_antes_url"
        case fotoDespuesUrl = "foto_despues_url"
        case createdAt = "created_at"
        case estructura = "estructuras"
        case rondin = "rondines"
    }
}
