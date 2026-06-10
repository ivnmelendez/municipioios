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
    private var subIntervencion: RealtimeSubscription?
    private var subDano: RealtimeSubscription?
    private let client = SupabaseService.shared.client

    private var notificacionesHabilitadas: Bool {
        UserDefaults.standard.object(forKey: "notificacionesHabilitadas") as? Bool ?? true
    }

    private init() {}

    func subscribir() async {
        guard channel == nil else { return }
        await client.realtimeV2.removeAllChannels()
        let channel = client.realtimeV2.channel("campo_actividad")

        subIntervencion = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "rondines_estructuras",
            filter: "accion=eq.cambio_coroplast"
        ) { [weak self] change in
            Task { @MainActor [weak self] in
                self?.handleInsert(change, tipo: .intervencion)
            }
        }

        subDano = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "rondines_estructuras",
            filter: "accion=eq.reporte_dano"
        ) { [weak self] change in
            Task { @MainActor [weak self] in
                self?.handleInsert(change, tipo: .dano)
            }
        }

        try? await channel.subscribeWithError()
        self.channel = channel

        programarNotificacionSabado()
    }

    func desuscribir() async {
        if let ch = channel {
            await client.realtimeV2.removeChannel(ch)
        }
        subIntervencion = nil
        subDano = nil
        channel = nil
    }

    // MARK: - Sábado 6pm

    func programarNotificacionSabado() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rondin_sabado"])

        guard notificacionesHabilitadas else { return }

        let content = UNMutableNotificationContent()
        content.title = "Historial de rondín disponible"
        content.body = "Ya puedes revisar las estructuras visitadas hoy por el equipo de campo."
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = 7   // Sábado
        comps.hour = 18
        comps.minute = 0

        content.userInfo = ["destino": "rondines"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "rondin_sabado",
            content: content,
            trigger: trigger
        )
        Task { try? await center.add(request) }
    }

    func cancelarNotificacionSabado() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["rondin_sabado"])
    }

    // MARK: - Realtime handler

    private enum TipoEvento { case intervencion, dano }

    private func handleInsert(_ change: InsertAction, tipo: TipoEvento) {
        NotificationCenter.default.post(name: .nuevoCambioRotoplas, object: nil)
        guard notificacionesHabilitadas else { return }

        badgeCount += 1

        let num = change.record["estructura_id"]?.stringValue ?? "—"

        let (titulo, cuerpo): (String, String) = switch tipo {
        case .intervencion:
            ("Cambio de coroplast registrado", "Estructura \(num)")
        case .dano:
            ("⚠️ Daño reportado", "Estructura \(num) necesita atención")
        }

        Task {
            let content = UNMutableNotificationContent()
            content.title = titulo
            content.body = cuerpo
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
}

extension Notification.Name {
    static let nuevoCambioRotoplas = Notification.Name("nuevoCambioRotoplas")
    static let abrirRondines = Notification.Name("abrirRondines")
}
