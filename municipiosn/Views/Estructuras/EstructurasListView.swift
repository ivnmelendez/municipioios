import SwiftUI

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
        var base = estructuras
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
        default:         return "Estructuras"
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

// MARK: - Detalle

struct EstructuraDetalleView: View {
    let estructura: EstructuraConParque
    @State private var caras: [CaraDetalle] = []
    @State private var historial: [IntervencionCompleta] = []
    @State private var isLoading = true
    @State private var fotoFullscreen: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Estado + fecha instalación
                HStack {
                    EstadoBadge(estado: estructura.estado)
                    Spacer()
                    if let fecha = estructura.fechaInstalacion {
                        Text("Instalada \(fecha.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color("TextMuted"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                Divider()

                // Foto estructura
                if let fotoUrl = estructura.fotoUrl, let url = URL(string: fotoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            Button {
                                fotoFullscreen = IdentifiableURL(url: url, titulo: estructura.numero)
                            } label: {
                                image.resizable().aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity).frame(height: 320).clipped()
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption.weight(.semibold)).foregroundStyle(.white)
                                            .padding(6).background(.black.opacity(0.4), in: Circle()).padding(10)
                                    }
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        case .failure: EmptyView()
                        default: Color.secondary.opacity(0.1).frame(height: 320).overlay { ProgressView() }
                        }
                    }
                    Divider()
                }

                // Ubicación
                if let parque = estructura.parques {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ubicación")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color("TextMuted"))
                        if let colonia = parque.colonias {
                            Label(colonia.nombre, systemImage: "map").font(.subheadline)
                        }
                        Label(parque.nombre, systemImage: "tree")
                            .font(.subheadline).foregroundStyle(Color("TextMuted"))
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    Divider()
                }

                // Campañas
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 32)
                } else {
                    if !caras.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Campañas activas")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Color("TextMuted"))
                                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                            ForEach(caras.sorted(by: { $0.tipo < $1.tipo })) { cara in
                                CampanaRow(cara: cara, onTapFoto: { url in
                                    fotoFullscreen = IdentifiableURL(url: url, titulo: "Campaña Cara \(cara.tipo)")
                                })
                                .padding(.horizontal, 20).padding(.bottom, 16)
                            }
                        }
                        Divider()
                    }

                    // Historial
                    if !historial.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Historial reciente")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Color("TextMuted"))
                                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

                            ForEach(historial) { item in
                                HistorialRow(item: item)
                                    .scrollTransition(.animated.threshold(.visible(0.1))) { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1 : 0)
                                            .offset(y: phase.isIdentity ? 0 : 8)
                                    }
                                if item.id != historial.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        Divider()
                    }
                }

                // Notas
                if let notas = estructura.notas, !notas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notas").font(.footnote.weight(.semibold)).foregroundStyle(Color("TextMuted"))
                        Text(notas).font(.body)
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color("Background"))
        .navigationTitle(estructura.numero)
        .navigationBarTitleDisplayMode(.large)
        .task {
            async let carasTask = EstructurasService.shared.fetchCarasDetalle(estructuraId: estructura.id)
            async let historialTask = IntervencionesService.shared.fetchHistorial(estructuraId: estructura.id)
            caras = (try? await carasTask) ?? []
            historial = (try? await historialTask) ?? []
            isLoading = false
        }
        .fullScreenCover(item: $fotoFullscreen) { (item: IdentifiableURL) in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
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
