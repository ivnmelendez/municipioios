import SwiftUI

struct AvisoCoroplastView: View {
    let estructura: EstructuraConParque
    let userId: UUID?
    var rutaSemanaId: UUID? = nil
    var onCompletion: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var tipoSeleccionado: String? = nil
    @State private var fotoUI: UIImage?
    @State private var notas: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exito = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    estructuraHeader
                    tipoSelector
                    FotoCapturaView(imagen: $fotoUI)
                        .padding(.horizontal, 20)
                    notasField
                    botonEnviar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Aviso coroplast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color("Navy"))
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .overlay {
                if exito { exitoOverlay }
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
                    Text(parque.nombre).font(.subheadline).foregroundStyle(.secondary)
                    if let colonia = parque.colonias {
                        Text(colonia.nombre).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            EstadoBadge(estado: estructura.estado)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    // MARK: - Tipo selector

    private var tipoSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿Cuál es el problema?")
                .font(.headline)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                tipoCard(
                    tipo: "sin_coroplast",
                    titulo: "Sin coroplast",
                    subtitulo: "No tiene panel",
                    icono: "square.slash.fill",
                    color: Color(hex: "#ea580c") ?? .orange
                )
                tipoCard(
                    tipo: "coroplast_roto",
                    titulo: "Dañado",
                    subtitulo: "Roto o salido",
                    icono: "exclamationmark.square.fill",
                    color: Color(hex: "#d97706") ?? .yellow
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func tipoCard(tipo: String, titulo: String, subtitulo: String, icono: String, color: Color) -> some View {
        let seleccionado = tipoSeleccionado == tipo
        return Button { tipoSeleccionado = tipo; HapticService.seleccion() } label: {
            VStack(spacing: 10) {
                Image(systemName: icono)
                    .font(.system(size: 28))
                    .foregroundStyle(seleccionado ? .white : color)
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(seleccionado ? .white : .primary)
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(seleccionado ? .white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                seleccionado ? color : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(seleccionado ? color : Color.clear, lineWidth: 2)
            )
            .animation(.spring(duration: 0.2), value: seleccionado)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notas

    private var notasField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas (opcional)")
                .font(.subheadline.weight(.medium))
            TextField("Describe el problema…", text: $notas, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Botón

    private var botonEnviar: some View {
        Button(action: enviar) {
            HStack {
                if isLoading { ProgressView().tint(.white) }
                else { Image(systemName: "bell.fill"); Text("Enviar aviso") }
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                tipoSeleccionado != nil ? Color(hex: "#ea580c") ?? .orange : Color.secondary.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(tipoSeleccionado == nil || isLoading)
    }

    // MARK: - Éxito

    private var exitoOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text("Aviso registrado")
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("El equipo verá el aviso en el próximo recorrido.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
        .onAppear {
            HapticService.exito()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onCompletion?()
                dismiss()
            }
        }
    }

    // MARK: - Enviar

    private func enviar() {
        guard let userId, let tipo = tipoSeleccionado else { return }
        let fotoData = fotoUI?.jpegData(compressionQuality: 0.85)
        let notasVal = notas.isEmpty ? nil : notas

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                var fotoUrl: String? = nil
                if let data = fotoData {
                    let path = "\(userId.uuidString)/\(UUID().uuidString)_coroplast.jpg"
                    fotoUrl = try await CoroplastService.shared.uploadFoto(data: data, path: path)
                }
                try await CoroplastService.shared.reportarCoroplast(
                    estructuraId: estructura.id,
                    userId: userId,
                    rutaSemanaId: rutaSemanaId,
                    tipo: tipo,
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
