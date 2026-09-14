#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct CampoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var ultimaActualizacion: Date
        var activo: Bool
    }

    let nombre: String
    let inicial: String
}

@available(iOS 16.1, *)
final class WorkerLiveActivityManager {
    static let shared = WorkerLiveActivityManager()
    private var activities: [String: Activity<CampoActivityAttributes>] = [:]

    func update(trabajadores: [UbicacionActiva]) {
        let activosIds = Set(trabajadores.map(\.userId.uuidString))

        // End activities for workers who went offline
        for (id, activity) in activities where !activosIds.contains(id) {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
            activities.removeValue(forKey: id)
        }

        // Start or update for active workers
        for trabajador in trabajadores {
            let id = trabajador.userId.uuidString
            let nombre = trabajador.perfiles?.nombre ?? "Trabajador"
            let inicial = String(nombre.prefix(1)).uppercased()
            let state = CampoActivityAttributes.ContentState(
                ultimaActualizacion: Date(),
                activo: true
            )
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))

            if let existing = activities[id] {
                Task { await existing.update(content) }
            } else {
                let attrs = CampoActivityAttributes(nombre: nombre, inicial: inicial)
                if let activity = try? Activity.request(attributes: attrs, content: content) {
                    activities[id] = activity
                }
            }
        }
    }

    func endAll() {
        for activity in activities.values {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activities.removeAll()
    }
}
#endif
