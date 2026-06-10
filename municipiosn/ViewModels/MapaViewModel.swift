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
    var isLoading = false
    var visitadasHoy: Set<UUID> = []

    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.7327, longitude: -100.2726),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    func cargar(userId: UUID? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            estructuras = try await EstructurasService.shared.fetchEstructuras()
            if let uid = userId {
                visitadasHoy = (try? await CoroplastService.shared.fetchVisitadasHoy(userId: uid)) ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
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
