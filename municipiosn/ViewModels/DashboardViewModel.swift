import Foundation
import CoreLocation

@MainActor
@Observable
final class DashboardViewModel {
    var kpi = KPIData()
    var usoCampanas: [UsoCampana] = []
    var usoColonias: [UsoColonia] = []
    var coloniasConEstructuras: Int = 0
    var coloniasSinEstructuras: Int = 0
    var totalColoniasGeo: Int = 0
    var coloniasDetalle: [ColoniaConCampanas] = []
    var errorMessage: String?
    var isLoading = false

    func cargar() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let kpiTask = EstructurasService.shared.fetchKPIs()
            async let campanasTask = EstructurasService.shared.fetchUsoCampanas()
            async let coloniasTask = EstructurasService.shared.fetchUsoColonias()
            async let estructurasTask = EstructurasService.shared.fetchEstructuras()
            async let coloniasDetalleTask = EstructurasService.shared.fetchColoniasConCampanas()

            kpi = try await kpiTask
            usoCampanas = (try? await campanasTask) ?? []
            usoColonias = (try? await coloniasTask) ?? []
            let estructuras = (try? await estructurasTask) ?? []
            coloniasDetalle = (try? await coloniasDetalleTask) ?? []

            computarCobertura(estructuras: estructuras)
        } catch is CancellationError {
            // View disappeared before load completed — normal, ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computarCobertura(estructuras: [EstructuraConParque]) {
        let polygons = loadGeoPolygons(named: "colonias_san_nicolas")
        let coords = estructuras.compactMap { e -> CLLocationCoordinate2D? in
            guard let lat = e.lat, let lng = e.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        var conEstructura = Set<String>()
        for polygon in polygons where !polygon.cvegeo.isEmpty {
            for coord in coords {
                if pointInPolygon(coord, polygon.coordinates) {
                    conEstructura.insert(polygon.cvegeo)
                    break
                }
            }
        }

        totalColoniasGeo = polygons.filter { !$0.cvegeo.isEmpty }.count
        coloniasConEstructuras = conEstructura.count
        coloniasSinEstructuras = totalColoniasGeo - coloniasConEstructuras
    }
}
