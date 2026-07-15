import SwiftUI

// MARK: - Estructura detail loader

private struct EstructuraDetalleLoader: View {
    let id: UUID
    @State private var estructura: EstructuraConParque? = nil
    @State private var cargando = true

    var body: some View {
        Group {
            if cargando {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let e = estructura {
                EstructuraDetalleView(estructura: e)
            } else {
                ContentUnavailableView("No encontrada", systemImage: "exclamationmark.triangle")
            }
        }
        .task {
            estructura = try? await EstructurasService.shared.fetchEstructura(id: id)
            cargando = false
        }
    }
}

// MARK: - Filtro rondin

private enum FiltroRondin: String, CaseIterable {
    case todas           = "Todas"
    case cambioCoroplast = "Cambio coroplast"
    case dano            = "Daño"
    case mantenimiento   = "Mantenimiento"
    case sinCoroplast    = "Sin coroplast"
    case coroplastRoto   = "Coroplast roto"

    func coincide(con intervenciones: [IntervencionCompleta]) -> Bool {
        switch self {
        case .todas:           return true
        case .cambioCoroplast: return intervenciones.contains { $0.accion == .cambio_coroplast || $0.accion == .reparacion_coroplast }
        case .dano:            return intervenciones.contains { $0.accion == .reporte_dano }
        case .mantenimiento:   return intervenciones.contains { $0.accion == .reporte_mantenimiento || $0.accion == .mantenimiento_realizado }
        case .sinCoroplast:    return intervenciones.contains { $0.accion == .reporte_coroplast && $0.tipoDano == .sin_coroplast }
        case .coroplastRoto:   return intervenciones.contains { $0.accion == .reporte_coroplast && $0.tipoDano == .coroplast_roto }
        }
    }
}

// MARK: - Día rondin detail

private struct DiaRondinDetalleView: View {
    let dia: DiaVisita

    @State private var intervenciones: [IntervencionCompleta] = []
    @State private var cargando = true
    @State private var filtro: FiltroRondin = .todas
    @State private var busqueda = ""
    @FocusState private var searchFocused: Bool
    @State private var showFloatingSearch = false

    private var intervencionesMap: [UUID: [IntervencionCompleta]] {
        Dictionary(grouping: intervenciones, by: \.estructuraId)
    }

    private var filtrosDisponibles: [FiltroRondin] {
        let map = intervencionesMap
        return FiltroRondin.allCases.filter { f in
            f == .todas || dia.estructuras.contains { f.coincide(con: map[$0.id] ?? []) }
        }
    }

