import Foundation
import CoreLocation
import SwiftUI

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

    var cardConfig: [DashboardCardItem] = DashboardCardItem.defaults
    private var configUserId: UUID?
    private var saveTask: Task<Void, Never>?

    func cargarConfig(userId: UUID) async {
        configUserId = userId
        cardConfig = await DashboardConfigService.shared.fetch(userId: userId)
    }

    func toggleCard(_ id: DashboardCardID) {
        guard let idx = cardConfig.firstIndex(where: { $0.id == id }) else { return }
        cardConfig[idx].activa.toggle()
        programarGuardado()
    }

    func moverCard(from: IndexSet, to: Int) {
        cardConfig.move(fromOffsets: from, toOffset: to)
        programarGuardado()
    }

    private func programarGuardado() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, let userId = self.configUserId else { return }
            await DashboardConfigService.shared.save(userId: userId, config: self.cardConfig)
        }
    }

    func cargar() async {
        guard !isLoading else { return }

        if !kpi.isLoaded, let cached = LocalDataCache.shared.cargar(KPIData.self, clave: "dashboard_kpi") {
            kpi = cached
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let kpiTask = EstructurasService.shared.fetchKPIs()
            async let campanasTask = EstructurasService.shared.fetchUsoCampanas()
            async let coloniasTask = EstructurasService.shared.fetchUsoColonias()
            async let estructurasTask = EstructurasService.shared.fetchEstructuras()
            async let coloniasDetalleTask = EstructurasService.shared.fetchColoniasConCampanas()
            async let resumenMesTask = EstructurasService.shared.fetchResumenMes()

            var nuevoKpi = try await kpiTask
            let (visitasMes, _, danosMes) = (try? await resumenMesTask) ?? (0, 0, 0)
            nuevoKpi.visitasMes = visitasMes
            nuevoKpi.danosMes = danosMes
            kpi = nuevoKpi
            LocalDataCache.shared.guardar(nuevoKpi, clave: "dashboard_kpi")
            usoCampanas = (try? await campanasTask) ?? []
            usoColonias = (try? await coloniasTask) ?? []
            let estructuras = (try? await estructurasTask) ?? []
            coloniasDetalle = (try? await coloniasDetalleTask) ?? []

            computarCobertura(estructuras: estructuras)
        } catch is CancellationError {
        } catch {
            if !kpi.isLoaded { errorMessage = error.localizedDescription }
        }
    }

    private func computarCobertura(estructuras: [EstructuraConParque]) {
        let polygons = loadGeoPolygons(named: "nuevascolonias")
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
