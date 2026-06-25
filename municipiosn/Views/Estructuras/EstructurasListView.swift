import SwiftUI
import MapKit

@MainActor
@Observable
final class EstructurasListViewModel {
    var estructuras: [EstructuraConParque] = []
    var filtradas: [EstructuraConParque] = []
    var busqueda = ""
    var filtroEstado: EstadoEstructura?
    var isLoading = false
    var errorMessage: String?

    init(filtroInicial: EstadoEstructura? = nil) {
        self.filtroEstado = filtroInicial
    }

    func cargar() async {
        if estructuras.isEmpty, let cached = LocalDataCache.shared.cargar([EstructuraConParque].self, clave: "estructuras_lista") {
            estructuras = cached
            filtrar()
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let nuevas = try await EstructurasService.shared.fetchEstructuras()
            estructuras = nuevas
            LocalDataCache.shared.guardar(nuevas, clave: "estructuras_lista")
            filtrar()
        } catch {
            if estructuras.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    func filtrar() {
        var base = estructuras.sorted { $0.numero.localizedStandardCompare($1.numero) == .orderedAscending }
        if let filtro = filtroEstado { base = base.filter { $0.estado == filtro } }
        guard !busqueda.isEmpty else { filtradas = base; return }
        filtradas = base.filter {
            $0.numero.localizedCaseInsensitiveContains(busqueda) ||
            ($0.numeroLocal?.localizedCaseInsensitiveContains(busqueda) ?? false) ||
            ($0.parques?.nombre.localizedCaseInsensitiveContains(busqueda) ?? false) ||
            ($0.parques?.colonias?.nombre.localizedCaseInsensitiveContains(busqueda) ?? false)
        }
    }
}

// MARK: - Main View (no NavigationStack — parent provides it)

private let estadosFiltro: [EstadoEstructura] = [.activa, .dañada, .inactiva]

struct EstructurasListView: View {
    var filtroInicial: EstadoEstructura? = nil
    @State private var vm: EstructurasListViewModel
    @FocusState private var searchFocused: Bool
    @State private var showFloatingSearch = false

    init(filtroInicial: EstadoEstructura? = nil) {
        self.filtroInicial = filtroInicial
        self._vm = State(wrappedValue: EstructurasListViewModel(filtroInicial: filtroInicial))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    BuscadorGlass(
                        busqueda: $vm.busqueda,
                        searchFocused: $searchFocused,
                        onClear: { vm.busqueda = ""; vm.filtrar() }
                    )
                    .id("searchBar")
                    .onChange(of: vm.busqueda) { vm.filtrar() }

                    FiltroChips(
                        filtroActivo: vm.filtroEstado,
                        onSelect: { estado in
                            vm.filtroEstado = vm.filtroEstado == estado ? nil : estado
                            vm.filtrar()
                        }
                    )

                    if !vm.estructuras.isEmpty {
                        HStack {
                            let isFiltered = vm.filtroEstado != nil || !vm.busqueda.isEmpty
                            Text(isFiltered
                                 ? "\(vm.filtradas.count) resultado\(vm.filtradas.count == 1 ? "" : "s")"
                                 : "\(vm.estructuras.count) estructuras")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color("TextMuted"))
                                .contentTransition(.numericText())
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    ListaEstructuras(filtradas: vm.filtradas, isLoading: vm.isLoading,
                                     busqueda: vm.busqueda, filtroEstado: vm.filtroEstado)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color("Background"))
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y > 80
            } action: { _, scrolled in
                withAnimation(.spring(duration: 0.3)) { showFloatingSearch = scrolled }
            }
            .overlay(alignment: .top) {
                if showFloatingSearch {
                    BuscadorGlass(
                        busqueda: $vm.busqueda,
                        searchFocused: $searchFocused,
                        onClear: { vm.busqueda = ""; vm.filtrar() }
                    )
                    .onChange(of: vm.busqueda) { vm.filtrar() }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(tituloNavegacion)
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
    }

    private var tituloNavegacion: String {
        switch filtroInicial {
        case .dañada:    return "Estructuras dañadas"
        case .activa:    return "Estructuras activas"
        case .inactiva:  return "Estructuras inactivas"
        default:         return ""
        }
    }
}

// MARK: - Buscador

private struct BuscadorGlass: View {
    @Binding var busqueda: String
    var searchFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        Button { searchFocused.wrappedValue = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15, weight: .medium))
                TextField("Número, parque o colonia", text: $busqueda)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused(searchFocused)
                    .onSubmit { searchFocused.wrappedValue = false }
                if !busqueda.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.horizontal, 20)
    }
}

