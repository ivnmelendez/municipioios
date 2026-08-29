import SwiftUI
import MapKit

@MainActor
@Observable
final class EstructurasListViewModel {
    var estructuras: [EstructuraConParque] = []
    var filtradas: [EstructuraConParque] = []
    var busqueda = ""
    var filtroEstado: EstadoEstructura?
    var filtroCoroplast: String?
    var isLoading = false
    var errorMessage: String?

    init(filtroInicial: EstadoEstructura? = nil, filtroCoroplast: String? = nil) {
        self.filtroEstado = filtroInicial
        self.filtroCoroplast = filtroCoroplast
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
        if let filtro = filtroCoroplast { base = base.filter { $0.coroplastEstado == filtro } }
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

private let estadosFiltro: [EstadoEstructura] = [.activa, .dañada, .necesita_mantenimiento, .inactiva]

struct EstructurasListView: View {
    var filtroInicial: EstadoEstructura? = nil
    var filtroCoroplast: String? = nil
    var esCampo: Bool = false
    @State private var vm: EstructurasListViewModel
    @FocusState private var searchFocused: Bool
    @State private var showFloatingSearch = false
    @State private var generandoPDF = false
    @State private var pdfURL: URL? = nil

    init(filtroInicial: EstadoEstructura? = nil, filtroCoroplast: String? = nil, esCampo: Bool = false) {
        self.filtroInicial = filtroInicial
        self.filtroCoroplast = filtroCoroplast
        self.esCampo = esCampo
        self._vm = State(wrappedValue: EstructurasListViewModel(filtroInicial: filtroInicial, filtroCoroplast: filtroCoroplast))
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

                    if filtroInicial == nil && filtroCoroplast == nil {
                        FiltroChips(
                            filtroActivo: vm.filtroEstado,
                            onSelect: { estado in
                                vm.filtroEstado = vm.filtroEstado == estado ? nil : estado
                                vm.filtrar()
                            }
                        )
                    }

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
                                     busqueda: vm.busqueda, filtroEstado: vm.filtroEstado, esCampo: esCampo)
                }
                .padding(.top, 4)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
        .toolbar {
            if filtroInicial == nil && filtroCoroplast == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await generarPDF() }
                    } label: {
                        if generandoPDF {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text")
                        }
                    }
                    .disabled(generandoPDF || vm.estructuras.isEmpty)
                }
            }
        }
        .sheet(item: Binding(
            get: { pdfURL.map { IdentifiablePDFURL(url: $0) } },
            set: { if $0 == nil { pdfURL = nil } }
        )) { item in
            ShareLink(
                item: item.url,
                preview: SharePreview("Estructuras municipio.pdf", image: Image(systemName: "doc.text.fill"))
            )
            .presentationDetents([.height(160)])
        }
    }

    private var tituloNavegacion: String { "" }

    private func generarPDF() async {
        generandoPDF = true
        defer { generandoPDF = false }

        let estructuras = vm.estructuras.sorted {
            let p0 = $0.parques?.nombre ?? "ZZZ"
            let p1 = $1.parques?.nombre ?? "ZZZ"
            if p0 != p1 { return p0 < p1 }
            return $0.numero.localizedStandardCompare($1.numero) == .orderedAscending
        }

        let porParque: [(parque: String, colonia: String?, items: [EstructuraConParque])] = {
            var orden: [String] = []
            var grupos: [String: (colonia: String?, items: [EstructuraConParque])] = [:]
            for e in estructuras {
                let key = e.parques?.nombre ?? "Sin parque"
                if grupos[key] == nil {
                    orden.append(key)
                    grupos[key] = (e.parques?.colonias?.nombre, [])
                }
                grupos[key]!.items.append(e)
            }
            return orden.map { k in (k, grupos[k]!.colonia, grupos[k]!.items) }
        }()

        let pageW: CGFloat = 612
        let pageH: CGFloat = 792
        let margin: CGFloat = 50
        let lineH: CGFloat = 20
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        let data = renderer.pdfData { ctx in
            var y: CGFloat = margin
            var pageNumber = 1
            let pageNumAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.systemGray2
            ]

            func drawPageNumber() {
                let label = "Página \(pageNumber)"
                let size = label.size(withAttributes: pageNumAttrs)
                label.draw(at: CGPoint(x: (pageW - size.width) / 2, y: pageH - margin / 2), withAttributes: pageNumAttrs)
            }

            func nuevaPagina() {
                if pageNumber > 0 { drawPageNumber() }
                ctx.beginPage()
                pageNumber += 1
                y = margin
            }

            func espacio(_ h: CGFloat) -> Bool {
                y + h > pageH - margin
            }

            ctx.beginPage()
            y = margin

            // Encabezado
            let titulo = "Municipio de San Nicolás de los Garza"
            let subtitulo = "Listado de estructuras por parque"
            let fecha: String = {
                let f = DateFormatter()
                f.locale = Locale(identifier: "es_MX")
                f.dateFormat = "d 'de' MMMM 'de' yyyy"
                return f.string(from: Date())
            }()

            titulo.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.black
            ])
            y += 22
            subtitulo.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.systemGray
            ])
            y += 16
            fecha.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.systemGray2
            ])
            y += 24

            // Línea separadora
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: y))
            linePath.addLine(to: CGPoint(x: pageW - margin, y: y))
            UIColor.systemGray4.setStroke()
            linePath.lineWidth = 0.5
            linePath.stroke()
            y += 16

            // Resumen
            "\(estructuras.count) estructuras · \(porParque.count) parques".draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray]
            )
            y += 24

            for grupo in porParque {
                if espacio(lineH * 3) { nuevaPagina() }

                // Nombre del parque + total
                let parqueLabel = "\(grupo.parque): \(grupo.items.count) estructura\(grupo.items.count == 1 ? "" : "s")"
                parqueLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.black
                ])
                y += 16

                if let colonia = grupo.colonia {
                    colonia.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.systemGray
                    ])
                    y += 14
                }

                // Números en columnas (4 por fila)
                let colWidth = (pageW - margin * 2) / 4
                var col = 0
                for e in grupo.items {
                    let x = margin + CGFloat(col) * colWidth
                    if col == 0 && espacio(lineH) { nuevaPagina(); col = 0 }
                    e.numero.draw(at: CGPoint(x: x, y: y), withAttributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: UIColor.darkGray
                    ])
                    col += 1
                    if col == 4 { col = 0; y += lineH }
                }
                if col > 0 { y += lineH }
                y += 12
            }
            drawPageNumber()
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("estructuras_municipio.pdf")
        try? data.write(to: url)
        pdfURL = url
    }
}

