import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    var kpi = KPIData()
    var errorMessage: String?
    var isLoading = false

    func cargar() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            kpi = try await EstructurasService.shared.fetchKPIs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
