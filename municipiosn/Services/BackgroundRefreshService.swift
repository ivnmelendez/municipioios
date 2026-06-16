import BackgroundTasks
import Foundation

// MARK: - Background task identifier
// Must match BGTaskSchedulerPermittedIdentifiers in Info.plist
private let taskId = "com.ivanmelendez.municipiosn.refresh"

final class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()
    private init() {}

    // Call from AppDelegate/App init to register the handler
    func registrar() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleRefresh(task: refreshTask)
        }
    }

    // Call after app finishes launching and after each background execution
    func programar() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // min 15 min
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handler

    private func handleRefresh(task: BGAppRefreshTask) {
        // Re-schedule next refresh immediately
        programar()

        let taskHandle = Task {
            await ejecutarRefresh()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            taskHandle.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func ejecutarRefresh() async {
        // Flush offline queue first
        await OfflineQueueService.shared.procesarQueue()

        // Refresh and cache estructuras + campañas
        if let estructuras = try? await EstructurasService.shared.fetchEstructuras() {
            LocalDataCache.shared.guardar(estructuras, clave: "estructuras_mapa")
            LocalDataCache.shared.guardar(estructuras, clave: "estructuras_campo")
            LocalDataCache.shared.guardar(estructuras, clave: "estructuras_lista")
        }
        if let campanas = try? await CoroplastService.shared.fetchCampanasActivas() {
            LocalDataCache.shared.guardar(campanas, clave: "campanas")
        }
        if let kpi = try? await EstructurasService.shared.fetchKPIs() {
            LocalDataCache.shared.guardar(kpi, clave: "dashboard_kpi")
        }
    }
}
