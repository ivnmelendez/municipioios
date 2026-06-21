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
    @State private var fotoAntesUI: UIImage?
    @State private var fotoDespuesUI: UIImage?
    @State private var isLoading = false
    @State private var cargandoCaras = false
    @State private var errorMessage: String?
    @State private var exito = false
    @State private var exitoOffline = false

    private var esCambio: Bool { tipoSeleccionado == .cambio }
    private var totalPasos: Int { esCambio ? 5 : 4 }

    private var pasoNumero: Int {
        switch paso {
        case .accion:      return 1
        case .campanas:    return 2
        case .fotoAntes:   return esCambio ? 3 : 2
        case .fotoDespues: return esCambio ? 4 : 3
        case .confirmar:   return totalPasos
        }
    }

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
                    if paso == .accion      { pasoAccion.transition(.opacity) }
                    if paso == .campanas    { pasoCampanas.transition(.opacity) }
                    if paso == .fotoAntes   { pasoFoto(esAntes: true).transition(.opacity) }
                    if paso == .fotoDespues { pasoFoto(esAntes: false).transition(.opacity) }
                    if paso == .confirmar   { pasoConfirmar.transition(.opacity) }
                }
                .animation(.easeInOut(duration: 0.2), value: paso)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Registrar acción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if paso == .accion {
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
                HStack(spacing: 8) {
                    Text(estructura.numero)
                        .font(.title3.bold())
                        .foregroundStyle(Color("Navy"))
                    if let local = estructura.numeroLocal {
                        Text(local)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
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
            ForEach(1...totalPasos, id: \.self) { n in
                let activo = n == pasoNumero
                let completado = n < pasoNumero
                Capsule()
                    .fill(activo || completado ? Color("Navy") : Color.secondary.opacity(0.25))
                    .frame(width: activo ? 28 : 10, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: pasoNumero)
            }
        }
    }

    // MARK: - Paso 1: Acción

    private var pasoAccion: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("¿Qué vas a hacer?")
                    .font(.title2.bold())
                    .foregroundStyle(Color("Navy"))
                Text("Selecciona el tipo de trabajo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                opcionButton(
                    icono: "wrench.and.screwdriver.fill",
                    titulo: "Reparar el coroplast",
                    subtitulo: "El coroplast está dañado pero no se cambia completo"
                ) {
                    tipoSeleccionado = .reparacion
                    withAnimation(.easeInOut(duration: 0.2)) { paso = .fotoAntes }
                }
                opcionButton(
                    icono: "arrow.2.squarepath",
                    titulo: "Cambiar con campaña nueva",
                    subtitulo: "Se instala coroplast nuevo con diseño diferente"
                ) {
                    if caras.isEmpty { Task { await cargarCaras() } }
                    tipoSeleccionado = .cambio
                    withAnimation(.easeInOut(duration: 0.2)) { paso = .campanas }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso 2: Campañas (solo cambio)

    private var pasoCampanas: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("¿Qué campaña va en cada cara?")
                    .font(.title2.bold())
                    .foregroundStyle(Color("Navy"))
                    .multilineTextAlignment(.center)
                Text("Asigna una campaña a cada cara de la estructura")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            if cargandoCaras {
                ProgressView("Cargando caras...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if caras.isEmpty {
                Text("Sin caras registradas para esta estructura.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
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

                botonContinuar(habilitado: todasCarasAsignadas) {
                    withAnimation(.easeInOut(duration: 0.2)) { paso = .fotoAntes }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Pasos de foto

    private func pasoFoto(esAntes: Bool) -> some View {
        let imagen: Binding<UIImage?> = esAntes ? $fotoAntesUI : $fotoDespuesUI
        let titulo = esAntes ? "Foto de ANTES" : "Foto de DESPUÉS"
        let subtitulo = esAntes
            ? "Documenta el estado del coroplast antes de tocarlo"
            : "Documenta el resultado final del trabajo"
        let siguientePaso: Paso = esAntes ? .fotoDespues : .confirmar
        let tieneFoto = esAntes ? fotoAntesUI != nil : fotoDespuesUI != nil

        return VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(titulo)
                    .font(.title2.bold())
                    .foregroundStyle(Color("Navy"))
                Text(subtitulo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            FotoCapturaView(imagen: imagen)
                .padding(.horizontal, 20)

            botonContinuar(habilitado: tieneFoto) {
                withAnimation(.easeInOut(duration: 0.2)) { paso = siguientePaso }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso final: Confirmar

    private var pasoConfirmar: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("¿Alguna nota?")
                        .font(.title2.bold())
                        .foregroundStyle(Color("Navy"))
                    Text("Opcional — cualquier observación del trabajo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField("Observaciones (opcional)", text: $notas, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

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
            mensaje: esCambio ? "Cambio de coroplast registrado." : "Reparación registrada.",
            delay: 1.5
        )
    }

    private var exitoOfflineOverlay: some View {
        exitoView(
            icono: "wifi.slash",
            color: .orange,
            mensaje: "Se enviará automáticamente cuando haya señal.",
            delay: 2.2
        )
    }

    private func exitoView(icono: String, color: Color, mensaje: String, delay: Double) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.system(size: 60))
                    .foregroundStyle(color)
                Text(icono == "wifi.slash" ? "Guardado sin internet" : "¡Registrado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(mensaje)
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

    // MARK: - Helpers

    private var todasCarasAsignadas: Bool {
        !caras.isEmpty && caras.allSatisfy { $0.nuevaCampana != nil }
    }

    private func opcionButton(icono: String, titulo: String, subtitulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.title2)
                    .foregroundStyle(Color("Navy"))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("Navy").opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

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

    private func retroceder() {
        withAnimation(.easeInOut(duration: 0.2)) {
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
        let antesData = fotoAntesUI?.jpegData(compressionQuality: 0.85)
        let despuesData = fotoDespuesUI?.jpegData(compressionQuality: 0.85)
        let notasVal = notas.isEmpty ? nil : notas

        guard OfflineQueueService.shared.isConnected else {
            switch tipo {
            case .reparacion:
                OfflineQueueService.shared.encolar(AccionPendiente(
                    tipo: .reparacionCoroplast,
                    estructuraId: estructura.id,
                    rutaSemanaId: rutaSemanaId,
                    userId: userId,
                    fotoAntesData: antesData,
                    fotoDespuesData: despuesData,
                    notas: notasVal
                ))
            case .cambio:
                let carasPendientes = caras.compactMap { cara -> AccionPendiente.CaraPendiente? in
                    guard let campana = cara.nuevaCampana else { return nil }
                    return AccionPendiente.CaraPendiente(caraId: cara.id, campanaId: campana.id)
                }
                OfflineQueueService.shared.encolar(AccionPendiente(
                    tipo: .cambioCoroplast,
                    estructuraId: estructura.id,
                    rutaSemanaId: rutaSemanaId,
                    userId: userId,
                    estadoEstructura: estructura.estado.rawValue,
                    caras: carasPendientes,
                    fotoAntesData: antesData,
                    fotoDespuesData: despuesData,
                    notas: notasVal
                ))
            }
            withAnimation { exitoOffline = true }
            return
        }

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let antesUrl = try await subirFoto(antesData, sufijo: "antes", userId: userId)
                let despuesUrl = try await subirFoto(despuesData, sufijo: "despues", userId: userId)

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

    private func subirFoto(_ data: Data?, sufijo: String, userId: UUID) async throws -> String? {
        guard let data else { return nil }
        let path = "\(userId.uuidString)/\(UUID().uuidString)_\(sufijo).jpg"
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
                    .foregroundStyle(Color("Navy"))
                Spacer()
                if let actual = cara.campanaActual {
                    Text("Actual: \(actual.nombre)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button { showPicker = true } label: {
                HStack(spacing: 12) {
                    if let nueva = cara.nuevaCampana {
                        CampanaThumbnail(campana: nueva, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nueva.nombre)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Label("Campaña asignada", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("Navy").opacity(0.08))
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus.circle.dashed")
                                .font(.title2)
                                .foregroundStyle(Color("Navy"))
                        }
                        Text("Tocar para elegir campaña")
                            .font(.subheadline)
                            .foregroundStyle(Color("Navy"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
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

struct CampanaThumbnail: View {
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

struct CampanaPickerSheet: View {
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
                        CampanaThumbnail(campana: campana, size: 80)
                        Text(campana.nombre)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if seleccionada?.id == campana.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("Navy"))
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
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color("Navy"))
                }
            }
        }
    }
}
