import Foundation

enum DashboardCardID: String, Codable, CaseIterable {
    // 1. Alertas urgentes
    case alertaEstructuras   = "alerta_estructuras"
    case avisoCoroplast      = "aviso_coroplast"
    // 2. Dinero
    case pagos               = "pagos"
    // 3. Progreso
    case cobertura           = "cobertura"
    case campanasCard        = "campanas_card"
    // 4. Actividad
    case semana              = "semana"
    case ultimasEstructuras  = "ultimas_estructuras"
    // 5. Contexto / análisis
    case resumenMunicipal    = "resumen_municipal"
    case campanasChart       = "campanas_chart"
    case coloniasChart       = "colonias_chart"
    // 6. Alcance demográfico (oculto por defecto)
    case alcancePoblacional  = "alcance_poblacional"
    case alcanceColonias     = "alcance_colonias"

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
        case .ultimasEstructuras: "Últimas estructuras"
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
        case .ultimasEstructuras: "clock.fill"
        }
    }
}

struct DashboardCardItem: Codable, Identifiable, Equatable {
    var id: DashboardCardID
    var activa: Bool

    private static let defaultsOff: Set<DashboardCardID> = [.alcancePoblacional, .alcanceColonias, .ultimasEstructuras]

    static let defaults: [DashboardCardItem] = DashboardCardID.allCases.map {
        DashboardCardItem(id: $0, activa: !defaultsOff.contains($0))
    }
}
