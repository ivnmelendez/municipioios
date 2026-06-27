import Foundation

@MainActor
@Observable
final class IntervencionesViewModel {
    var intervenciones: [IntervencionCompleta] = []
    var filtro: FiltroFecha = .mes
    var errorMessage: String?
    var isLoading = false

    func cargar() async {
        guard !isLoading else { return }

        let claveCache = "intervenciones_\(filtro)"
        if intervenciones.isEmpty, let cached = LocalDataCache.shared.cargar([IntervencionCompleta].self, clave: claveCache) {
            intervenciones = cached
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let nuevas = try await IntervencionesService.shared.fetchCambiosRotoplas(filtro: filtro)
            intervenciones = nuevas
            LocalDataCache.shared.guardar(nuevas, clave: claveCache)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func aplicarFiltro(_ nuevoFiltro: FiltroFecha) async {
        filtro = nuevoFiltro
        intervenciones = []
        await cargar()
    }
}
