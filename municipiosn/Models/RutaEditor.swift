import Foundation
import UIKit

struct RutaEditorItem: Identifiable, Equatable {
    let id: UUID          // rutas_estructuras.id (junction row)
    var orden: Int
    let estructura: EstructuraConParque
}

struct PinInfo {
    let color: UIColor
    let opacity: CGFloat  // 1.0 = active route, 0.3 = other route, 0.5 = unassigned
}

struct RutaJunction: Codable {
    let id: UUID
    let rutaSemanaId: UUID
    let estructuraId: UUID
    let orden: Int

    enum CodingKeys: String, CodingKey {
        case id, orden
        case rutaSemanaId = "ruta_semana_id"
        case estructuraId = "estructura_id"
    }
}
