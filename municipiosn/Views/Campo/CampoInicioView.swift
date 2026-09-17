import SwiftUI
import UIKit

private extension View {
    func intro(_ aparecer: Bool, delay: Double) -> some View {
        self
            .opacity(aparecer ? 1 : 0)
            .offset(y: aparecer ? 0 : 16)
            .animation(.spring(duration: 0.5, bounce: 0.1).delay(delay), value: aparecer)
    }
}

struct CampoInicioView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var fotoPerfil: Image? = nil
    @State private var aparecer = false
    @State private var mostrarConfiguracion = false
    @State private var avisos: [EstructuraConParque] = []
    @State private var cargandoAvisos = false
    @State private var estructuraSeleccionada: EstructuraConParque?

    @AppStorage("perfil_avatar_url_cache") private var avatarUrlCached = ""

    private var saludo: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let hora = cal.component(.hour, from: Date())
        switch hora {
        case 6..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default:      return "Buenas noches"
        }
    }

    private var fechaFormateada: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "EEEE, d 'de' MMMM"
        let raw = fmt.string(from: Date())
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private func cargarFotoPerfil(forzar: Bool = false) {
        let localUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perfil.jpg")
        let remoteUrlStr = auth.avatarUrl ?? ""

        if !remoteUrlStr.isEmpty,
           let url = URL(string: remoteUrlStr + "?v=\(Int(Date().timeIntervalSince1970))"),
           forzar || remoteUrlStr != avatarUrlCached {
            Task {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let uiImage = UIImage(data: data) {
                    fotoPerfil = Image(uiImage: uiImage)
                    try? data.write(to: localUrl)
                    avatarUrlCached = remoteUrlStr
                }
            }
            return
        }

        Task.detached(priority: .userInitiated) {
            let data = try? Data(contentsOf: localUrl)
            let image = data.flatMap(UIImage.init(data:)).map(Image.init(uiImage:))
            await MainActor.run { [image] in fotoPerfil = image }
        }
    }

    private func cargarAvisos() async {
        cargandoAvisos = true
        avisos = (try? await EstructurasService.shared.fetchEstructurasConAvisoCoroplast()) ?? []
        cargandoAvisos = false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 28)

                    if cargandoAvisos {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .intro(aparecer, delay: 0.08)
                    } else if !avisos.isEmpty {
                        AvisosReportesCard(avisos: avisos) { e in
                            estructuraSeleccionada = e
                        }
                        .padding(.horizontal, 20)
                        .intro(aparecer, delay: 0.08)
                    }
                }
                .padding(.bottom, 48)
            }
            .background(
                LinearGradient(
                    colors: [Color("Background").opacity(0.6), Color("Background")],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $estructuraSeleccionada) { e in
                CampoEstructuraDetalleView(
                    estructura: e,
                    userId: auth.perfilId,
                    campanas: [],
                    rutaSemanaId: nil,
                    yaVisitada: false,
                    requiereFoto: false
                )
            }
        }
        .task {
            cargarFotoPerfil()
            if avisos.isEmpty { await cargarAvisos() }
            aparecer = true
        }
        .refreshable { await cargarAvisos() }
        .sheet(isPresented: $mostrarConfiguracion) {
            ConfiguracionView(vm: nil)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarActualizado)) { _ in
            avatarUrlCached = ""
            cargarFotoPerfil(forzar: true)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(saludo)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color("Navy"))

                Text(fechaFormateada)
                    .font(.subheadline)
                    .foregroundStyle(Color("TextMuted"))
            }
            .intro(aparecer, delay: 0.0)

            Spacer()

            Button { mostrarConfiguracion = true } label: {
                if let foto = fotoPerfil {
                    foto.resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } else {
                    Text(auth.initiales.isEmpty ? "?" : auth.initiales)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("Navy"))
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .opacity(aparecer ? 1 : 0)
            .animation(.spring(duration: 0.5, bounce: 0.1).delay(0.05), value: aparecer)
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification)) { _ in cargarFotoPerfil() }
        }
    }
}

// MARK: - Avisos Card

private struct AvisosReportesCard: View {
    let avisos: [EstructuraConParque]
    let onSelect: (EstructuraConParque) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reportes a atender")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                Text("\(avisos.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("Navy"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                ForEach(Array(avisos.enumerated()), id: \.element.id) { index, e in
                    Button { onSelect(e) } label: { fila(e) }
                        .buttonStyle(.plain)
                    if index < avisos.count - 1 {
                        Divider().padding(.leading, 20)
                    }
                }
            }

            Spacer(minLength: 8)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func fila(_ e: EstructuraConParque) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estructura \(e.numero)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                    .lineLimit(1)
                if let parque = e.parques?.nombre {
                    Text(parque)
                        .font(.caption)
                        .foregroundStyle(Color("TextMuted"))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("TextMuted").opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
