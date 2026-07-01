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
    var alcancePorColonia: [ColoniaAlcance] = []
    var alcanceTotal: Int = 0
    var alcanceFem: Int = 0
    var alcanceMas: Int = 0
    var alcance18mas: Int = 0
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
            async let estructurasTask = EstructurasService.shared.fetchEstructuras()
            async let kpiTask = EstructurasService.shared.fetchKPIs()
            async let campanasTask = EstructurasService.shared.fetchUsoCampanas()
            async let coloniasTask = EstructurasService.shared.fetchUsoColonias()
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
            coloniasDetalle = (try? await coloniasDetalleTask) ?? []

            let totalColonias = (try? await EstructurasService.shared.fetchTotalColonias()) ?? 0
            coloniasConEstructuras = usoColonias.count
            totalColoniasGeo = totalColonias
            coloniasSinEstructuras = max(0, totalColonias - usoColonias.count)

            let estructuras = (try? await estructurasTask) ?? []
            computarAlcance(estructuras: estructuras)
        } catch is CancellationError {
        } catch {
            if !kpi.isLoaded { errorMessage = error.localizedDescription }
        }
    }

    private func computarAlcance(estructuras: [EstructuraConParque]) {
        let polygons = loadGeoPolygons(named: "colonias_san_nicolas")
        guard !polygons.isEmpty else { return }

        var porColonia: [UUID: (nombre: String, coords: [CLLocationCoordinate2D])] = [:]
        for e in estructuras {
            guard let colonia = e.parques?.colonias,
                  let lat = e.lat, let lng = e.lng else { continue }
            var entry = porColonia[colonia.id] ?? (colonia.nombre, [])
            entry.coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            porColonia[colonia.id] = entry
        }

        alcancePorColonia = porColonia.map { id, val in
            let d = alcanceDetallado(polygons: polygons, coordenadas: val.coords)
            return ColoniaAlcance(
                id: id,
                nombre: val.nombre,
                estructuras: val.coords.count,
                poblacion: d.pobtot,
                pobFem: d.pobFem,
                pobMas: d.pobMas,
                p18ymas: d.p18ymas
            )
        }.sorted { $0.poblacion > $1.poblacion }

        let todasCoords = estructuras.compactMap { e -> CLLocationCoordinate2D? in
            guard let lat = e.lat, let lng = e.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let total = alcanceDetallado(polygons: polygons, coordenadas: todasCoords)
        alcanceTotal  = total.pobtot
        alcanceFem    = total.pobFem
        alcanceMas    = total.pobMas
        alcance18mas  = total.p18ymas
    }

}
