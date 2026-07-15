import Foundation

enum DashboardCardID: String, Codable, CaseIterable {
    // 1. Alertas urgentes
    case alertaEstructuras   = "alerta_estructuras"
    case avisoCoroplast      = "aviso_coroplast"
    // 2. Actividad del equipo
    case semana              = "semana"
    case cobertura           = "cobertura"
    // 3. Campañas (le preguntan mucho)
    case campanasCard        = "campanas_card"
    // 4. Resumen del municipio
    case resumenMunicipal    = "resumen_municipal"
    // 5. Alcance demográfico
    case alcancePoblacional  = "alcance_poblacional"
    // 6. Detalle estadístico
    case campanasChart       = "campanas_chart"
    case alcanceColonias     = "alcance_colonias"
    case coloniasChart       = "colonias_chart"
    // 7. Pagos
    case pagos               = "pagos"

    var titulo: String {
        switch self {
        case .alertaEstructuras:  "Estructuras con alertas"
        case .avisoCoroplast:     "Avisos coroplast"
        case .semana:             "Esta semana"
        case .cobertura:          "Cobertura mensual"
        case .campanasCard:       "Campañas activas"
        case .resumenMunicipal:   "Datos del municipio"
        case .alcancePoblacional: "Alcance estimado"
        case .campanasChart:      "Estadísticas campañas"
        case .alcanceColonias:    "Alcance por colonia"
        case .coloniasChart:      "Estadísticas colonias"
        case .pagos:              "Gastos mano de obra"
        }
    }

    var icono: String {
        switch self {
        case .alertaEstructuras:  "exclamationmark.triangle.fill"
        case .avisoCoroplast:     "bell.fill"
        case .semana:             "calendar.badge.clock"
        case .cobertura:          "chart.pie.fill"
        case .campanasCard:       "megaphone.fill"
        case .resumenMunicipal:   "building.2.fill"
        case .alcancePoblacional: "person.3.fill"
        case .campanasChart:      "chart.bar.fill"
        case .alcanceColonias:    "map.circle.fill"
        case .coloniasChart:      "map.fill"
        case .pagos:              "banknote.fill"
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
