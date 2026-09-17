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
    @State private var proximidad: ProximidadValidator? = nil
    @State private var isLoadingRevision = false
    @State private var mostrarRevisionConfirmada = false
    @State private var revisadaEnCiclo = false
    @State private var errorRevision: String? = nil

    var body: some View {
        ZStack {
            // Blur background FUERA del NavigationStack — iOS 26 lo tapa si va adentro
            Color("Background").ignoresSafeArea()

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
        .onAppear {
            if let lat = estructura.lat, let lng = estructura.lng, proximidad == nil {
                proximidad = ProximidadValidator(lat: lat, lng: lng)
            }
            Task {
                revisadaEnCiclo = (try? await CoroplastService.shared.fetchRevisadaEnCiclo(estructuraId: estructura.id)) ?? false
            }
        }
        .fullScreenCover(isPresented: $mostrarRevisionConfirmada) {
            RevisionConfirmadaView(estructura: estructura) {
                onMarcarRevision?()
                isLoadingRevision = false
                dismiss()
            }
        }
        .alert("Error al registrar", isPresented: .constant(errorRevision != nil)) {
            Button("OK") { errorRevision = nil }
        } message: { Text(errorRevision ?? "") }
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
        VStack(spacing: 12) {
            if proximidad?.cercano == true {
                let estaRevisada = yaVisitada || revisadaEnCiclo
                accionPrimaria(
                    titulo: estaRevisada ? "Ya revisada" : "Revisar",
                    icono: estaRevisada ? "checkmark.circle" : "checkmark.circle.fill",
                    color: .green,
                    disabled: estaRevisada,
                    loading: isLoadingRevision
                ) {
                    marcarEstaBien()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    accionCard(titulo: "Registrar coroplast", icono: "square.and.pencil", color: Color("Navy")) {
                        mostrarRegistrarCoroplast = true
                    }

                    if let coroplastEstado = estructura.coroplastEstado {
                        coroplastBadgeCard(estado: coroplastEstado)
                    } else if estructura.estado != .inactiva && estructura.estado != .destruida {
                        accionCard(titulo: "Aviso coroplast", icono: "bell.fill", color: Color(hex: "#ea580c")) {
                            mostrarAvisoCoroplast = true
                        }
                    }

                    if estructura.estado != .dañada {
                        accionCard(titulo: "Reportar daño", icono: "exclamationmark.triangle.fill", color: .red) {
                            mostrarReportarDano = true
                        }
                    }
                    if estructura.estado == .dañada {
                        accionCard(titulo: "Reparación realizada", icono: "hammer.fill", color: .green) {
                            mostrarReparacionRealizada = true
                        }
                    }

                    if estructura.estado != .necesita_mantenimiento && estructura.estado != .dañada {
                        accionCard(titulo: "Reportar mantenimiento", icono: "wrench.fill", color: .orange) {
                            mostrarReportarMantenimiento = true
                        }
                    }
                    if estructura.estado == .necesita_mantenimiento {
                        accionCard(titulo: "Mantenimiento realizado", icono: "checkmark.seal.fill", color: .green) {
                            mostrarMantenimientoRealizado = true
                        }
                    }
                }
            } else {
                lejosBanner
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }

    private var lejosBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: proximidad?.autorizado == false ? "location.slash.fill" : "location.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            if proximidad?.autorizado == false {
                Text("Activa el GPS para registrar acciones")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Acércate a la estructura para registrar acciones")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func coroplastBadgeCard(estado: String) -> some View {
        let esSin = estado == "sin_coroplast"
        let color = esSin ? Color(hex: "#ea580c") : Color(hex: "#d97706")
        let icono = esSin ? "square.slash.fill" : "exclamationmark.square.fill"
        let titulo = esSin ? "Sin coroplast" : "Coroplast dañado"
        return VStack(spacing: 10) {
            Image(systemName: icono)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("Navy"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 90)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func marcarEstaBien() {
        guard let userId else { return }
        Task {
            isLoadingRevision = true
            do {
                try await RutasService.shared.marcarRevision(
                    estructuraId: estructura.id,
                    rutaSemanaId: rutaSemanaId,
                    userId: userId
                )
                HapticService.exito()
                mostrarRevisionConfirmada = true
            } catch {
                errorRevision = error.localizedDescription
                isLoadingRevision = false
            }
        }
    }

    private func accionPrimaria(titulo: String, icono: String, color: Color, disabled: Bool = false, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView().tint(color)
                } else {
                    Label(titulo, systemImage: icono)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(disabled ? Color.secondary : color)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.glass(.regular))
        .tint(color)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(disabled || loading)
    }

    private func accionCard(titulo: String, icono: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icono)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(color)
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 90)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(disabled)
    }

    // MARK: - Helpers

    private func thumbnailURL(_ urlString: String, width: Int) -> URL? {
        guard urlString.contains("/object/public/") else { return URL(string: urlString) }
        let render = urlString.replacingOccurrences(of: "/object/public/", with: "/render/image/public/")
        return URL(string: "\(render)?width=\(width)&quality=72&resize=contain")
    }

    private func abrirGoogleMaps(lat: Double, lng: Double) {
        let gm = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")!
        let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving")!
        UIApplication.shared.open(gm) { success in
            if !success { UIApplication.shared.open(web) }
        }
    }
}

// MARK: - Revisión confirmada

private struct RevisionConfirmadaView: View {
    let estructura: EstructuraConParque
    let onDismiss: () -> Void

    @State private var anillo: Double = 0
    @State private var mostrarDetalle = false
    @State private var dismissed = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color(hex: "#16a34a").opacity(0.15), lineWidth: 6)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: anillo)
                        .stroke(Color(hex: "#16a34a"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: anillo)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color(hex: "#16a34a"))
                        .scaleEffect(mostrarDetalle ? 1 : 0)
                        .animation(.spring(duration: 0.4, bounce: 0.3).delay(0.5), value: mostrarDetalle)
                }

                Spacer().frame(height: 32)

                Text(estructura.numero)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("Navy"))
                    .opacity(mostrarDetalle ? 1 : 0)
                    .offset(y: mostrarDetalle ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.55), value: mostrarDetalle)

                Spacer().frame(height: 8)

                Text("Revisada")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(mostrarDetalle ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.65), value: mostrarDetalle)

                if let parque = estructura.parques {
                    Spacer().frame(height: 6)
                    Text(parque.nombre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(mostrarDetalle ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.72), value: mostrarDetalle)
                }

                Spacer()

                Button {
                    dismissed = true
                    onDismiss()
                } label: {
                    Text("Listo")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("Azul"), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(mostrarDetalle ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.85), value: mostrarDetalle)
            }
        }
        .onAppear {
            withAnimation { anillo = 1 }
            mostrarDetalle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if !dismissed { onDismiss() }
            }
        }
    }
}
