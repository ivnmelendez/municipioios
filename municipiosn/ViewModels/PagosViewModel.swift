import Foundation
import SwiftUI

@MainActor
@Observable
final class PagosViewModel {
    var pagos: [PagoManoObra] = []
    var isLoading = false
    var errorMessage: String?

    var totalMes: Double {
        let cal = Calendar.current
        return pagos
            .filter { cal.isDate($0.fechaDate, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.monto }
    }

    func totalMesPor(trabajador: String) -> Double {
        let cal = Calendar.current
        return pagos
            .filter { cal.isDate($0.fechaDate, equalTo: Date(), toGranularity: .month) && $0.trabajador == trabajador }
            .reduce(0) { $0 + $1.monto }
    }

    var trabajadores: [String] {
        Array(Set(pagos.map { $0.trabajador })).sorted()
    }

    func cargar() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            pagos = try await PagosService.shared.fetchPagos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func registrar(fecha: String, trabajador: String, monto: Double, concepto: String?, creadoPor: UUID) async {
        do {
            try await PagosService.shared.registrar(
                fecha: fecha,
                trabajador: trabajador,
                monto: monto,
                concepto: concepto,
                creadoPor: creadoPor
            )
            await cargar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func eliminar(_ pago: PagoManoObra) async {
        pagos.removeAll { $0.id == pago.id }
        do {
            try await PagosService.shared.eliminar(id: pago.id)
        } catch {
            await cargar()
        }
    }
}
