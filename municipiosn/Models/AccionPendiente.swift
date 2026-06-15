import Foundation

struct AccionPendiente: Codable, Identifiable {
    enum Tipo: String, Codable {
        case revision
        case reparacionCoroplast
        case cambioCoroplast
        case reporteDano
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
    let estadoEstructura: String?  // solo cambioCoroplast — para auto-resolver si ya reparada
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
        estadoEstructura: String? = nil,
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
        self.estadoEstructura = estadoEstructura
        self.caras = caras
        self.fotoAntesData = fotoAntesData
        self.fotoDespuesData = fotoDespuesData
        self.notas = notas
        self.fechaCreacion = Date()
        self.intentos = 0
    }
}
