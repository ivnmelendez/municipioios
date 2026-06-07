import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    var kpi = KPIData()
    var usoCampanas: [UsoCampana] = []
    var usoColonias: [UsoColonia] = []
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
            kpi = try await kpiTask
            usoCampanas = (try? await campanasTask) ?? []
            usoColonias = (try? await coloniasTask) ?? []
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
}
