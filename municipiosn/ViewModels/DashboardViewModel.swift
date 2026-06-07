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
        } catch {
            errorMessage = error.localizedDescription
            print("❌ DashboardViewModel error: \(error)")
            if let decoding = error as? DecodingError {
                switch decoding {
                case .keyNotFound(let key, let ctx):
                    print("  keyNotFound: '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue))")
                case .valueNotFound(let type, let ctx):
                    print("  valueNotFound: \(type) at \(ctx.codingPath.map(\.stringValue))")
                case .typeMismatch(let type, let ctx):
                    print("  typeMismatch: \(type) at \(ctx.codingPath.map(\.stringValue))")
                case .dataCorrupted(let ctx):
                    print("  dataCorrupted: \(ctx.debugDescription)")
                @unknown default: break
                }
            }
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
