import Foundation
import SwiftUI

struct RutaInfo: Identifiable {
    var id: UUID { ruta.id }
    let ruta: RutaSemana
    let visitadas: Int
    let total: Int
    var progreso: Double { total > 0 ? Double(visitadas) / Double(total) : 0 }
}

@MainActor
@Observable
final class CampoViewModel {
    var estructuras: [EstructuraConParque] = []
    var campanas: [CampanaBasica] = []
    var isLoading = false
    var errorMessage: String?
    var busqueda: String = ""

    var rutasInfo: [RutaInfo] = []
    var isLoadingRutas = false

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

    func cargarRutas(userId: UUID?) async {
        isLoadingRutas = true
        defer { isLoadingRutas = false }
        do {
            let semanas = try await RutasService.shared.fetchSemanasRecientes()
            guard let uid = userId else {
                rutasInfo = semanas.map { RutaInfo(ruta: $0, visitadas: 0, total: 0) }
                return
            }
            var infos: [RutaInfo] = []
            for semana in semanas {
                let items = try await RutasService.shared.fetchEstructurasEnRuta(
                    rutaSemanaId: semana.id, userId: uid
                )
                infos.append(RutaInfo(
                    ruta: semana,
                    visitadas: items.filter(\.visitada).count,
                    total: items.count
                ))
            }
            rutasInfo = infos
        } catch {}
    }

    func cargar() async {
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
