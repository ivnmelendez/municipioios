import Foundation

@MainActor
@Observable
final class CampoAdminViewModel {
    var visitas: Int = 0
    var cambios: Int = 0
    var danos: Int = 0
    var cargado = false

    func cargar() async {
        guard !cargado else { return }
        if let (v, c, d) = try? await EstructurasService.shared.fetchResumenSemana() {
            visitas = v
            cambios = c
            danos = d
            cargado = true
        }
    }
}
