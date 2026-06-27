import Foundation
import SwiftUI

@MainActor
@Observable
final class CampoViewModel {
    var estructuras: [EstructuraConParque] = []
    var campanas: [CampanaBasica] = []
    var isLoading = false
    var errorMessage: String?
    var busqueda: String = ""

    var estructurasFiltradas: [EstructuraConParque] {
        guard !busqueda.isEmpty else { return estructuras }
        let q = busqueda.lowercased()
        return estructuras.filter {
            $0.numero.lowercased().contains(q)
            || ($0.numeroLocal?.lowercased().contains(q) ?? false)
            || ($0.parques?.nombre.lowercased().contains(q) ?? false)
            || ($0.parques?.colonias?.nombre.lowercased().contains(q) ?? false)
        }
    }

    func cargar() async {
        // Serve cached data immediately — UI usable even offline
        if campanas.isEmpty, let cached = LocalDataCache.shared.cargar([CampanaBasica].self, clave: "campanas") {
            campanas = cached
        }
        if estructuras.isEmpty, let cached = LocalDataCache.shared.cargar([EstructuraConParque].self, clave: "estructuras_campo") {
            estructuras = cached
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let e = EstructurasService.shared.fetchEstructuras()
            async let c = EstructurasService.shared.fetchCampanasActivas()
            let (nuevasE, nuevasC) = try await (e, c)
            estructuras = nuevasE
            campanas = nuevasC
            LocalDataCache.shared.guardar(nuevasE, clave: "estructuras_campo")
            LocalDataCache.shared.guardar(nuevasC, clave: "campanas")
        } catch {
            if estructuras.isEmpty && campanas.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
