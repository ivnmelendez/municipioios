import Foundation
import Supabase
import UserNotifications

@MainActor
@Observable
final class RealtimeService {
    static let shared = RealtimeService()

    var nuevaIntervencion: IntervencionCompleta?
    var badgeCount: Int = 0

    private var channel: RealtimeChannelV2?
    private var subscription: RealtimeSubscription?
    private let client = SupabaseService.shared.client

    private init() {}

    func subscribir() async {
        let channel = client.realtimeV2.channel("rondines_estructuras_rotoplas")

        subscription = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "rondines_estructuras",
            filter: "accion=eq.cambio_rotoplas"
        ) { [weak self] change in
            Task { @MainActor [weak self] in
                await self?.handleInsert(change)
            }
        }

        try? await channel.subscribeWithError()
        self.channel = channel
    }

    func desuscribir() async {
        await channel?.unsubscribe()
        subscription = nil
        channel = nil
    }

    private var notificacionesHabilitadas: Bool {
        UserDefaults.standard.object(forKey: "notificacionesHabilitadas") as? Bool ?? true
    }

    private func handleInsert(_ change: InsertAction) async {
        NotificationCenter.default.post(name: .nuevoCambioRotoplas, object: nil)

        guard notificacionesHabilitadas else { return }

        badgeCount += 1

        let estructuraNum = change.record["estructuras"]?.objectValue?["numero"]?.stringValue ?? "—"
        let parqueNom = change.record["estructuras"]?.objectValue?["parques"]?.objectValue?["nombre"]?.stringValue ?? "—"
        let quien = change.record["rondines"]?.objectValue?["perfiles"]?.objectValue?["nombre"]?.stringValue ?? "—"

        await dispararNotificacion(estructuraNum: estructuraNum, parque: parqueNom, quien: quien)
    }

    private func dispararNotificacion(estructuraNum: String, parque: String, quien: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Nuevo cambio de rotoplas"
        content.body = "\(estructuraNum) · \(parque) — \(quien)"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

extension Notification.Name {
    static let nuevoCambioRotoplas = Notification.Name("nuevoCambioRotoplas")
}
