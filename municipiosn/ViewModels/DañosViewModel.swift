import Foundation

@Observable
final class DañosViewModel {
    var danos: [IntervencionCompleta] = []
    var filtro: FiltroFecha = .mes
    var isLoading = false
    var error: String?

    func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            danos = try await IntervencionesService.shared.fetchDanos(filtro: filtro)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func aplicarFiltro(_ f: FiltroFecha) async {
        filtro = f
        await cargar()
    }
}
