import Foundation

enum DashboardCardID: String, Codable, CaseIterable {
    case cobertura        = "cobertura"
    case semana           = "semana"
    case resumenMunicipal = "resumen_municipal"
    case campanasChart    = "campanas_chart"
    case coloniasChart    = "colonias_chart"
    case pagos            = "pagos"

    var titulo: String {
        switch self {
        case .cobertura:        "Cobertura mensual"
        case .semana:           "Esta semana"
        case .resumenMunicipal: "Datos del municipio"
        case .campanasChart:    "Estadísticas campañas"
        case .coloniasChart:    "Estadísticas colonias"
        case .pagos:            "Gastos mano de obra"
        }
    }

    var icono: String {
        switch self {
        case .cobertura:        "chart.pie.fill"
        case .semana:           "calendar.badge.clock"
        case .resumenMunicipal: "building.2.fill"
        case .campanasChart:    "megaphone.fill"
        case .coloniasChart:    "map.fill"
        case .pagos:            "banknote.fill"
        }
    }
}

struct DashboardCardItem: Codable, Identifiable, Equatable {
    var id: DashboardCardID
    var activa: Bool

    static let defaults: [DashboardCardItem] = DashboardCardID.allCases.map {
        DashboardCardItem(id: $0, activa: true)
    }
}
