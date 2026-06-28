import Foundation

struct AccionPendiente: Codable, Identifiable {
    enum Tipo: String, Codable {
        case revision
        case reparacionCoroplast
        case cambioCoroplast
        case reporteDano
        case reporteMantenimiento
        case mantenimientoRealizado
    }

    struct CaraPendiente: Codable {
        let caraId: UUID
        let campanaId: UUID
    }

    let id: UUID
    let tipo: Tipo
    let estructuraId: UUID
    let rutaSemanaId: UUID?
    let userId: UUID
    let caras: [CaraPendiente]?    // solo cambioCoroplast
    let fotoAntesData: Data?
    let fotoDespuesData: Data?
    let notas: String?
    let fechaCreacion: Date
    var intentos: Int

    init(
        tipo: Tipo,
        estructuraId: UUID,
        rutaSemanaId: UUID?,
        userId: UUID,
        caras: [CaraPendiente]? = nil,
        fotoAntesData: Data? = nil,
        fotoDespuesData: Data? = nil,
        notas: String? = nil
    ) {
        self.id = UUID()
        self.tipo = tipo
        self.estructuraId = estructuraId
        self.rutaSemanaId = rutaSemanaId
        self.userId = userId
        self.caras = caras
        self.fotoAntesData = fotoAntesData
        self.fotoDespuesData = fotoDespuesData
        self.notas = notas
        self.fechaCreacion = Date()
        self.intentos = 0
    }
}
