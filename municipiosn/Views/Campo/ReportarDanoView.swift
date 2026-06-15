import SwiftUI

private enum Paso { case foto, confirmar }

struct ReportarDanoView: View {
    let estructura: EstructuraConParque
    let userId: UUID?
    var rutaSemanaId: UUID? = nil
    var onCompletion: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var paso: Paso = .foto
    @State private var notas: String = ""
    @State private var fotoUI: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exito = false
    @State private var exitoOffline = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                estructuraHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                progresoIndicador
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                ZStack {
                    if paso == .foto      { pasoFoto.transition(.opacity) }
                    if paso == .confirmar { pasoConfirmar.transition(.opacity) }
                }
                .animation(.easeInOut(duration: 0.2), value: paso)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reportar daño")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if paso == .foto {
                        Button("Cancelar") { dismiss() }
                            .foregroundStyle(Color("Navy"))
                    } else {
                        Button(action: retroceder) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Atrás")
                            }
                            .foregroundStyle(Color("Navy"))
                        }
                    }
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

    // MARK: - Progreso

    private var progresoIndicador: some View {
        HStack(spacing: 8) {
            ForEach(1...2, id: \.self) { n in
                let activo = n == (paso == .foto ? 1 : 2)
                let completado = n < (paso == .foto ? 1 : 2)
                Capsule()
                    .fill(activo || completado ? Color("Navy") : Color.secondary.opacity(0.25))
                    .frame(width: activo ? 28 : 10, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: paso)
            }
        }
    }

    // MARK: - Paso 1: Foto

    private var pasoFoto: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Foto del daño")
                    .font(.title2.bold())
                    .foregroundStyle(Color("Navy"))
                Text("Toma una foto que muestre claramente el daño")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            FotoCapturaView(imagen: $fotoUI)
                .padding(.horizontal, 20)

            botonContinuar(habilitado: fotoUI != nil, accion: avanzarAConfirmar)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso 2: Confirmar

    private var pasoConfirmar: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Notas del daño")
                        .font(.title2.bold())
                        .foregroundStyle(Color("Navy"))
                    Text("Opcional — describe qué pasó")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Ej: La estructura estaba golpeada de un lado", text: $notas, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

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
                    .background(Color("Navy"), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Éxito

    private var exitoOverlay: some View {
        exitoView(
            icono: "checkmark.circle.fill",
            color: .green,
            titulo: "Reporte enviado",
            detalle: "La estructura fue marcada como dañada.",
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
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onCompletion?()
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func botonContinuar(habilitado: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text("Continuar")
                Image(systemName: "chevron.right")
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                habilitado ? Color("Navy") : Color.secondary.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(!habilitado)
    }

    private func avanzarAConfirmar() {
        withAnimation(.easeInOut(duration: 0.2)) { paso = .confirmar }
    }

    private func retroceder() {
        withAnimation(.easeInOut(duration: 0.2)) { paso = .foto }
    }

    private func enviar() {
        guard let userId else { return }
        let fotoData = fotoUI?.jpegData(compressionQuality: 0.85)
        let notasVal = notas.isEmpty ? nil : notas

        guard OfflineQueueService.shared.isConnected else {
            let accion = AccionPendiente(
                tipo: .reporteDano,
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
                    let path = "\(userId.uuidString)/\(UUID().uuidString)_dano.jpg"
                    fotoUrl = try? await CoroplastService.shared.uploadFoto(data: data, path: path)
                }
                try await CoroplastService.shared.reportarDano(
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