private struct IdentifiablePDFURL: Identifiable {
    let id = UUID()
    let url: URL
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
                .background(isActive ? Color("Azul") : Color("Navy").opacity(0.08), in: Capsule())
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
    var esCampo: Bool = false

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
                    NavigationLink(destination: EstructuraDetalleView(estructura: estructura, esCampo: esCampo)) {
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

    @State private var eventoSeleccionado: IntervencionCompleta? = nil

    var body: some View {
        Group {
            if sizeClass == .regular && isLandscape {
                iPadLayout
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
        .navigationDestination(item: $eventoSeleccionado) { evento in
            EventoDetalleView(evento: evento)
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

    // MARK: - Content cards (compartidos iPhone / iPad)
    private var contentCards: some View {
        VStack(spacing: 20) {
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
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .cardShadow()
                .padding(.horizontal, 16)
            }

            // Campañas
            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
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
                    .cardShadow()
                }

                // Historial
                if !historial.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Historial")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        ForEach(historial) { item in
                            Button { eventoSeleccionado = item } label: {
                                HistorialRow(item: item)
                            }
                            .buttonStyle(.plain)
                            if item.id != historial.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .cardShadow()
                    .padding(.horizontal, 16)
                }
            }

            // Notas
            if let notas = estructura.notas, !notas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notas")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notas).font(.subheadline)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .cardShadow()
                .padding(.horizontal, 16)
            }

        }
        .padding(.top, 16)
        .padding(.bottom, 40)
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


// MARK: - Historial Row

private struct HistorialRow: View {
    let item: IntervencionCompleta

    private var accionInfo: (icono: String, label: String, color: Color) {
        switch item.accion {
        case .revision:                return ("checkmark.circle.fill",        "Revisión",                  Color(hex: "#16a34a"))
        case .cambio_coroplast:        return ("arrow.2.squarepath",           "Cambio de coroplast",       Color("Navy"))
        case .reparacion_coroplast:    return ("wrench.and.screwdriver.fill",  "Reparación de coroplast",   Color("Navy"))
        case .reporte_dano:            return ("exclamationmark.triangle.fill", "Daño reportado",           Color(hex: "#dc2626"))
        case .reactivacion:            return ("arrow.clockwise",              "Reactivación",              Color(hex: "#16a34a"))
        case .instalacion:             return ("plus.circle.fill",             "Instalación",               Color("Navy"))
        case .cambio_campana:          return ("megaphone.fill",               "Cambio de campaña",         Color("Navy"))
        case .reparacion:              return ("hammer.fill",                  "Reparación",                Color("Navy"))
        case .reporte_mantenimiento:   return ("wrench.fill",                  "Mantenimiento reportado",   Color(hex: "#d97706"))
        case .mantenimiento_realizado: return ("checkmark.seal.fill",          "Mantenimiento realizado",   Color(hex: "#16a34a"))
        case .reporte_coroplast:
            switch item.tipoDano {
            case .sin_coroplast:  return ("square.slash",              "Sin coroplast",       Color(hex: "#d97706"))
            case .coroplast_roto: return ("exclamationmark.square.fill","Coroplast dañado",   Color(hex: "#d97706"))
            default:              return ("exclamationmark.square.fill","Aviso coroplast",    Color(hex: "#d97706"))
            }
        }
    }

    private var tieneFoto: Bool {
        item.fotoAntesUrl != nil || item.fotoDespuesUrl != nil
    }

    var body: some View {
        let info = accionInfo
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(info.color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: info.icono)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(info.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(info.label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                    if let nombre = item.rondines?.perfiles?.nombre {
                        Text("·").font(.subheadline).foregroundStyle(Color("TextMuted"))
                        Text(nombre).font(.subheadline).foregroundStyle(Color("TextMuted"))
                    }
                }

                if let notas = item.notas, !notas.isEmpty {
                    Text(notas)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }

            Spacer()

            if tieneFoto {
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted").opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Evento detalle view (full navigation push)

private struct EventoDetalleView: View {
    let evento: IntervencionCompleta
    @Environment(\.dismiss) private var dismiss
    @State private var fotoFullscreen: IdentifiableURL?

    private var accionInfo: (icono: String, label: String, color: Color) {
        switch evento.accion {
        case .revision:                return ("checkmark.circle.fill",        "Revisión",                  Color(hex: "#16a34a"))
        case .cambio_coroplast:        return ("arrow.2.squarepath",           "Cambio de coroplast",       Color("Navy"))
        case .reparacion_coroplast:    return ("wrench.and.screwdriver.fill",  "Reparación de coroplast",   Color("Navy"))
        case .reporte_dano:            return ("exclamationmark.triangle.fill", "Daño reportado",           Color(hex: "#dc2626"))
        case .reactivacion:            return ("arrow.clockwise",              "Reactivación",              Color(hex: "#16a34a"))
        case .instalacion:             return ("plus.circle.fill",             "Instalación",               Color("Navy"))
        case .cambio_campana:          return ("megaphone.fill",               "Cambio de campaña",         Color("Navy"))
        case .reparacion:              return ("hammer.fill",                  "Reparación",                Color("Navy"))
        case .reporte_mantenimiento:   return ("wrench.fill",                  "Mantenimiento reportado",   Color(hex: "#d97706"))
        case .mantenimiento_realizado: return ("checkmark.seal.fill",          "Mantenimiento realizado",   Color(hex: "#16a34a"))
        case .reporte_coroplast:
            switch evento.tipoDano {
            case .sin_coroplast:  return ("square.slash",              "Sin coroplast",       Color(hex: "#d97706"))
            case .coroplast_roto: return ("exclamationmark.square.fill","Coroplast dañado",   Color(hex: "#d97706"))
            default:              return ("exclamationmark.square.fill","Aviso coroplast",    Color(hex: "#d97706"))
            }
        }
    }

    private var fotos: [(url: URL, label: String)] {
        var result: [(URL, String)] = []
        let esCoroplast = evento.accion == .reporte_coroplast
        if let s = evento.fotoAntesUrl,   let u = URL(string: s) { result.append((u, esCoroplast ? "" : "Antes")) }
        if let s = evento.fotoDespuesUrl, let u = URL(string: s) { result.append((u, "Después")) }
        return result
    }

    private var fotoUrl: URL? { fotos.first?.url }

    var body: some View {
        let info = accionInfo
        ScrollView {
            VStack(spacing: 0) {
                heroImage(info: info)
                contentSection(info: info)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background {
            Color(.systemGray6).ignoresSafeArea()
            if let url = fotoUrl {
                CachedAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.4)
                            .blur(radius: 60)
                            .opacity(0.4)
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
                        Text("Historial").fontWeight(.semibold)
                    }
                }
                .foregroundStyle(Color("Navy"))
            }
            ToolbarItem(placement: .primaryAction) {
                Image(systemName: info.icono)
                    .foregroundStyle(info.color)
                    .font(.footnote)
            }
        }
        .fullScreenCover(item: $fotoFullscreen) { item in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
        }
    }

    @ViewBuilder
    private func heroImage(info: (icono: String, label: String, color: Color)) -> some View {
        if !fotos.isEmpty {
            TabView {
                ForEach(fotos, id: \.url) { foto in
                    ZStack {
                        Color(.systemGray5)
                        CachedAsyncImage(url: foto.url) { phase in
                            if case .success(let image) = phase {
                                Button {
                                    fotoFullscreen = IdentifiableURL(url: foto.url, titulo: foto.label)
                                } label: {
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 500)
                                        .clipped()
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.animation(.easeOut(duration: 0.4)))
                            } else {
                                ProgressView()
                            }
                        }
                        // Label Antes/Después
                        VStack {
                            Spacer()
                            HStack {
                                if !foto.label.isEmpty {
                                    Text(foto.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.black.opacity(0.45), in: Capsule())
                                        .padding(14)
                                }
                                Spacer()
                                // Expandir
                                Button {
                                    fotoFullscreen = IdentifiableURL(url: foto.url, titulo: foto.label)
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(.black.opacity(0.4), in: Circle())
                                }
                                .padding(14)
                            }
                        }
                    }
                    .frame(height: 500)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: fotos.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 500)
        } else {
            ZStack {
                info.color.opacity(0.12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                Image(systemName: info.icono)
                    .font(.system(size: 72))
                    .foregroundStyle(info.color.opacity(0.5))
            }
            .padding(.top, 100)
        }
    }

    private func contentSection(info: (icono: String, label: String, color: Color)) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.label)
                        .font(.title3.bold())
                    Text(evento.createdAt.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let nombre = evento.rondines?.perfiles?.nombre {
                    Label(nombre, systemImage: "person.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)

            if let notas = evento.notas, !notas.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Notas", systemImage: "note.text")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notas)
                        .font(.body)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 32)
        }
        .padding(.top, 16)
    }
}

private extension View {
    func cardShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }
}
