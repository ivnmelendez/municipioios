import UIKit

struct HapticService {
    static func exito() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func advertencia() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func impacto(_ estilo: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: estilo).impactOccurred()
    }

    static func seleccion() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
