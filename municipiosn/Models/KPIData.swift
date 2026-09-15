import Foundation

struct CoberturaMensual: Identifiable, Hashable {
    let año: Int
    let mes: Int  // 1–12
    let visitadas: Int
    let total: Int

    var id: String { "\(año)-\(mes)" }
    var porcentaje: Double { total > 0 ? min(Double(visitadas) / Double(total), 1.0) : 0 }
    var completo: Bool { total > 0 && visitadas >= total }
    var enCurso: Bool {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.year, from: now) == año && cal.component(.month, from: now) == mes
    }
}

struct KPIData: Codable {
    var totalEstructuras: Int = 0
    var activas: Int = 0
    var dañadas: Int = 0
    var enReparacion: Int = 0
    var inactivas: Int = 0
    var necesitaMantenimiento: Int = 0
    var campanasActivas: Int = 0
    var coroplastMes: Int = 0
    var visitasSemana: Int = 0
    var cambiosSemana: Int = 0
    var danosSemana: Int = 0
    var visitasMes: Int = 0
    var danosMes: Int = 0

    var sinCoroplast: Int = 0
    var coroplastRoto: Int = 0
    var isLoaded: Bool = false
}
