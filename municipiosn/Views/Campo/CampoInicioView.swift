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
    @State private var navegarAvisos = false

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
                        .intro(aparecer, delay: 0.0)

                    if cargandoAvisos {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .intro(aparecer, delay: 0.08)
                    } else if !avisos.isEmpty {
                        AvisosReportesCard(avisos: avisos) {
                            HapticService.impacto(.medium)
                            navegarAvisos = true
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
            .navigationDestination(isPresented: $navegarAvisos) {
                CampoAvisosListView(avisos: avisos)
            }
        }
        .task {
            aparecer = true
            await cargarAvisos()
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
            .onAppear { cargarFotoPerfil() }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification)) { _ in cargarFotoPerfil() }
        }
    }
}

// MARK: - Avisos Card

private struct AvisosReportesCard: View {
    let avisos: [EstructuraConParque]
    let onTap: () -> Void

    private var sinCoroplast: Int { avisos.filter { $0.coroplastEstado == "sin_coroplast" }.count }
    private var coroplastRoto: Int { avisos.filter { $0.coroplastEstado == "coroplast_roto" }.count }
    private var preview: [EstructuraConParque] { Array(avisos.prefix(5)) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Reportes a atender")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    HStack(spacing: 6) {
                        if sinCoroplast > 0 {
                            Label("\(sinCoroplast)", systemImage: "square.slash.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "#ea580c"))
                        }
                        if coroplastRoto > 0 {
                            Label("\(coroplastRoto)", systemImage: "exclamationmark.square.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "#d97706"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Rows
                VStack(spacing: 0) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { index, e in
                        fila(e)
                        if index < preview.count - 1 {
                            Divider().padding(.leading, 20)
                        }
                    }
                }

                // Footer si hay más de 5
                if avisos.count > 5 {
                    Divider().padding(.leading, 20)
                    HStack {
                        Text("Ver los \(avisos.count) reportes")
                            .font(.subheadline)
                            .foregroundStyle(Color("Azul"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("Azul").opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }

                Spacer(minLength: 8)
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
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
            if e.coroplastEstado == "sin_coroplast" {
                Image(systemName: "square.slash.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#ea580c"))
            } else {
                Image(systemName: "exclamationmark.square.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#d97706"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
