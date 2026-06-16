import SwiftUI

struct NetworkStatusBanner: View {
    private var queue: OfflineQueueService { OfflineQueueService.shared }
    @State private var mostrarReconectado = false
    @State private var estabaConectado = true

    var body: some View {
        VStack {
            Group {
                if !queue.isConnected {
                    pill(
                        icono: "wifi.slash",
                        texto: queue.pendientes.isEmpty
                            ? "Sin internet"
                            : "Sin internet · \(queue.pendientes.count) \(queue.pendientes.count == 1 ? "acción guardada" : "acciones guardadas")",
                        color: .orange
                    )
                } else if mostrarReconectado {
                    pill(
                        icono: queue.isProcessing ? "arrow.clockwise" : "wifi",
                        texto: queue.isProcessing ? "Reconectado · sincronizando..." : "Reconectado",
                        color: Color(hex: "#16a34a")
                    )
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            Spacer()
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: queue.isConnected)
        .animation(.spring(duration: 0.4, bounce: 0.2), value: mostrarReconectado)
        .onChange(of: queue.isConnected) { _, conectado in
            if conectado && !estabaConectado {
                withAnimation { mostrarReconectado = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { mostrarReconectado = false }
                }
            }
            estabaConectado = conectado
        }
    }

    private func pill(icono: String, texto: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
                .font(.caption.weight(.semibold))
            Text(texto)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color, in: Capsule())
        .shadow(color: color.opacity(0.35), radius: 8, y: 4)
        .padding(.top, 12)
    }
}