// MARK: - Filtro Chips

private struct FiltroChips: View {
    let filtroActivo: EstadoEstructura?
    let onSelect: (EstadoEstructura?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton("Todas", isActive: filtroActivo == nil) { onSelect(nil) }
                ForEach(estadosFiltro, id: \.self) { estado in
                    chipButton(estado.etiqueta, isActive: filtroActivo == estado) { onSelect(estado) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func chipButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isActive ? Color("Background") : Color("Navy"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isActive ? Color("Navy") : Color("Navy").opacity(0.08), in: Capsule())
                .scaleEffect(isActive ? 1.04 : 1.0)
                .animation(.spring(duration: 0.3, bounce: 0.4), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lista

private struct ListaEstructuras: View {
    let filtradas: [EstructuraConParque]
    let isLoading: Bool
    let busqueda: String
    let filtroEstado: EstadoEstructura?

    @State private var appeared = false
    @State private var listKey = UUID()

    var body: some View {
        if isLoading && filtradas.isEmpty {
            LazyVStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    EstructuraRowSkeleton()
                    Divider().padding(.leading, 20)
                }
            }
            .padding(.horizontal, 20)
        } else if filtradas.isEmpty && !busqueda.isEmpty {
            ContentUnavailableView.search(text: busqueda).padding(.top, 40)
        } else if filtradas.isEmpty && filtroEstado != nil {
            ContentUnavailableView(
                "Sin estructuras",
                systemImage: filtroEstado?.icono ?? "square.stack",
                description: Text("No hay estructuras con estado \"\(filtroEstado?.etiqueta ?? "")\"")
            )
            .padding(.top, 40)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(filtradas.enumerated()), id: \.element.id) { index, estructura in
                    NavigationLink(value: estructura) {
                        EstructuraRow(estructura: estructura)
                    }
                    .buttonStyle(RowButtonStyle())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(
                        .spring(duration: 0.4, bounce: 0.08).delay(Double(min(index, 14)) * 0.035),
                        value: appeared
                    )
                    Divider().padding(.leading, 20)
                }
            }
            .padding(.horizontal, 20)
            .id(listKey)
            .onAppear { appeared = true }
            .onChange(of: filtroEstado) { _, _ in triggerAnimation() }
        }
    }

    private func triggerAnimation() {
        appeared = false
        listKey = UUID()
        Task { @MainActor in appeared = true }
    }
}

private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.secondary.opacity(0.08) : Color.clear)
    }
}

// MARK: - Row

struct EstructuraRow: View {
    let estructura: EstructuraConParque

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(estructura.numero)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let local = estructura.numeroLocal, !local.isEmpty {
                        Text(local)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                    if estructura.estado == .dañada {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#dc2626"))
                    }
                }
                if let parque = estructura.parques {
                    Text(parque.nombre).font(.subheadline).foregroundStyle(.secondary)
                    if let colonia = parque.colonias {
                        Text(colonia.nombre).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Skeleton Row

private struct EstructuraRowSkeleton: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)).frame(width: 80, height: 13)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.10)).frame(width: 150, height: 11)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)).frame(width: 110, height: 10)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(0.4 + 0.6 * abs(sin(phase)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) { phase = .pi }
        }
    }
}

