import Foundation
import MapKit

@MainActor
@Observable
final class MapaViewModel {
    var estructuras: [EstructuraConParque] = []
    var estructuraSeleccionada: EstructuraConParque?
    var carasDetalle: [CaraDetalle] = []
    var mostrarDetalle = false
    var errorMessage: String?
    var errorAccion: String?
    var isLoading = false
    var visitadasHoy: Set<UUID> = []

    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.7327, longitude: -100.2726),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    func cargarVisitadas(userId: UUID) async {
        visitadasHoy = (try? await CoroplastService.shared.fetchVisitadasHoy(userId: userId)) ?? []
    }

    func cargar(userId: UUID? = nil) async {
        guard !isLoading else { return }

        if estructuras.isEmpty, let cached = LocalDataCache.shared.cargar([EstructuraConParque].self, clave: "estructuras_mapa") {
            estructuras = cached
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let nuevas = try await EstructurasService.shared.fetchEstructuras()
            estructuras = nuevas
            LocalDataCache.shared.guardar(nuevas, clave: "estructuras_mapa")
        } catch {
            if estructuras.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    func seleccionar(_ estructura: EstructuraConParque) async {
        estructuraSeleccionada = estructura
        carasDetalle = []

        do {
            carasDetalle = try await EstructurasService.shared.fetchCarasDetalle(estructuraId: estructura.id)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ seleccionar error: \(error)")
        }

        mostrarDetalle = true
    }
}
