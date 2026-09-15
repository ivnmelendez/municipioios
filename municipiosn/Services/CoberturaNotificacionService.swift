import Foundation
// import UserNotifications  // pendiente: requiere APNs (Apple Developer Program)

final class CoberturaNotificacionService {
    static let shared = CoberturaNotificacionService()
    private init() {}

    // MARK: - Utilidades compartidas

    static func nombreDelMes(_ mes: Int) -> String {
        let lista = ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
                     "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
        guard (1...12).contains(mes) else { return "" }
        return lista[mes - 1]
    }

    // MARK: - Notificación fin de mes (pendiente de implementar con APNs)
    //
    // Para enviar la notificación del último sábado con datos reales de Supabase,
    // se necesita una Supabase Edge Function (cron 4:50pm) + APNs.
    // APNs requiere Apple Developer Program ($99/año).
    //
    // Lógica ya diseñada:
    //   - Mensaje "✅ ¡Meta cumplida!" si visitadas >= total
    //   - Mensaje "⚠️ Quedaron N sin revisar" si visitadas < total
    //   - Mensaje "Sin actividad registrada" si visitadas == 0
    //   - Deep link: tap → historial de cobertura (destino: "historial_cobertura")
    //   - Hora: último sábado del mes, 5:05pm Monterrey
    //
    // func scheduleProximos(_ meses: Int = 12) async { ... }
    // func actualizarCobertura(visitadas: Int, total: Int) async { ... }
}
