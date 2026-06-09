import SwiftUI
import PhotosUI

struct ReportarDanoView: View {
    let estructura: EstructuraConParque
    let userId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var notas: String = ""
    @State private var fotoItem: PhotosPickerItem?
    @State private var fotoUI: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exito = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    estructuraHeader
                    warningCard
                    fotoSection
                    notasSection
                    submitButton
                }
                .padding()
            }
            .navigationTitle("Reportar daño")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay {
                if exito { exitoOverlay }
            }
        }
    }

    private var estructuraHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(estructura.numero)
                    .font(.title2.bold())
                if let parque = estructura.parques {
                    Text(parque.nombre)
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
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var warningCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Esta estructura quedará marcada como DAÑADA")
                    .font(.subheadline.bold())
                Text("El equipo de mantenimiento será notificado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private var fotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foto del daño")
                .font(.headline)
            PhotosPicker(selection: $fotoItem, matching: .images) {
                ZStack {
                    if let img = fotoUI {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .overlay {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("Tomar foto del daño")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                }
            }
            .onChange(of: fotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        fotoUI = ui
                    }
                }
            }
        }
    }

    private var notasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descripción del daño")
                .font(.headline)
            TextField("Describe qué está dañado (opcional)", text: $notas, axis: .vertical)
                .lineLimit(3...6)
                .font(.body)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var submitButton: some View {
        Button(action: enviar) {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Reportar daño")
                }
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1)
    }

    private var exitoOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("¡Reporte enviado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("La estructura fue marcada como dañada.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
        }
    }

    private func enviar() {
        guard let userId else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                var fotoUrl: String? = nil
                if let img = fotoUI,
                   let data = img.jpegData(compressionQuality: 0.8) {
                    let path = "\(userId.uuidString)/\(UUID().uuidString)_dano.jpg"
                    fotoUrl = try? await CoroplastService.shared.uploadFoto(data: data, path: path)
                }
                try await CoroplastService.shared.reportarDano(
                    estructuraId: estructura.id,
                    userId: userId,
                    fotoUrl: fotoUrl,
                    notas: notas.isEmpty ? nil : notas
                )
                withAnimation { exito = true }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
