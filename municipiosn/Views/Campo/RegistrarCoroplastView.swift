import SwiftUI
import PhotosUI

enum TipoAccionCoroplast { case reparacion, cambio }

private enum Paso { case accion, campanas, fotoAntes, fotoDespues, confirmar }

struct RegistrarCoroplastView: View {
    let estructura: EstructuraConParque
    let campanas: [CampanaBasica]
    let userId: UUID?
    var rutaSemanaId: UUID? = nil
    var onCompletion: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var paso: Paso = .accion
    @State private var tipoSeleccionado: TipoAccionCoroplast?
    @State private var caras: [CaraParaCambio] = []
    @State private var notas: String = ""
    @State private var fotoAntesItem: PhotosPickerItem?
    @State private var fotoDespuesItem: PhotosPickerItem?
    @State private var fotoAntesUI: UIImage?
    @State private var fotoDespuesUI: UIImage?
    @State private var isLoading = false
    @State private var cargandoCaras = false
    @State private var errorMessage: String?
    @State private var exito = false
    @State private var avanzando = true

    private var esCambio: Bool { tipoSeleccionado == .cambio }

    private var totalPasos: Int { esCambio ? 5 : 4 }

    private var pasoNumero: Int {
        switch paso {
        case .accion:     return 1
        case .campanas:   return 2
        case .fotoAntes:  return esCambio ? 3 : 2
        case .fotoDespues: return esCambio ? 4 : 3
        case .confirmar:  return totalPasos
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                estructuraHeader
                    .padding(.horizontal)
                    .padding(.top, 12)

                progresoIndicador
                    .padding(.vertical, 20)

                ZStack {
                    if paso == .accion     { pasoAccion.transition(transicion) }
                    if paso == .campanas   { pasoCampanas.transition(transicion) }
                    if paso == .fotoAntes  { pasoFoto(esAntes: true).transition(transicion) }
                    if paso == .fotoDespues { pasoFoto(esAntes: false).transition(transicion) }
                    if paso == .confirmar  { pasoConfirmar.transition(transicion) }
                }
                .animation(.spring(duration: 0.35), value: paso)

                Spacer()
            }
            .navigationTitle("Registrar acción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if paso == .accion {
                        Button("Cancelar") { dismiss() }
                    } else {
                        Button(action: retroceder) {
                            Image(systemName: "chevron.left")
                            Text("Atrás")
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
            }
        }
    }

    private var transicion: AnyTransition {
        avanzando
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }

    private func avanzar(a nuevoPaso: Paso) {
        avanzando = true
        withAnimation { paso = nuevoPaso }
    }

    // MARK: - Header

