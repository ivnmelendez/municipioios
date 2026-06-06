import Foundation

@MainActor
@Observable
final class IntervencionesViewModel {
    var intervenciones: [IntervencionCompleta] = []
    var filtro: FiltroFecha = .mes
    var errorMessage: String?
    var isLoading = false
    var badgeCount: Int = 0

    func cargar() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            intervenciones = try await IntervencionesService.shared.fetchCambiosRotoplas(filtro: filtro)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func aplicarFiltro(_ nuevoFiltro: FiltroFecha) async {
        filtro = nuevoFiltro
        await cargar()
    }

    func limpiarBadge() {
        badgeCount = 0
    }
}
