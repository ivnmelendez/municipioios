import Foundation

struct UsoColonia: Identifiable {
    let id: UUID
    let nombre: String
    let totalEstructuras: Int
}

struct ColoniaAlcance: Identifiable {
    let id: UUID
    let nombre: String
    let estructuras: Int
    let poblacion: Int
    let pobFem: Int
    let pobMas: Int
    let p18ymas: Int
    let pob0a14: Int
    let pob15a64: Int
    let p60ymas: Int
}

struct DemografiaAlcance {
    // Pirámide de edad (F=femenino, M=masculino)
    var p0a5F = 0;  var p0a5M = 0
    var p6a11F = 0; var p6a11M = 0
    var p12a17F = 0; var p12a17M = 0
    var p18a24F = 0; var p18a24M = 0
    var p25a59F = 0; var p25a59M = 0
    var p60masF = 0; var p60masM = 0
    // Segmentos
    var pob0a14 = 0; var pob15a64 = 0; var p60ymas = 0
    // Servicios
    var psinder = 0; var pderSS = 0
    var vphInter = 0; var vphSinInter = 0; var tvivhab = 0
}

struct ColoniaConCampanas: Identifiable {
    let id: UUID
    let nombre: String
    let totalEstructuras: Int
    let campanas: [CampanaEnColonia]
}

struct CampanaEnColonia: Identifiable {
    let id: UUID
    let nombre: String
    let totalCaras: Int
    let fotoUrl: String?
}

enum EstadoEstructura: String, Codable, CaseIterable {
    case activa
    case dañada
    case destruida
    case en_reparacion
    case inactiva
    case necesita_mantenimiento
}

struct Estructura: Codable, Identifiable {
    let id: UUID
    let numero: String
    let numeroLocal: String?
    let parqueId: UUID
    let lat: Double?
    let lng: Double?
    let estado: EstadoEstructura
    let fotoUrl: String?
    let notas: String?
    let fechaInstalacion: Date?

    var parque: Parque?

    enum CodingKeys: String, CodingKey {
        case id, numero, estado, lat, lng, notas, parque
        case numeroLocal = "numero_local"
        case parqueId = "parque_id"
        case fotoUrl = "foto_url"
        case fechaInstalacion = "fecha_instalacion"
    }
}

struct Parque: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let coloniaId: UUID
    let lat: Double?
    let lng: Double?
    let activo: Bool

    var colonia: Colonia?

    enum CodingKeys: String, CodingKey {
        case id, nombre, lat, lng, activo, colonia
        case coloniaId = "colonia_id"
    }
}

struct Colonia: Codable, Identifiable, Hashable {
    let id: UUID
    let nombre: String
    let activo: Bool
}
