import Foundation
import MapKit

@MainActor
@Observable
final class MapaViewModel {
    var estructuras: [EstructuraConParque] = []
    var estructuraSeleccionada: EstructuraConParque?
    var carasSeleccionadas: [Cara] = []
    var campanaCaraA: Campana?
    var campanaCaraB: Campana?
    var mostrarDetalle = false
    var errorMessage: String?
    var isLoading = false

    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.7327, longitude: -100.2726),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    func cargar() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            estructuras = try await EstructurasService.shared.fetchEstructuras()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seleccionar(_ estructura: EstructuraConParque) async {
        estructuraSeleccionada = estructura
        carasSeleccionadas = []
        campanaCaraA = nil
        campanaCaraB = nil

        do {
            let caras = try await EstructurasService.shared.fetchCaras(estructuraId: estructura.id)
            carasSeleccionadas = caras

            for cara in caras {
                let campana = try await EstructurasService.shared.fetchCampanaActivaDeCara(caraId: cara.id)
                if cara.tipo == "A" {
                    campanaCaraA = campana
                } else if cara.tipo == "B" {
                    campanaCaraB = campana
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        mostrarDetalle = true
    }
}