    private var estructuraHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(estructura.numero)
                        .font(.title3.bold())
                    if let local = estructura.numeroLocal {
                        Text(local).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let parque = estructura.parques {
                    Text(parque.nombre).foregroundStyle(.secondary).font(.subheadline)
                    if let colonia = parque.colonias {
                        Text(colonia.nombre).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            EstadoBadge(estado: estructura.estado)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Progreso

    private var progresoIndicador: some View {
        HStack(spacing: 8) {
            ForEach(1...totalPasos, id: \.self) { n in
                Capsule()
                    .fill(n <= pasoNumero ? Color("MunicipioCyan") : Color.secondary.opacity(0.3))
                    .frame(width: n == pasoNumero ? 28 : 10, height: 8)
                    .animation(.spring(duration: 0.3), value: pasoNumero)
            }
        }
    }

    // MARK: - Paso 1: Acción

    private var pasoAccion: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("¿Qué vas a hacer?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Paso 1 de \(totalPasos)")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                opcionButton(
                    icono: "wrench.and.screwdriver.fill",
                    titulo: "Reparar el coroplast",
                    subtitulo: "El coroplast está dañado o fuera de lugar"
                ) {
                    tipoSeleccionado = .reparacion
                    avanzar(a: .fotoAntes)
                }
                opcionButton(
                    icono: "arrow.2.squarepath",
                    titulo: "Cambiar con campaña nueva",
                    subtitulo: "Se va a instalar un coroplast nuevo con campaña diferente"
                ) {
                    tipoSeleccionado = .cambio
                    if caras.isEmpty { Task { await cargarCaras() } }
                    avanzar(a: .campanas)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso 2: Campañas (solo cambio)

    private var pasoCampanas: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("¿Qué campaña va a ir en cada cara?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Paso 2 de \(totalPasos)")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            if cargandoCaras {
                ProgressView("Cargando caras...")
                    .frame(maxWidth: .infinity).padding(.top, 40)
            } else if caras.isEmpty {
                Text("Sin caras registradas para esta estructura.")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($caras) { $cara in
                            CaraCampanaRow(cara: $cara, campanas: campanas)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                continuar(habilitado: todasCarasAsignadas) {
                    avanzar(a: .fotoAntes)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Pasos de foto (antes / después)

    private func pasoFoto(esAntes: Bool) -> some View {
        let item: Binding<PhotosPickerItem?> = esAntes ? $fotoAntesItem : $fotoDespuesItem
        let imagen: Binding<UIImage?> = esAntes ? $fotoAntesUI : $fotoDespuesUI
        let titulo = esAntes ? "Foto de ANTES" : "Foto de DESPUÉS"
        let subtitulo = esAntes
            ? "Toma una foto del coroplast como está ahora, antes de tocarlo"
            : "Toma una foto del coroplast ya terminado"
        let numero = pasoNumero
        let total = totalPasos
        let siguientePaso: Paso = esAntes ? .fotoDespues : .confirmar
        let tieneFoto = esAntes ? fotoAntesUI != nil : fotoDespuesUI != nil

        return VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(titulo)
                    .font(.title2.bold())
                Text(subtitulo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("Paso \(numero) de \(total)")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            PhotosPicker(selection: item, matching: .images) {
                ZStack {
                    if let img = imagen.wrappedValue {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 4)
                                    .padding(12)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .overlay {
                                VStack(spacing: 14) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(Color("MunicipioCyan"))
                                    Text("Tocar para tomar foto")
                                        .font(.headline)
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
            .padding(.horizontal, 20)

            continuar(habilitado: tieneFoto) {
                avanzar(a: siguientePaso)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso final: Confirmar

    private var pasoConfirmar: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("¿Alguna nota antes de registrar?")
                        .font(.title2.bold())
                    Text("Paso \(pasoNumero) de \(totalPasos)")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                notasSection

                submitButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
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

    private var submitButton: some View {
        Button(action: enviar) {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: esCambio ? "arrow.2.squarepath" : "checkmark")
                    Text(esCambio ? "Registrar cambio" : "Registrar reparación")
                }
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("MunicipioCyan"), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1)
    }

    // MARK: - Éxito

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
                Text(esCambio ? "Cambio de coroplast registrado." : "Reparación registrada.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onCompletion?()
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var todasCarasAsignadas: Bool {
        !caras.isEmpty && caras.allSatisfy { $0.nuevaCampana != nil }
    }

    private func opcionButton(icono: String, titulo: String, subtitulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.title)
                    .foregroundStyle(Color("MunicipioCyan"))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(.headline).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitulo)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold()).foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color("MunicipioCyan").opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func continuar(habilitado: Bool, accion: @escaping () -> Void) -> some View {
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
                habilitado ? Color("MunicipioCyan") : Color.secondary.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(!habilitado)
    }

    private func retroceder() {
        avanzando = false
        withAnimation {
            switch paso {
            case .accion:      break
            case .campanas:    paso = .accion
            case .fotoAntes:   paso = esCambio ? .campanas : .accion
            case .fotoDespues: paso = .fotoAntes
            case .confirmar:   paso = .fotoDespues
            }
        }
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
        guard let tipo = tipoSeleccionado, let userId else { return }
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
                        rutaSemanaId: rutaSemanaId,
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
                        estadoActual: estructura.estado,
                        userId: userId,
                        rutaSemanaId: rutaSemanaId,
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
        guard let image, let data = image.jpegData(compressionQuality: 0.8), let userId else { return nil }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cara \(cara.tipo.uppercased())")
                    .font(.headline)
                Spacer()
                if let actual = cara.campanaActual {
                    Text("Actual: \(actual.nombre)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Button { showPicker = true } label: {
                HStack(spacing: 12) {
                    if let nueva = cara.nuevaCampana {
                        CampanaThumbnail(campana: nueva, size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nueva.nombre)
                                .font(.subheadline.bold()).foregroundStyle(.primary)
                            Label("Campaña asignada", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(.green)
                        }
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("MunicipioCyan").opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus.circle.dashed")
                                .font(.title2).foregroundStyle(Color("MunicipioCyan"))
                        }
                        Text("Tocar para elegir campaña")
                            .font(.subheadline).foregroundStyle(Color("MunicipioCyan"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline).foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPicker) {
                CampanaPickerSheet(campanas: campanas, seleccionada: $cara.nuevaCampana)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - CampanaThumbnail

private struct CampanaThumbnail: View {
    let campana: CampanaBasica
    let size: CGFloat

    var body: some View {
        Group {
            if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }

    private var placeholderIcon: some View {
        ZStack {
            Color(.tertiarySystemGroupedBackground)
            Image(systemName: "megaphone.fill").foregroundStyle(.secondary)
        }
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
                    HStack(spacing: 14) {
                        CampanaThumbnail(campana: campana, size: 88)
                        Text(campana.nombre)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if seleccionada?.id == campana.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("MunicipioCyan"))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $busqueda, prompt: "Buscar campaña")
            .navigationTitle("Elige la campaña")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.font(.body)
                }
            }
        }
    }
}