    private var estructurasFiltradas: [EstructuraVisitada] {
        var base = dia.estructuras
        if filtro != .todas {
            base = base.filter { filtro.coincide(con: intervencionesMap[$0.id] ?? []) }
        }
        guard !busqueda.isEmpty else { return base }
        let q = busqueda.trimmingCharacters(in: .whitespaces)
        return base.filter {
            $0.numero.localizedCaseInsensitiveContains(q) ||
            ($0.colonia?.localizedCaseInsensitiveContains(q) ?? false) ||
            ($0.parque?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // Search bar (glass — igual que EstructurasListView)
                    RondinBuscadorGlass(busqueda: $busqueda, searchFocused: $searchFocused) {
                        busqueda = ""
                    }
                    .id("searchBar")

                    // Chips de filtro
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filtrosDisponibles, id: \.self) { f in
                                Button {
                                    withAnimation(.spring(duration: 0.3, bounce: 0.4)) { filtro = f }
                                } label: {
                                    Text(f.rawValue)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(filtro == f ? Color("Background") : Color("Navy"))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(filtro == f ? Color("Azul") : Color("Navy").opacity(0.08), in: Capsule())
                                        .scaleEffect(filtro == f ? 1.04 : 1.0)
                                        .animation(.spring(duration: 0.3, bounce: 0.4), value: filtro == f)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                    }
                    .scrollClipDisabled()

                    // Contador
                    HStack {
                        Text(busqueda.isEmpty && filtro == .todas
                             ? "\(dia.estructuras.count) estructuras"
                             : "\(estructurasFiltradas.count) resultado\(estructurasFiltradas.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color("TextMuted"))
                            .contentTransition(.numericText())
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Lista
                    if cargando {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if estructurasFiltradas.isEmpty {
                        ContentUnavailableView(
                            "Sin resultados",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(estructurasFiltradas) { e in
                                NavigationLink(destination: EstructuraDetalleLoader(id: e.id)) {
                                    EstructuraRondinRow(
                                        estructura: e,
                                        intervenciones: intervencionesMap[e.id] ?? []
                                    )
                                }
                                .buttonStyle(RondinRowButtonStyle())
                                Divider().padding(.leading, 20)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color("Background"))
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 80 } action: { _, scrolled in
                withAnimation(.spring(duration: 0.3)) { showFloatingSearch = scrolled }
            }
            .overlay(alignment: .top) {
                if showFloatingSearch {
                    RondinBuscadorGlass(busqueda: $busqueda, searchFocused: $searchFocused) {
                        busqueda = ""
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(dia.fecha.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es_MX"))).capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            intervenciones = (try? await IntervencionesService.shared.fetchIntervencionesDelDia(
                fecha: dia.fecha,
                estructuraIds: dia.estructuras.map { $0.id }
            )) ?? []
            cargando = false
        }
    }
}

private struct RondinBuscadorGlass: View {
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

private struct RondinRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.secondary.opacity(0.08) : Color.clear)
    }
}

// MARK: - Estructura row con badges

private struct EstructuraRondinRow: View {
    let estructura: EstructuraVisitada
    let intervenciones: [IntervencionCompleta]

    private var badges: [(icono: String, color: Color)] {
        var result: [(String, Color)] = []
        for i in intervenciones {
            switch i.accion {
            case .cambio_coroplast, .reparacion_coroplast:
                result.append(("arrow.2.squarepath", Color("Navy")))
            case .reporte_dano:
                result.append(("exclamationmark.triangle.fill", .red))
            case .reporte_mantenimiento:
                result.append(("wrench.fill", .orange))
            case .mantenimiento_realizado:
                result.append(("checkmark.seal.fill", .green))
            case .reporte_coroplast:
                result.append((i.tipoDano == .sin_coroplast ? "square.slash" : "exclamationmark.square.fill", .orange))
            default: break
            }
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.0).inserted }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(estructura.numero)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let colonia = estructura.colonia {
                    Text(colonia).font(.subheadline).foregroundStyle(.secondary)
                } else if let parque = estructura.parque {
                    Text(parque).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(badges, id: \.icono) { badge in
                    Image(systemName: badge.icono)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(badge.color)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Historial Campo

struct HistorialCampoView: View {
    let periodo: FiltroFecha
    @State private var vm = HistorialViewModel()

    private var dias: [DiaVisita] {
        switch periodo {
        case .semana:        return vm.diasSemana
        case .mes:           return vm.diasMes
        case .mesElegido:    return vm.diasMesElegido
        case .todo:          return vm.diasMes
        }
    }

    private var mostrarResumenMes: Bool {
        switch periodo {
        case .mes, .mesElegido: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            if vm.cargando {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dias.isEmpty {
                ContentUnavailableView(
                    "Sin visitas",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No hay estructuras visitadas en este periodo.")
                )
            } else {
                List {
                    Section("Rondines") {
                        ForEach(dias) { dia in
                            NavigationLink(destination: DiaRondinDetalleView(dia: dia)) {
                                DiaRondinRow(dia: dia)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
        .onChange(of: periodo) { (_: FiltroFecha, new: FiltroFecha) in
            if case .mesElegido(let d) = new {
                Task { await vm.cargarMesElegido(fecha: d) }
            }
        }
    }

    // MARK: - Resumen mes

    @ViewBuilder
    private func resumenMesSection(dias: [DiaVisita]) -> some View {
        let semanas = agruparPorSemana(dias: dias)
        Section("Resumen del mes") {
            ForEach(semanas, id: \.label) { semana in
                HStack {
                    Text(semana.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(semana.total) estructuras")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("Navy"))
                }
            }
        }
    }

    private struct SemanaResumen {
        let label: String
        let total: Int
    }

    private func agruparPorSemana(dias: [DiaVisita]) -> [SemanaResumen] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Monterrey")!
        calendar.firstWeekday = 2
        var porSemana: [Int: Int] = [:]
        var semanaFecha: [Int: Date] = [:]
        for dia in dias {
            let semana = calendar.component(.weekOfYear, from: dia.fecha)
            porSemana[semana, default: 0] += dia.estructuras.count
            if semanaFecha[semana] == nil { semanaFecha[semana] = dia.fecha }
        }
        return porSemana.sorted { $0.key > $1.key }.map { key, total in
            let fecha = semanaFecha[key] ?? Date()
            let inicio = calendar.dateInterval(of: .weekOfYear, for: fecha)?.start ?? fecha
            let fin = calendar.date(byAdding: .day, value: 6, to: inicio) ?? inicio
            let fmt = DateFormatter()
            fmt.dateFormat = "d MMM"
            fmt.locale = Locale(identifier: "es_MX")
            let label = "\(fmt.string(from: inicio)) – \(fmt.string(from: fin))"
            return SemanaResumen(label: label, total: total)
        }
    }
}

// MARK: - Día row

private struct DiaRondinRow: View {
    let dia: DiaVisita

    private var diaNombre: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "EEEE"
        return fmt.string(from: dia.fecha).capitalized
    }

    private var fechaCorta: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "d 'de' MMMM"
        return fmt.string(from: dia.fecha)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(diaNombre)
                    .font(.subheadline.weight(.semibold))
                Text(fechaCorta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 3) {
                Text("\(dia.estructuras.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("Azul"))
                    .monospacedDigit()
                Text("revisadas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Resumen período (semana/mes) desde dashboard

struct ResumenPeriodoView: View {
    let esMes: Bool

    @State private var estructuras: [EstructuraVisitada] = []
    @State private var intervenciones: [IntervencionCompleta] = []
    @State private var cargando = true
    @State private var filtro: FiltroRondin = .todas
    @State private var busqueda = ""
    @FocusState private var searchFocused: Bool
    @State private var showFloatingSearch = false

    private var intervencionesMap: [UUID: [IntervencionCompleta]] {
        Dictionary(grouping: intervenciones, by: \.estructuraId)
    }

    private var filtrosDisponibles: [FiltroRondin] {
        let map = intervencionesMap
        return FiltroRondin.allCases.filter { f in
            f == .todas || estructuras.contains { f.coincide(con: map[$0.id] ?? []) }
        }
    }

    private var estructurasFiltradas: [EstructuraVisitada] {
        var base = estructuras
        if filtro != .todas {
            base = base.filter { filtro.coincide(con: intervencionesMap[$0.id] ?? []) }
        }
        guard !busqueda.isEmpty else { return base }
        let q = busqueda.trimmingCharacters(in: .whitespaces)
        return base.filter {
            $0.numero.localizedCaseInsensitiveContains(q) ||
            ($0.colonia?.localizedCaseInsensitiveContains(q) ?? false) ||
            ($0.parque?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    RondinBuscadorGlass(busqueda: $busqueda, searchFocused: $searchFocused) {
                        busqueda = ""
                    }
                    .id("searchBar")

                    if filtrosDisponibles.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filtrosDisponibles, id: \.self) { f in
                                    Button {
                                        withAnimation(.spring(duration: 0.3, bounce: 0.4)) { filtro = f }
                                    } label: {
                                        Text(f.rawValue)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(filtro == f ? Color("Background") : Color("Navy"))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(filtro == f ? Color("Azul") : Color("Navy").opacity(0.08), in: Capsule())
                                            .scaleEffect(filtro == f ? 1.04 : 1.0)
                                            .animation(.spring(duration: 0.3, bounce: 0.4), value: filtro == f)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                        }
                        .scrollClipDisabled()
                    }

                    HStack {
                        Text(busqueda.isEmpty && filtro == .todas
                             ? "\(estructuras.count) estructuras"
                             : "\(estructurasFiltradas.count) resultado\(estructurasFiltradas.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color("TextMuted"))
                            .contentTransition(.numericText())
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    if cargando {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if estructurasFiltradas.isEmpty {
                        ContentUnavailableView("Sin resultados", systemImage: "line.3.horizontal.decrease.circle")
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(estructurasFiltradas) { e in
                                NavigationLink(destination: EstructuraDetalleLoader(id: e.id)) {
                                    EstructuraRondinRow(
                                        estructura: e,
                                        intervenciones: intervencionesMap[e.id] ?? []
                                    )
                                }
                                .buttonStyle(RondinRowButtonStyle())
                                Divider().padding(.leading, 20)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color("Background"))
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 80 } action: { _, scrolled in
                withAnimation(.spring(duration: 0.3)) { showFloatingSearch = scrolled }
            }
            .overlay(alignment: .top) {
                if showFloatingSearch {
                    RondinBuscadorGlass(busqueda: $busqueda, searchFocused: $searchFocused) { busqueda = "" }
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(esMes ? "Este mes" : "Esta semana")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let filtroFecha: FiltroFecha = esMes ? .mes : .semana
            async let diasTask = HistorialService.shared.fetchDias(desde: periodoDesde, hasta: Date())
            async let intervencionesTask = IntervencionesService.shared.fetchTodasIntervencionesDelPeriodo(filtro: filtroFecha)
            let dias = (try? await diasTask) ?? []
            intervenciones = (try? await intervencionesTask) ?? []
            var vistas: [UUID: EstructuraVisitada] = [:]
            for dia in dias {
                for e in dia.estructuras where vistas[e.id] == nil {
                    vistas[e.id] = e
                }
            }
            estructuras = vistas.values.sorted { $0.numero.localizedStandardCompare($1.numero) == .orderedAscending }
            cargando = false
        }
    }

    private var periodoDesde: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Monterrey")!
        cal.firstWeekday = 2
        let now = Date()
        if esMes {
            return cal.date(from: cal.dateComponents([.year, .month], from: now))!
        } else {
            return cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        }
    }
}
