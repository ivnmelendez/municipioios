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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let e = EstructurasService.shared.fetchEstructuras()
            async let c = CoroplastService.shared.fetchCampanasActivas()
            (estructuras, campanas) = try await (e, c)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
