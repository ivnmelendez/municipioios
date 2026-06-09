import SwiftUI
import PhotosUI

private enum Paso { case seleccion, foto, confirmar }

struct ReportarDanoView: View {
    let estructura: EstructuraConParque
    let userId: UUID?
    var rutaSemanaId: UUID? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var paso: Paso = .seleccion
    @State private var tipoDano: TipoDano? = nil
    @State private var notas: String = ""
    @State private var fotoItem: PhotosPickerItem?
    @State private var fotoUI: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exito = false
    @State private var avanzando = true

    private var pasoNumero: Int {
        switch paso {
        case .seleccion: return 1
        case .foto:      return 2
        case .confirmar: return 3
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
                    if paso == .seleccion { pasoSeleccion.transition(transicion) }
                    if paso == .foto      { pasoFoto.transition(transicion) }
                    if paso == .confirmar { pasoConfirmar.transition(transicion) }
                }
                .animation(.spring(duration: 0.35), value: paso)

                Spacer()
            }
            .navigationTitle("Reportar daño")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if paso == .seleccion {
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

    // MARK: - Header

    private var estructuraHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(estructura.numero)
                    .font(.title3.bold())
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
            ForEach(1...3, id: \.self) { n in
                Capsule()
                    .fill(n <= pasoNumero ? Color.orange : Color.secondary.opacity(0.3))
                    .frame(width: n == pasoNumero ? 28 : 10, height: 8)
                    .animation(.spring(duration: 0.3), value: pasoNumero)
            }
        }
    }

    // MARK: - Paso 1: Selección de daño

    private var pasoSeleccion: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("¿Qué daño tiene?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Paso 1 de 3")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                opcionButton(
                    icono: "exclamationmark.triangle.fill",
                    color: .orange,
                    titulo: "Coroplast roto",
                    subtitulo: "El coroplast está puesto pero en mal estado",
                    destacado: true
                ) {
                    tipoDano = .coroplast_roto
                    avanzar(a: .foto)
                }

                opcionButton(
                    icono: "minus.circle.fill",
                    color: .orange,
                    titulo: "Sin coroplast",
                    subtitulo: "No tiene coroplast puesto",
                    destacado: true
                ) {
                    tipoDano = .sin_coroplast
                    avanzar(a: .foto)
                }

                Divider().padding(.vertical, 4)

                opcionButton(
                    icono: "xmark.octagon.fill",
                    color: .secondary,
                    titulo: "Estructura destruida",
                    subtitulo: "Fue derribada o está irreparable",
                    destacado: false
                ) {
                    tipoDano = .destruida
                    avanzar(a: .foto)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso 2: Foto

    private var pasoFoto: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Foto del daño")
                    .font(.title2.bold())
                Text("Toma una foto que muestre claramente el daño")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("Paso 2 de 3")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            PhotosPicker(selection: $fotoItem, matching: .images) {
                ZStack {
                    if let img = fotoUI {
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
                                        .foregroundStyle(.orange)
                                    Text("Tocar para tomar foto")
                                        .font(.headline)
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
            .padding(.horizontal, 20)

            continuar(habilitado: fotoUI != nil) {
                avanzar(a: .confirmar)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Paso 3: Confirmar

    private var pasoConfirmar: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("¿Alguna nota antes de enviar?")
                        .font(.title2.bold())
                    Text("Paso 3 de 3")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notas")
                        .font(.headline)
                    TextField("Describe qué pasó (opcional)", text: $notas, axis: .vertical)
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
                    .background(
                        tipoDano == .destruida ? Color.red : Color.orange,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
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
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("¡Reporte enviado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if let tipo = tipoDano {
                    Text("La estructura fue marcada como \(tipo.estadoResultante.rawValue).")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
        }
    }

    // MARK: - Helpers

    private func opcionButton(icono: String, color: Color, titulo: String, subtitulo: String, destacado: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 16) {
                Image(systemName: icono)
                    .font(destacado ? .title : .title2)
                    .foregroundStyle(color)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(destacado ? .headline : .subheadline)
                        .foregroundStyle(destacado ? .primary : .secondary)
                        .multilineTextAlignment(.leading)
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold()).foregroundStyle(.tertiary)
            }
            .padding(destacado ? 18 : 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(destacado ? 0.25 : 0.1), lineWidth: destacado ? 1.5 : 1)
            )
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
                habilitado ? Color.orange : Color.secondary.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(!habilitado)
    }

    private func avanzar(a nuevoPaso: Paso) {
        avanzando = true
        withAnimation { paso = nuevoPaso }
    }

    private func retroceder() {
        avanzando = false
        withAnimation {
            switch paso {
            case .seleccion: break
            case .foto:      paso = .seleccion
            case .confirmar: paso = .foto
            }
        }
    }

    private func enviar() {
        guard let userId, let tipoDano else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                var fotoUrl: String? = nil
                if let img = fotoUI, let data = img.jpegData(compressionQuality: 0.8) {
                    let path = "\(userId.uuidString)/\(UUID().uuidString)_dano.jpg"
                    fotoUrl = try? await CoroplastService.shared.uploadFoto(data: data, path: path)
                }
                try await CoroplastService.shared.reportarDano(
                    estructuraId: estructura.id,
                    userId: userId,
                    rutaSemanaId: rutaSemanaId,
                    tipoDano: tipoDano,
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
