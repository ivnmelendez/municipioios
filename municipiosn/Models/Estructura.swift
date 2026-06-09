import Foundation

struct UsoColonia: Identifiable {
    let id: UUID
    let nombre: String
    let totalEstructuras: Int
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
