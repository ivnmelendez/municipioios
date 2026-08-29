import SwiftUI

struct CampoEstructuraDetalleView: View {
    let estructura: EstructuraConParque
    let userId: UUID?
    let campanas: [CampanaBasica]
    let rutaSemanaId: UUID?
    let yaVisitada: Bool
    var requiereFoto: Bool = true
    var onMarcarRevision: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isLandscape = false
    @State private var fotoFullscreen: IdentifiableURL?
    @State private var mostrarRegistrarCoroplast = false
    @State private var mostrarAvisoCoroplast = false
    @State private var mostrarReportarDano = false
    @State private var mostrarReportarMantenimiento = false
    @State private var mostrarMantenimientoRealizado = false
    @State private var mostrarReparacionRealizada = false

    var body: some View {
        ZStack {
            // Blur background FUERA del NavigationStack — iOS 26 lo tapa si va adentro
            Color(.systemGray6).ignoresSafeArea()

            NavigationStack {
                Group {
                    if sizeClass == .regular && isLandscape {
                        iPadLandscapeLayout
                    } else if sizeClass == .regular {
                        iPadPortraitLayout
                    } else {
                        iPhoneLayout
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { isLandscape = geo.size.width > geo.size.height }
                            .onChange(of: geo.size) { _, size in isLandscape = size.width > size.height }
                    }
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { dismiss() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left").fontWeight(.semibold)
                                Text(estructura.numero).fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(Color("Navy"))
                    }
                    if let lat = estructura.lat, let lng = estructura.lng {
                        ToolbarItem(placement: .primaryAction) {
                            Button { abrirGoogleMaps(lat: lat, lng: lng) } label: {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                }
                .sheet(isPresented: $mostrarRegistrarCoroplast) {
                    RegistrarCoroplastView(
                        estructura: estructura,
                        campanas: campanas,
                        userId: userId,
                        rutaSemanaId: rutaSemanaId,
                        requiereFoto: requiereFoto
                    )
                }
                .sheet(isPresented: $mostrarAvisoCoroplast) {
                    AvisoCoroplastView(estructura: estructura, userId: userId, rutaSemanaId: rutaSemanaId)
                }
                .sheet(isPresented: $mostrarReportarDano) {
                    ReportarDanoView(estructura: estructura, userId: userId, rutaSemanaId: rutaSemanaId)
                }
                .sheet(isPresented: $mostrarReportarMantenimiento) {
                    ReportarMantenimientoView(estructura: estructura, userId: userId, rutaSemanaId: rutaSemanaId)
                }
                .sheet(isPresented: $mostrarMantenimientoRealizado) {
                    MantenimientoRealizadoView(estructura: estructura, userId: userId, rutaSemanaId: rutaSemanaId)
                }
                .sheet(isPresented: $mostrarReparacionRealizada) {
                    ReparacionRealizadaView(estructura: estructura, userId: userId, rutaSemanaId: rutaSemanaId)
                }
                .fullScreenCover(item: $fotoFullscreen) { (item: IdentifiableURL) in
                    FotoFullscreenView(url: item.url, titulo: item.titulo)
                }
            }
            .background(Color.clear)
        } // ZStack
    }

    // MARK: - Layouts

    private var iPhoneLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage(height: 500)
                contentSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    private var iPadPortraitLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage(height: 700)
                contentSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    private var iPadLandscapeLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                heroImage(height: nil)
                    .frame(width: geo.size.width * 0.45)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(edges: .vertical)

                ScrollView {
                    contentSection
                        .padding(.top, 12)
                }
                .frame(width: geo.size.width * 0.55)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Hero image

    @ViewBuilder
    private func heroImage(height: CGFloat?) -> some View {
        if let fotoUrl = estructura.fotoUrl, let url = URL(string: fotoUrl) {
            ZStack {
                Color(.systemGray5)
                    .frame(maxWidth: .infinity, maxHeight: height ?? .infinity)
                CachedAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        Button {
                            fotoFullscreen = IdentifiableURL(url: url, titulo: estructura.numero)
                        } label: {
                            image.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: height ?? .infinity)
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.animation(.easeOut(duration: 0.5)))
                    } else if case .failure = phase {
                        EmptyView()
                    } else {
                        ProgressView().tint(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height ?? .infinity)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 16) {
            infoCard
            if userId != nil { accionesCard }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 40)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let parque = estructura.parques {
                if let colonia = parque.colonias {
                    Label(colonia.nombre, systemImage: "map.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Label(parque.nombre, systemImage: "tree.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let fecha = estructura.fechaInstalacion {
                Label(fecha.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }

    private var accionesCard: some View {
        VStack(spacing: 10) {
            accionBtn(
                titulo: yaVisitada ? "Revisada hoy" : "Está bien",
                icono: yaVisitada ? "checkmark.circle" : "checkmark.circle.fill",
                color: .green,
                disabled: yaVisitada
            ) {
                HapticService.impacto(.medium)
                onMarcarRevision?()
                dismiss()
            }

            accionBtn(titulo: "Registrar coroplast", icono: "square.and.pencil", color: Color("Navy")) {
                mostrarRegistrarCoroplast = true
            }

            if let coroplastEstado = estructura.coroplastEstado {
                coroplastBadge(estado: coroplastEstado)
            } else if estructura.estado != .inactiva && estructura.estado != .destruida {
                accionBtn(titulo: "Aviso coroplast", icono: "bell.fill", color: Color(hex: "#ea580c")) {
                    mostrarAvisoCoroplast = true
                }
            }

            if estructura.estado != .dañada {
                accionBtn(titulo: "Reportar daño", icono: "exclamationmark.triangle.fill", color: .red) {
                    mostrarReportarDano = true
                }
            }

            if estructura.estado == .dañada {
                accionBtn(titulo: "Reparación realizada", icono: "hammer.fill", color: .green) {
                    mostrarReparacionRealizada = true
                }
            }

            if estructura.estado != .necesita_mantenimiento && estructura.estado != .dañada {
                accionBtn(titulo: "Reportar mantenimiento", icono: "wrench.fill", color: .orange) {
                    mostrarReportarMantenimiento = true
                }
            }

            if estructura.estado == .necesita_mantenimiento {
                accionBtn(titulo: "Mantenimiento realizado", icono: "checkmark.seal.fill", color: .green) {
                    mostrarMantenimientoRealizado = true
                }
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }

    private func coroplastBadge(estado: String) -> some View {
        let esSin = estado == "sin_coroplast"
        return HStack(spacing: 10) {
            Image(systemName: esSin ? "square.slash.fill" : "exclamationmark.square.fill")
                .foregroundStyle(esSin ? Color(hex: "#ea580c") : Color(hex: "#d97706"))
            VStack(alignment: .leading, spacing: 2) {
                Text(esSin ? "Sin coroplast" : "Coroplast dañado")
                    .font(.headline.weight(.bold))
                Text("Registra un coroplast para cerrar este aviso")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            (esSin ? Color(hex: "#ea580c") : Color(hex: "#d97706")).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    (esSin ? Color(hex: "#ea580c") : Color(hex: "#d97706")).opacity(0.4),
                    lineWidth: 1
                )
        )
    }

    private func accionBtn(titulo: String, icono: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(titulo, systemImage: icono)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .controlSize(.large)
        .disabled(disabled)
    }

    // MARK: - Helpers

    private func abrirGoogleMaps(lat: Double, lng: Double) {
        let gm = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")!
        let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving")!
        UIApplication.shared.open(gm) { success in
            if !success { UIApplication.shared.open(web) }
        }
    }
}
