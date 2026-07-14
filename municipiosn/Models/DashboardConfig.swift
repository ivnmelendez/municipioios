import Foundation

enum DashboardCardID: String, Codable, CaseIterable {
    case alertaEstructuras = "alerta_estructuras"
    case avisoCoroplast    = "aviso_coroplast"
    case cobertura        = "cobertura"
    case semana           = "semana"
    case resumenMunicipal = "resumen_municipal"
    case campanasChart    = "campanas_chart"
    case coloniasChart    = "colonias_chart"
    case pagos            = "pagos"
    case alcancePoblacional = "alcance_poblacional"
    case alcanceColonias    = "alcance_colonias"
    case piramideEdad       = "piramide_edad"
    case sinInternet        = "sin_internet"
    case segmentosPorColonia = "segmentos_colonia"
    case seguroMedico        = "seguro_medico"

    var titulo: String {
        switch self {
        case .alertaEstructuras:  "Estructuras con alertas"
        case .avisoCoroplast:     "Avisos coroplast"
        case .cobertura:          "Cobertura mensual"
        case .semana:             "Esta semana"
        case .resumenMunicipal:   "Datos del municipio"
        case .campanasChart:      "Estadísticas campañas"
        case .coloniasChart:      "Estadísticas colonias"
        case .pagos:              "Gastos mano de obra"
        case .alcancePoblacional:   "Alcance estimado"
        case .alcanceColonias:      "Alcance por colonia"
        case .piramideEdad:         "Pirámide de edad"
        case .sinInternet:          "Conectividad digital"
        case .segmentosPorColonia:  "Segmentos por colonia"
        case .seguroMedico:         "Acceso a salud"
        }
    }

    var icono: String {
        switch self {
        case .alertaEstructuras:    "exclamationmark.triangle.fill"
        case .avisoCoroplast:       "bell.fill"
        case .cobertura:            "chart.pie.fill"
        case .semana:               "calendar.badge.clock"
        case .resumenMunicipal:     "building.2.fill"
        case .campanasChart:        "megaphone.fill"
        case .coloniasChart:        "map.fill"
        case .pagos:                "banknote.fill"
        case .alcancePoblacional:   "person.3.fill"
        case .alcanceColonias:      "map.circle.fill"
        case .piramideEdad:         "chart.bar.xaxis"
        case .sinInternet:          "wifi.slash"
        case .segmentosPorColonia:  "chart.bar.fill"
        case .seguroMedico:         "cross.circle.fill"
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
