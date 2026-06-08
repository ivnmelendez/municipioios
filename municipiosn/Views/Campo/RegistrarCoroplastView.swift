import SwiftUI
import PhotosUI

enum TipoAccionCoroplast {
    case reparacion, cambio
}

struct RegistrarCoroplastView: View {
    let estructura: EstructuraConParque
    let campanas: [CampanaBasica]
    let userId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var tipoSeleccionado: TipoAccionCoroplast?
    @State private var caras: [CaraParaCambio] = []
    @State private var notas: String = ""
    @State private var fotoAntesItem: PhotosPickerItem?
    @State private var fotoDespuesItem: PhotosPickerItem?
    @State private var fotoAntesUI: UIImage?
    @State private var fotoDespuesUI: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cargandoCaras = false
    @State private var exito = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    estructuraHeader
                    accionSelector
                    if tipoSeleccionado != nil {
                        fotosSection
                        notasSection
                        if tipoSeleccionado == .cambio {
                            carasSection
                        }
                        submitButton
                    }
                }
                .padding()
            }
            .navigationTitle("Registrar acción")
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
                if exito {
                    exitoOverlay
                }
            }
        }
    }

    // MARK: - Sections

    private var estructuraHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(estructura.numero)
                            .font(.title2.bold())
                        if let local = estructura.numeroLocal {
                            Text(local)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var accionSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿Qué se hizo?")
                .font(.headline)
            HStack(spacing: 12) {
                accionCard(
                    titulo: "Reparación",
                    descripcion: "Coroplast dañado\no fuera de lugar",
                    icono: "wrench.and.screwdriver.fill",
                    tipo: .reparacion
                )
                accionCard(
                    titulo: "Cambio",
                    descripcion: "Coroplast nuevo\ncon campaña",
                    icono: "arrow.2.squarepath",
                    tipo: .cambio
                )
            }
        }
    }

    private func accionCard(titulo: String, descripcion: String, icono: String, tipo: TipoAccionCoroplast) -> some View {
        let seleccionado = tipoSeleccionado == tipo
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                tipoSeleccionado = tipo
            }
            if tipo == .cambio && caras.isEmpty {
                Task { await cargarCaras() }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icono)
                    .font(.title2)
                    .foregroundStyle(seleccionado ? .white : Color("MunicipioCyan"))
                Text(titulo)
                    .font(.headline)
                    .foregroundStyle(seleccionado ? .white : .primary)
                Text(descripcion)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(seleccionado ? .white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(seleccionado ? Color("MunicipioCyan") : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(seleccionado ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var fotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fotos")
                .font(.headline)
            HStack(spacing: 12) {
                fotoPickerCard(titulo: "Antes", item: $fotoAntesItem, imagen: $fotoAntesUI)
                fotoPickerCard(titulo: "Después", item: $fotoDespuesItem, imagen: $fotoDespuesUI)
            }
        }
    }

    private func fotoPickerCard(titulo: String, item: Binding<PhotosPickerItem?>, imagen: Binding<UIImage?>) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            ZStack {
                if let img = imagen.wrappedValue {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text(titulo)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
        }
        .onChange(of: item.wrappedValue) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    imagen.wrappedValue = ui
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var notasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas")
                .font(.headline)
            TextField("Observaciones (opcional)", text: $notas, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var carasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Asignar campaña por cara")
                .font(.headline)
            if cargandoCaras {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if caras.isEmpty {
                Text("Sin caras registradas para esta estructura.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach($caras) { $cara in
                    CaraCampanaRow(cara: $cara, campanas: campanas)
                }
            }
        }
    }

    private var submitButton: some View {
        Button(action: enviar) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: tipoSeleccionado == .cambio ? "arrow.2.squarepath" : "checkmark")
                    Text(tipoSeleccionado == .cambio ? "Registrar cambio" : "Registrar reparación")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("MunicipioCyan"), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading || !puedeEnviar)
        .opacity(puedeEnviar ? 1 : 0.5)
    }

    private var exitoOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("¡Registrado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    // MARK: - Logic

    private var puedeEnviar: Bool {
        guard let tipo = tipoSeleccionado else { return false }
        if tipo == .cambio {
            return !cargandoCaras && caras.allSatisfy { $0.nuevaCampana != nil }
        }
        return true
    }

    private func cargarCaras() async {
        cargandoCaras = true
        defer { cargandoCaras = false }
        do {
            caras = try await CoroplastService.shared.fetchCarasParaCambio(estructuraId: estructura.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enviar() {
        guard let tipo = tipoSeleccionado, let userId = userId else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let antesUrl = try await subirFotoSiExiste(fotoAntesUI, nombre: "antes")
                let despuesUrl = try await subirFotoSiExiste(fotoDespuesUI, nombre: "despues")
                let notasVal = notas.isEmpty ? nil : notas

                switch tipo {
                case .reparacion:
                    try await CoroplastService.shared.registrarReparacion(
                        estructuraId: estructura.id,
                        userId: userId,
                        fotoAntesUrl: antesUrl,
                        fotoDespuesUrl: despuesUrl,
                        notas: notasVal
                    )
                case .cambio:
                    let asignaciones = caras.compactMap { cara -> (caraId: UUID, campanaId: UUID)? in
                        guard let campana = cara.nuevaCampana else { return nil }
                        return (caraId: cara.id, campanaId: campana.id)
                    }
                    try await CoroplastService.shared.registrarCambio(
                        estructuraId: estructura.id,
                        userId: userId,
                        carasNuevasCampanas: asignaciones,
                        fotoAntesUrl: antesUrl,
                        fotoDespuesUrl: despuesUrl,
                        notas: notasVal
                    )
                }

                withAnimation { exito = true }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func subirFotoSiExiste(_ image: UIImage?, nombre: String) async throws -> String? {
        guard let image = image,
              let data = image.jpegData(compressionQuality: 0.8),
              let userId = userId else { return nil }
        let path = "\(userId.uuidString)/\(UUID().uuidString)_\(nombre).jpg"
        return try? await CoroplastService.shared.uploadFoto(data: data, path: path)
    }
}

// MARK: - CaraCampanaRow

private struct CaraCampanaRow: View {
    @Binding var cara: CaraParaCambio
    let campanas: [CampanaBasica]
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(cara.tipo.capitalized, systemImage: "rectangle.portrait")
                    .font(.subheadline.bold())
                Spacer()
                if let actual = cara.campanaActual {
                    Text("Antes: \(actual.nombre)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                showPicker = true
            } label: {
                HStack {
                    if let nueva = cara.nuevaCampana {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(nueva.nombre)
                            .foregroundStyle(.primary)
                    } else {
                        Image(systemName: "plus.circle.dashed")
                            .foregroundStyle(Color("MunicipioCyan"))
                        Text("Seleccionar campaña")
                            .foregroundStyle(Color("MunicipioCyan"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .sheet(isPresented: $showPicker) {
                CampanaPickerSheet(campanas: campanas, seleccionada: $cara.nuevaCampana)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - CampanaPickerSheet

private struct CampanaPickerSheet: View {
    let campanas: [CampanaBasica]
    @Binding var seleccionada: CampanaBasica?
    @Environment(\.dismiss) private var dismiss
    @State private var busqueda = ""

    private var filtradas: [CampanaBasica] {
        guard !busqueda.isEmpty else { return campanas }
        return campanas.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
    }

    var body: some View {
        NavigationStack {
            List(filtradas) { campana in
                Button {
                    seleccionada = campana
                    dismiss()
                } label: {
                    HStack {
                        Text(campana.nombre)
                            .foregroundStyle(.primary)
                        Spacer()
                        if seleccionada?.id == campana.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color("MunicipioCyan"))
                        }
                    }
                }
            }
            .searchable(text: $busqueda, prompt: "Buscar campaña")
            .navigationTitle("Campaña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