// MARK: - Navbar configurator

private struct TransparentNavBar: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var responder: UIResponder? = uiView
            while let r = responder {
                if let nav = r as? UINavigationController {
                    let clear = UINavigationBarAppearance()
                    clear.configureWithTransparentBackground()
                    nav.navigationBar.standardAppearance = clear
                    nav.navigationBar.scrollEdgeAppearance = clear
                    nav.navigationBar.compactAppearance = clear
                    nav.navigationBar.compactScrollEdgeAppearance = clear
                    break
                }
                responder = r.next
            }
        }
    }
}

// MARK: - Detalle

struct EstructuraDetalleView: View {
    let estructura: EstructuraConParque
    var esCampo: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isLandscape = false
    @State private var caras: [CaraDetalle] = []
    @State private var historial: [IntervencionCompleta] = []
    @State private var isLoading = true
    @State private var fotoFullscreen: IdentifiableURL?
    @State private var campanas: [CampanaBasica] = []
    @State private var caraParaCambio: CaraDetalle? = nil
    @State private var campanaSeleccionada: CampanaBasica? = nil
    @State private var mostrarMapaCompleto = false

    var body: some View {
        Group {
            if sizeClass == .regular && isLandscape {
                iPadLayout          // landscape iPad: dos columnas
            } else if sizeClass == .regular {
                iPadPortraitLayout  // portrait iPad: columna única ampliada
            } else {
                iPhoneLayout        // iPhone: layout actual
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { isLandscape = geo.size.width > geo.size.height }
                    .onChange(of: geo.size) { _, size in isLandscape = size.width > size.height }
            }
        )
        .background {
            Color(.systemGray6).ignoresSafeArea()
            if let fotoUrl = estructura.fotoUrl, let url = URL(string: fotoUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.4)
                            .blur(radius: 60)
                            .opacity(0.45)
                            .ignoresSafeArea()
                            .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                    }
                }
            }
        }
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
            ToolbarItem(placement: .primaryAction) {
                Image(systemName: estructura.estado.icono)
                    .foregroundStyle(estructura.estado.color)
                    .font(.footnote)
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
        .task {
            async let carasTask = EstructurasService.shared.fetchCarasDetalle(estructuraId: estructura.id)
            async let historialTask = IntervencionesService.shared.fetchHistorial(estructuraId: estructura.id)
            caras = (try? await carasTask) ?? []
            historial = (try? await historialTask) ?? []
            isLoading = false
            if esCampo {
                campanas = (try? await EstructurasService.shared.fetchCampanasActivas()) ?? []
            }
        }
        .sheet(item: $caraParaCambio) { cara in
            CampanaPickerSheet(campanas: campanas, seleccionada: $campanaSeleccionada)
                .onDisappear {
                    guard let nuevaCampana = campanaSeleccionada else { return }
                    Task {
                        try? await EstructurasService.shared.asignarCampana(caraId: cara.id, campanaId: nuevaCampana.id)
                        caras = (try? await EstructurasService.shared.fetchCarasDetalle(estructuraId: estructura.id)) ?? caras
                    }
                }
        }
        .fullScreenCover(item: $fotoFullscreen) { (item: IdentifiableURL) in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
        }
    }

    // MARK: - iPhone layout (vertical, hero arriba)
    private var iPhoneLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage(height: 500)
                contentCards
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - iPad portrait (columna única, hero más alto)
    private var iPadPortraitLayout: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage(height: 700)
                contentCards
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - iPad landscape (2 columnas)
    private var iPadLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Columna izquierda — ancho fijo 45%
                heroImage(height: nil)
                    .frame(width: geo.size.width * 0.45)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(edges: .vertical)

                // Columna derecha — ancho fijo 55%
                ScrollView {
                    contentCards
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

                AsyncImage(url: url) { phase in
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

    // MARK: - Content cards (compartidos iPhone / iPad)
    private var contentCards: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Info card — tappable, va al mapa
            if let parque = estructura.parques {
                Button {
                    if let lat = estructura.lat, let lng = estructura.lng {
                        NotificationCenter.default.post(
                            name: .abrirMapaEnEstructura,
                            object: nil,
                            userInfo: ["lat": lat, "lng": lng]
                        )
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            if let colonia = parque.colonias {
                                Label(colonia.nombre, systemImage: "map.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            Label(parque.nombre, systemImage: "tree.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let fecha = estructura.fechaInstalacion {
                                Label(fecha.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            // Campañas
            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                if !caras.isEmpty {
                    CampanasSideBySideView(
                        caras: caras,
                        onTapFoto: { url, titulo in
                            fotoFullscreen = IdentifiableURL(url: url, titulo: titulo)
                        },
                        onCambiarCampana: esCampo ? { cara in
                            campanaSeleccionada = cara.campana.flatMap { c in campanas.first { $0.id == c.id } }
                            caraParaCambio = cara
                        } : nil
                    )
                    .padding(.top, 8)
                }

                if !historial.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Historial")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(historial) { item in
                                HistorialRow(item: item)
                                if item.id != historial.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                    }
                }
            }

            if let notas = estructura.notas, !notas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notas")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notas).font(.subheadline)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            if let lat = estructura.lat, let lng = estructura.lng {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                Button { mostrarMapaCompleto = true } label: {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                    ))) {
                        Marker(estructura.numero, coordinate: coord)
                            .tint(Color("Navy"))
                    }
                    .frame(height: 200)
                    .allowsHitTesting(false)
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .fullScreenCover(isPresented: $mostrarMapaCompleto) {
                    MapaEstructuraFullView(
                        numero: estructura.numero,
                        coordinate: coord
                    )
                }
            }

            Spacer().frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    private func abrirGoogleMaps(lat: Double, lng: Double) {
        let gm = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")!
        let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving")!
        UIApplication.shared.open(gm) { success in
            if !success { UIApplication.shared.open(web) }
        }
    }
}

// MARK: - Fullscreen map

private struct MapaEstructuraFullView: View {
    let numero: String
    let coordinate: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            ))) {
                Marker(numero, coordinate: coordinate)
                    .tint(Color("Navy"))
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(numero)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
}

// MARK: - Historial Row

private struct HistorialRow: View {
    let item: IntervencionCompleta

    private var accionInfo: (icono: String, label: String, color: Color) {
        switch item.accion {
        case .revision:         return ("checkmark.circle.fill",       "Revisión",              Color(hex: "#16a34a"))
        case .cambio_coroplast: return ("arrow.2.squarepath",          "Cambio de coroplast",   Color("Navy"))
        case .reparacion_coroplast: return ("wrench.and.screwdriver.fill", "Reparación de coroplast", Color("Navy"))
        case .reporte_dano:     return ("exclamationmark.triangle.fill","Daño reportado",        Color(hex: "#dc2626"))
        case .reactivacion:     return ("arrow.clockwise",             "Reactivación",          Color(hex: "#16a34a"))
        case .instalacion:      return ("plus.circle.fill",            "Instalación",           Color("Navy"))
        case .cambio_campana:   return ("megaphone.fill",              "Cambio de campaña",     Color("Navy"))
        case .reparacion:       return ("hammer.fill",                 "Reparación",            Color("Navy"))
        }
    }

    var body: some View {
        let info = accionInfo
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.icono)
                .font(.title3)
                .foregroundStyle(info.color)
                .frame(width: 36)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Color("TextMuted"))
                    if let nombre = item.rondines?.perfiles?.nombre {
                        Text("·").font(.caption).foregroundStyle(Color("TextMuted"))
                        Text(nombre).font(.caption).foregroundStyle(Color("TextMuted"))
                    }
                }

                if let notas = item.notas, !notas.isEmpty {
                    Text(notas)
                        .font(.caption)
                        .foregroundStyle(Color("TextMuted"))
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
