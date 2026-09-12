import Foundation

enum AccionIntervencion: String, Codable {
    case revision
    case cambio_campana
    case reparacion
    case instalacion
    case cambio_coroplast
    case reparacion_coroplast
    case reporte_dano
    case reactivacion
    case reporte_mantenimiento
    case mantenimiento_realizado
    case reporte_coroplast

    var etiqueta: String {
        switch self {
        case .revision:               return "Revisión"
        case .cambio_campana:         return "Cambio de campaña"
        case .reparacion:             return "Reparación"
        case .instalacion:            return "Instalación"
        case .cambio_coroplast:       return "Cambio coroplast"
        case .reparacion_coroplast:   return "Reparación coroplast"
        case .reporte_dano:           return "Daño reportado"
        case .reactivacion:           return "Reactivación"
        case .reporte_mantenimiento:  return "Mantenimiento reportado"
        case .mantenimiento_realizado: return "Mantenimiento realizado"
        case .reporte_coroplast:      return "Aviso coroplast"
        }
    }

    var etiquetaCorta: String {
        switch self {
        case .reporte_mantenimiento:   return "Mant. reportado"
        case .mantenimiento_realizado: return "Mant. realizado"
        case .reparacion_coroplast:    return "Rep. coroplast"
        case .cambio_campana:          return "Cambio campaña"
        default: return etiqueta
        }
    }
}

enum TipoDano: String, Codable, CaseIterable {
    case coroplast_roto
    case sin_coroplast
    case destruida

    var label: String {
        switch self {
        case .coroplast_roto: return "Coroplast roto"
        case .sin_coroplast: return "Sin coroplast"
        case .destruida: return "Destruida"
        }
    }

    var estadoResultante: EstadoEstructura {
        self == .destruida ? .destruida : .dañada
    }
}

struct Perfil: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let rol: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, rol
        case avatarUrl = "avatar_url"
    }
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
