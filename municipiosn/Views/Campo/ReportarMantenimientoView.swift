import SwiftUI

struct ReportarMantenimientoView: View {
    let estructura: EstructuraConParque
    let userId: UUID?
    var rutaSemanaId: UUID? = nil
    var onCompletion: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var notas: String = ""
    @State private var fotoUI: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exito = false
    @State private var exitoOffline = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    estructuraHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    VStack(spacing: 6) {
                        Text("Foto del problema")
                            .font(.title2.bold())
                            .foregroundStyle(Color("Navy"))
                        Text("Toma una foto que muestre qué necesita la estructura")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    FotoCapturaView(imagen: $fotoUI)
                        .padding(.horizontal, 20)

                    TextField("Ej: Pintura descarapelada, base oxidada, salida de su lugar", text: $notas, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)

                    Button(action: enviar) {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Enviar reporte")
                            }
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                        isLoading || fotoUI == nil ? Color.secondary.opacity(0.35) : Color("Navy"),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    }
                    .disabled(isLoading || fotoUI == nil)
                    .opacity(isLoading ? 0.6 : 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reportar mantenimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color("Navy"))
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if exito { exitoOverlay }
                if exitoOffline { exitoOfflineOverlay }
            }
            .interactiveDismissDisabled(fotoUI != nil || !notas.isEmpty || isLoading)
        }
    }

    // MARK: - Header

    private var estructuraHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(estructura.numero)
                    .font(.title3.bold())
                    .foregroundStyle(Color("Navy"))
                if let parque = estructura.parques {
                    Text(parque.nombre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let colonia = parque.colonias {
                        Text(colonia.nombre)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            EstadoBadge(estado: estructura.estado)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Éxito

    private var exitoOverlay: some View {
        exitoView(
            icono: "checkmark.circle.fill",
            color: .cyan,
            titulo: "Mantenimiento reportado",
            detalle: "La estructura fue marcada como necesita mantenimiento.",
            delay: 1.8
        )
    }

    private var exitoOfflineOverlay: some View {
        exitoView(
            icono: "wifi.slash",
            color: .orange,
            titulo: "Guardado sin internet",
            detalle: "Se enviará automáticamente cuando haya señal.",
            delay: 2.2
        )
    }

    private func exitoView(icono: String, color: Color, titulo: String, detalle: String, delay: Double) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.system(size: 60))
                    .foregroundStyle(color)
                Text(titulo)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
        .onAppear {
            if icono == "wifi.slash" { HapticService.advertencia() } else { HapticService.exito() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onCompletion?()
                dismiss()
            }
        }
    }

    // MARK: - Enviar

    private func enviar() {
        guard let userId else { return }
        let fotoData = fotoUI?.jpegData(compressionQuality: 0.85)
        let notasVal = notas.isEmpty ? nil : notas

        guard OfflineQueueService.shared.isConnected else {
            let accion = AccionPendiente(
                tipo: .reporteMantenimiento,
                estructuraId: estructura.id,
                rutaSemanaId: rutaSemanaId,
                userId: userId,
                fotoAntesData: fotoData,
                notas: notasVal
            )
            OfflineQueueService.shared.encolar(accion)
            withAnimation { exitoOffline = true }
            return
        }

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                var fotoUrl: String? = nil
                if let data = fotoData {
                    let path = "\(userId.uuidString)/\(UUID().uuidString)_mant.jpg"
                    fotoUrl = try await CoroplastService.shared.uploadFoto(data: data, path: path)
                }
                try await CoroplastService.shared.registrarMantenimiento(
                    estructuraId: estructura.id,
                    userId: userId,
                    rutaSemanaId: rutaSemanaId,
                    fotoUrl: fotoUrl,
                    notas: notasVal
                )
                withAnimation { exito = true }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
