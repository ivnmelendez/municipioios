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
    private let client = SupabaseService.shared.client

    private init() {}

    func subscribir() async {
        let channel = await client.realtimeV2.channel("rondines_estructuras_rotoplas")

        let changes = await channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "rondines_estructuras",
            filter: "accion=eq.cambio_rotoplas"
        )

        await channel.subscribe()
        self.channel = channel

        for await change in changes {
            await handleInsert(change)
        }
    }

    func desuscribir() async {
        await channel?.unsubscribe()
        channel = nil
    }

    private var notificacionesHabilitadas: Bool {
        UserDefaults.standard.object(forKey: "notificacionesHabilitadas") as? Bool ?? true
    }

    private func handleInsert(_ change: InsertAction) async {
        NotificationCenter.default.post(name: .nuevoCambioRotoplas, object: nil)

        guard notificacionesHabilitadas else { return }

        badgeCount += 1

        let estructuraNum = (change.record["estructuras"] as? [String: Any])?["numero"] as? String ?? "—"
        let parqueNom = ((change.record["estructuras"] as? [String: Any])?["parques"] as? [String: Any])?["nombre"] as? String ?? "—"
        let quien = ((change.record["rondines"] as? [String: Any])?["perfiles"] as? [String: Any])?["nombre"] as? String ?? "—"

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
