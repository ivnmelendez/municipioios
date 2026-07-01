import Foundation

@Observable
final class HistorialViewModel {
    var diasSemana: [DiaVisita] = []
    var diasMes: [DiaVisita] = []
    var diasMesElegido: [DiaVisita] = []
    var cargando = false
    var error: String?

    func cargar(userId: UUID? = nil) async {
        if diasSemana.isEmpty, let cached = LocalDataCache.shared.cargar([DiaVisita].self, clave: "historial_semana") {
            diasSemana = cached
        }
        if diasMes.isEmpty, let cached = LocalDataCache.shared.cargar([DiaVisita].self, clave: "historial_mes") {
            diasMes = cached
        }

        cargando = true
        error = nil
        let calendar = Calendar.current
        let hoy = Date()
        let inicioSemana = calendar.dateInterval(of: .weekOfYear, for: hoy)?.start ?? hoy
        let inicioMes = calendar.dateInterval(of: .month, for: hoy)?.start ?? hoy

        do {
            async let semana = HistorialService.shared.fetchDias(userId: userId, desde: inicioSemana, hasta: hoy)
            async let mes = HistorialService.shared.fetchDias(userId: userId, desde: inicioMes, hasta: hoy)
            let (s, m) = try await (semana, mes)
            diasSemana = s
            diasMes = m
            LocalDataCache.shared.guardar(s, clave: "historial_semana")
            LocalDataCache.shared.guardar(m, clave: "historial_mes")
        } catch {
            self.error = error.localizedDescription
        }
        cargando = false
    }

    func cargarMesElegido(fecha: Date) async {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: fecha)
        let start = calendar.date(from: comps)!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        cargando = true
        do {
            diasMesElegido = try await HistorialService.shared.fetchDias(userId: nil, desde: start, hasta: end)
        } catch {
            self.error = error.localizedDescription
        }
        cargando = false
    }
}
