import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = DashboardViewModel()
    @State private var pagosVm = PagosViewModel()
    @State private var mostrarConfiguracion = false
    @State private var aparecer = false
    @State private var ultimaActualizacion: Date? = nil
    @State private var fotoPerfil: Image? = nil
    @State private var filtroNavegacion: EstadoEstructura? = nil
    @State private var navegarEstructuras = false
    @State private var filtroCoroplast: String? = nil
    @State private var navegarCoroplast = false
    @State private var navegarResumenPeriodo = false
    @State private var navegarCampanas = false
    @AppStorage("semanaCard_periodo") private var semanaCardEsMes = true

    private static let monterrey = TimeZone(identifier: "America/Monterrey")!

    private var saludo: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.monterrey
        let hora = cal.component(.hour, from: Date())
        switch hora {
        case 6..<12: return "Buenos días"
        case 12..<20: return "Buenas tardes"
        default:      return "Buenas noches"
        }
    }

    private var fechaFormateada: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.timeZone = Self.monterrey
        fmt.dateFormat = "EEEE, d 'de' MMMM"
        let raw = fmt.string(from: Date())
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private var horaActualizacion: String {
        guard let fecha = ultimaActualizacion else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.timeZone = Self.monterrey
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: fecha)
    }

    @AppStorage("perfil_avatar_url_cache") private var avatarUrlCached = ""

    private func cargarFotoPerfil(forzar: Bool = false) {
        let localUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perfil.jpg")
        let remoteUrlStr = auth.avatarUrl ?? ""

        if !forzar && remoteUrlStr == avatarUrlCached,
           let data = try? Data(contentsOf: localUrl),
           let uiImage = UIImage(data: data) {
            fotoPerfil = Image(uiImage: uiImage)
            return
        }

        if !remoteUrlStr.isEmpty,
           let url = URL(string: remoteUrlStr + "?v=\(Int(Date().timeIntervalSince1970))") {
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

        if let data = try? Data(contentsOf: localUrl),
           let uiImage = UIImage(data: data) {
            fotoPerfil = Image(uiImage: uiImage)
        }
    }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 28)
                    .intro(aparecer, delay: 0.0)

                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 100)
                } else {
                    VStack(spacing: 16) {

                        // MARK: Cards dinámicas
                        ForEach(Array(vm.cardConfig.filter { $0.activa }.enumerated()), id: \.element.id) { index, card in
                            cardView(for: card.id)
                                .padding(.horizontal, 20)
                                .intro(aparecer, delay: 0.08 + Double(index) * 0.06)
                        }
                    }
                    .padding(.bottom, 48)
                }

                if let error = vm.errorMessage {
                    ContentUnavailableView("Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error))
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color("Background"))
        .refreshable {
            EstructurasService.shared.invalidarCacheEstructuras()
            await vm.cargar()
            ultimaActualizacion = Date()
        }
        .task {
            if let userId = auth.perfilId {
                await vm.cargarConfig(userId: userId)
            }
            await vm.cargar()
            await pagosVm.cargar()
            ultimaActualizacion = Date()
            aparecer = true
        }
        .sheet(isPresented: $mostrarConfiguracion) {
            ConfiguracionView(vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarActualizado)) { _ in
            avatarUrlCached = ""
            cargarFotoPerfil(forzar: true)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navegarEstructuras) {
            EstructurasListView(filtroInicial: filtroNavegacion)
        }
        .navigationDestination(isPresented: $navegarCoroplast) {
            EstructurasListView(filtroCoroplast: filtroCoroplast)
        }
        .navigationDestination(isPresented: $navegarResumenPeriodo) {
            ResumenPeriodoView(esMes: !semanaCardEsMes)
        }
        .navigationDestination(isPresented: $navegarCampanas) {
            CampanasListaCompleta(datos: vm.usoCampanas)
        }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(saludo)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))

                Text(auth.displayName.isEmpty
                     ? "Bienvenido"
                     : auth.displayName.components(separatedBy: " ").first ?? auth.displayName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color("Navy"))

                Text(fechaFormateada)
                    .font(.subheadline)
                    .foregroundStyle(Color("TextMuted"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
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

                if !horaActualizacion.isEmpty {
                    Text("↻ \(horaActualizacion)")
                        .font(.caption2)
                        .foregroundStyle(Color("TextMuted").opacity(0.6))
                }
            }
        }
    }


    // MARK: - Coroplast del mes


    private func sectionLabel(_ texto: String) -> some View {
        Text(texto)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("TextMuted"))
    }

    @ViewBuilder
    private func cardView(for id: DashboardCardID) -> some View {
        switch id {
        case .alertaEstructuras:
            AlertaEstructurasCard(
                dañadas: vm.kpi.dañadas,
                mantenimiento: vm.kpi.necesitaMantenimiento,
                onDañadas: {
                    HapticService.impacto(.medium)
                    filtroNavegacion = .dañada
                    navegarEstructuras = true
                },
                onMantenimiento: {
                    HapticService.impacto(.medium)
                    filtroNavegacion = .necesita_mantenimiento
                    navegarEstructuras = true
                }
            )
        case .avisoCoroplast:
            AvisoCoroplastCard(
                sinCoroplast: vm.kpi.sinCoroplast,
                coroplastRoto: vm.kpi.coroplastRoto,
                onSinCoroplast: {
                    HapticService.impacto(.medium)
                    filtroCoroplast = "sin_coroplast"
                    navegarCoroplast = true
                },
                onCoroplastRoto: {
                    HapticService.impacto(.medium)
                    filtroCoroplast = "coroplast_roto"
                    navegarCoroplast = true
                }
            )
        case .cobertura:
            CoberturaRingCard(kpi: vm.kpi)
        case .semana:
            SemanaCard(kpi: vm.kpi, onTap: {
                HapticService.impacto(.medium)
                navegarResumenPeriodo = true
            })
        case .resumenMunicipal:
            ResumenMunicipalCard(kpi: vm.kpi, coloniasConEstructuras: vm.coloniasConEstructuras)
        case .campanasCard:
            CampañasCard(
                total: vm.kpi.campanasActivas,
                top: Array(vm.usoCampanas.prefix(3)),
                onTap: {
                    HapticService.impacto(.medium)
                    navegarCampanas = true
                }
            )
        case .campanasChart:
            CampanasChartCard(datos: vm.usoCampanas, onVerTodas: {
                HapticService.impacto(.medium)
                navegarCampanas = true
            })
        case .coloniasChart:
            if !vm.usoColonias.isEmpty {
                ColoniasChartCard(datos: vm.usoColonias)
            }
        case .pagos:
            PagosGastosCard(vm: pagosVm)
        case .alcancePoblacional:
            if vm.alcanceTotal > 0 {
                AlcanceTotalCard(
                    total: vm.alcanceTotal,
                    fem: vm.alcanceFem,
                    mas: vm.alcanceMas,
                    mayores18: vm.alcance18mas
                )
            }
        case .alcanceColonias:
            if !vm.alcancePorColonia.isEmpty {
                AlcanceColoniasCard(colonias: vm.alcancePorColonia)
            }
        }
    }
}

// MARK: - Editor Dashboard Sheet

struct EditorDashboardSheet: View {
    @Bindable var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($vm.cardConfig) { $card in
                        HStack(spacing: 14) {
                            Image(systemName: card.id.icono)
                                .font(.body.weight(.medium))
                                .foregroundStyle(card.activa ? Color("Navy") : Color("TextMuted"))
                                .frame(width: 28)

                            Text(card.id.titulo)
                                .font(.body)
                                .foregroundStyle(card.activa ? .primary : Color("TextMuted"))

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { card.activa },
                                set: { _ in vm.toggleCard(card.id) }
                            ))
                            .labelsHidden()
                            .tint(Color("Azul"))
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { from, to in vm.moverCard(from: from, to: to) }
                } header: {
                    Text("Arrastra para reordenar")
                } footer: {
                    Text("Los cambios se guardan automáticamente.")
                }
            }
            .navigationTitle("Personalizar inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color("Azul"))
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

// MARK: - Animación helper

// MARK: - Alcance Poblacional Card

// MARK: - Card 1: Alcance total

private struct AlcanceTotalCard: View {
    let total: Int
    let fem: Int
    let mas: Int
    let mayores18: Int

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Alcance estimado")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.caption.weight(.semibold))
                    Text("INEGI 2020")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(Color("TextMuted").opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Número grande — ocupa su propia línea, escala si es necesario
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(total.formatted())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("Navy"))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("hab.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            // Columnas
            HStack(spacing: 0) {
                statCol("Mujeres", valor: fem, color: Color(hex: "#db2777"))
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 52)
                statCol("Hombres", valor: mas, color: Color("Azul"))
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 52)
                statCol("+18 años", valor: mayores18, color: Color(hex: "#16a34a"))
            }
            .padding(.vertical, 18)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statCol(_ label: String, valor: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(valor.formatted())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Card 2: Alcance por colonia

private struct AlcanceColoniasCard: View {
    let colonias: [ColoniaAlcance]
    @State private var mostrarTodo = false
    @State private var animado = false

    private var top: [ColoniaAlcance] { Array(colonias.prefix(5)) }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(spacing: 0) {
                HStack {
                    Text("Alcance por colonia")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    Text("INEGI 2020")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("Navy").opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("Navy").opacity(0.07), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                let maxVal = top.first?.poblacion ?? 1
                ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                    fila(item: item, max: maxVal, posicion: index + 1)
                    if item.id != top.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
                Spacer().frame(height: 8)
            }
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.05).delay(0.3)) { animado = true }
        }
        .sheet(isPresented: $mostrarTodo) {
            AlcanceColoniasLista(colonias: colonias)
        }
    }

    private func fila(item: ColoniaAlcance, max: Int, posicion: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(posicion)")
                .font(.caption.weight(.bold))
                .foregroundStyle(posicion == 1 ? Color(hex: "#f59e0b") : Color("TextMuted").opacity(0.5))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.nombre)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.poblacion.formatted())
                        .font(.subheadline.bold())
                        .foregroundStyle(Color("Navy"))
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("Navy").opacity(0.08))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    posicion == 1
                                    ? LinearGradient(colors: [Color("Azul"), Color("Azul").opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color("Azul").opacity(0.6), Color("Azul").opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: animado ? geo.size.width * CGFloat(item.poblacion) / CGFloat(max) : 0)
                        }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct AlcanceColoniasLista: View {
    let colonias: [ColoniaAlcance]
    @Environment(\.dismiss) private var dismiss
    @State private var busqueda = ""

    private var filtrados: [ColoniaAlcance] {
        busqueda.isEmpty ? colonias : colonias.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtrados) { item in
                    HStack {
                        Text(item.nombre).font(.body)
                        Spacer()
                        Text(item.poblacion.formatted())
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color("Navy"))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $busqueda, prompt: "Buscar colonia")
            .navigationTitle("Alcance por colonia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}

private extension View {
    func intro(_ aparecer: Bool, delay: Double) -> some View {
        self
            .opacity(aparecer ? 1 : 0)
            .offset(y: aparecer ? 0 : 16)
            .animation(.spring(duration: 0.5, bounce: 0.1).delay(delay), value: aparecer)
    }
}

// MARK: - Esta semana card

private struct SemanaCard: View {
    let kpi: KPIData
    var onTap: () -> Void = {}
    @AppStorage("semanaCard_periodo") private var esMes = true

    private var visitas: Int  { esMes ? kpi.visitasSemana : kpi.visitasMes }
    private var cambios: Int  { esMes ? kpi.cambiosSemana : kpi.coroplastMes }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(esMes ? "Esta semana" : "Este mes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                    .contentTransition(.identity)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("TextMuted").opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 0) {
                columna(
                    valor: visitas,
                    label: "Revisadas",
                    icono: "checkmark.circle.fill",
                    color: Color(hex: "#16a34a")
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 72)
                columna(
                    valor: cambios,
                    label: "Coroplast",
                    icono: "arrow.2.squarepath",
                    color: Color("Navy")
                )
            }
            .padding(.vertical, 20)
        }
        .animation(.easeInOut(duration: 0.25), value: esMes)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            esMes.toggle()
            HapticService.seleccion()
        }
    }

    private func columna(valor: Int, label: String, icono: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
            Text("\(valor)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inventario card

private struct InventarioCard: View {
    let kpi: KPIData
    let onActivas: () -> Void
    let onDañadas: () -> Void

    private var total: Int { kpi.totalEstructuras }
    private var pctActivas: Double {
        guard total > 0 else { return 0 }
        return Double(kpi.activas) / Double(total)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header con total y porcentaje
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inventario")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(kpi.totalEstructuras)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color("Navy"))
                            .contentTransition(.numericText())
                        Text("estructuras")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color("TextMuted"))
                            .padding(.bottom, 4)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(pctActivas * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#16a34a"))
                        .contentTransition(.numericText())
                    Text("operativas")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("TextMuted"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Barra de proporción
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#dc2626").opacity(0.2))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#16a34a"))
                            .frame(width: geo.size.width * pctActivas, height: 8)
                            .animation(.spring(duration: 1.0, bounce: 0.1), value: pctActivas)
                    }
            }
            .frame(height: 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider().padding(.horizontal, 20)

            // Stats tappables
            HStack(spacing: 0) {
                inventarioBoton(
                    valor: kpi.activas,
                    label: "Activas",
                    color: Color(hex: "#16a34a"),
                    accion: onActivas
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 44)
                inventarioBoton(
                    valor: kpi.dañadas,
                    label: "Dañadas",
                    color: Color(hex: "#dc2626"),
                    accion: onDañadas
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 44)
                inventarioBoton(
                    valor: kpi.campanasActivas,
                    label: "Campañas",
                    color: Color("Navy"),
                    accion: nil
                )
            }
            .padding(.vertical, 16)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func inventarioBoton(valor: Int, label: String, color: Color, accion: (() -> Void)?) -> some View {
        let contenido = VStack(spacing: 4) {
            Text("\(valor)")
                .font(.title2.bold())
                .foregroundStyle(color)
                .contentTransition(.numericText())
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))
                if accion != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color("TextMuted").opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)

        if let accion {
            return AnyView(
                Button(action: accion) { contenido }.buttonStyle(.plain)
            )
        } else {
            return AnyView(contenido)
        }
    }
}

// MARK: - Resumen Municipal Card

// MARK: - Campañas Card

private struct CampañasCard: View {
    let total: Int
    let top: [UsoCampana]
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campañas activas")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(total)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("Navy"))
                                .contentTransition(.numericText())
                            Text("campañas")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color("TextMuted"))
                                .padding(.bottom, 4)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted").opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if !top.isEmpty {
                    Divider().padding(.horizontal, 20)
                    VStack(spacing: 0) {
                        ForEach(top) { campana in
                            HStack(spacing: 14) {
                                if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                                    CachedAsyncImage(url: url) { phase in
                                        if case .success(let image) = phase {
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 56, height: 56)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color("Navy").opacity(0.08))
                                                .frame(width: 56, height: 56)
                                        }
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color("Navy").opacity(0.08))
                                        .frame(width: 56, height: 56)
                                        .overlay {
                                            Image(systemName: "megaphone.fill")
                                                .foregroundStyle(Color("Navy").opacity(0.25))
                                        }
                                }
                                Text(campana.nombre)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            if campana.id != top.last?.id {
                                Divider().padding(.leading, 90)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 24))
    }
}

// MARK: - ResumenMunicipal Card

private struct ResumenMunicipalCard: View {
    let kpi: KPIData
    let coloniasConEstructuras: Int

    private var pctOperativas: Int {
        guard kpi.totalEstructuras > 0 else { return 0 }
        return Int(Double(kpi.activas) / Double(kpi.totalEstructuras) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Municipio")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                Image(systemName: "building.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color("Navy").opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 0) {
                statCelda("\(kpi.totalEstructuras)", "Estructuras", "square.stack.fill", Color("Navy"))
                divisor()
                statCelda("\(coloniasConEstructuras)", "Colonias", "map.fill", Color("Navy"))
                divisor()
                statCelda("\(pctOperativas)%", "Operativas", "checkmark.circle.fill", Color(hex: "#16a34a"))
            }
            .padding(.vertical, 20)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statCelda(_ valor: String, _ label: String, _ icono: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(color.opacity(0.8))
            Text(valor)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func divisor() -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(width: 1, height: 56)
    }
}

// MARK: - Cobertura Ring Card

private struct CoberturaRingCard: View {
    let kpi: KPIData
    @State private var progreso: Double = 0
    @State private var pulsando = false

    private var pct: Double {
        guard kpi.totalEstructuras > 0 else { return 0 }
        return min(Double(kpi.visitasMes) / Double(kpi.totalEstructuras), 1.0)
    }

    private var pctInt: Int { Int(pct * 100) }

    private var mensaje: String {
        switch pct {
        case 1.0:        return "¡Cobertura completa este mes!"
        case 0.8..<1.0:  return "Excelente gestión este mes"
        case 0.6..<0.8:  return "Buen ritmo del equipo"
        case 0.4..<0.6:  return "El equipo está avanzando"
        default:         return "Quedan estructuras por revisar"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Ring + center
            ZStack {
                // Track
                Circle()
                    .stroke(Color("Navy").opacity(0.1), lineWidth: 18)
                    .frame(width: 160, height: 160)

                // Fill
                Circle()
                    .trim(from: 0, to: progreso)
                    .stroke(
                        pct >= 1.0
                            ? LinearGradient(colors: [Color(hex: "#16a34a"), Color(hex: "#16a34a").opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color("Azul"), Color("Azul").opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.4, bounce: 0.1), value: progreso)

                // Center content
                VStack(spacing: 4) {
                    Text("\(pctInt)%")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(pct >= 1.0 ? Color(hex: "#16a34a") : Color("Navy"))
                        .contentTransition(.numericText())
                        .scaleEffect(pulsando ? 1.06 : 1.0)
                    Text("cobertura")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                }
            }

            // Label + stats
            VStack(spacing: 10) {
                Text(mensaje)
                    .font(.headline)
                    .foregroundStyle(Color("Navy"))
                    .multilineTextAlignment(.center)

                Text("\(kpi.visitasMes) de \(kpi.totalEstructuras) estructuras revisadas este mes")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextMuted"))
                    .multilineTextAlignment(.center)

            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            progreso = pct
            if pct >= 1.0 {
                withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true).delay(1.5)) {
                    pulsando = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    pulsando = false
                }
            }
        }
        .onChange(of: kpi.visitasMes) { _, _ in
            withAnimation(.spring(duration: 1.2)) { progreso = pct }
        }
    }
}

// MARK: - Alerta estructuras card

private struct AlertaEstructurasCard: View {
    let dañadas: Int
    let mantenimiento: Int
    let onDañadas: () -> Void
    let onMantenimiento: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Estructuras con alertas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 0) {
                columna(
                    valor: dañadas,
                    label: "Dañadas",
                    icono: "exclamationmark.triangle.fill",
                    color: Color(hex: "#dc2626"),
                    accion: onDañadas
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 72)
                columna(
                    valor: mantenimiento,
                    label: "Mantenimiento",
                    icono: "wrench.fill",
                    color: Color(hex: "#d97706"),
                    accion: onMantenimiento
                )
            }
            .padding(.vertical, 20)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func columna(valor: Int, label: String, icono: String, color: Color, accion: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(valor > 0 ? color : Color("TextMuted").opacity(0.4))
            Text("\(valor)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(valor > 0 ? Color("Navy") : Color("TextMuted").opacity(0.4))
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if valor > 0 { accion() } }
    }
}

// MARK: - Aviso Coroplast Card

private struct AvisoCoroplastCard: View {
    let sinCoroplast: Int
    let coroplastRoto: Int
    let onSinCoroplast: () -> Void
    let onCoroplastRoto: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Avisos coroplast")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 0) {
                columna(
                    valor: sinCoroplast,
                    label: "Sin coroplast",
                    icono: "square.slash.fill",
                    color: Color(hex: "#ea580c"),
                    accion: onSinCoroplast
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 72)
                columna(
                    valor: coroplastRoto,
                    label: "Dañado",
                    icono: "exclamationmark.square.fill",
                    color: Color(hex: "#d97706"),
                    accion: onCoroplastRoto
                )
            }
            .padding(.vertical, 20)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func columna(valor: Int, label: String, icono: String, color: Color, accion: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(valor > 0 ? color : Color("TextMuted").opacity(0.4))
            Text("\(valor)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(valor > 0 ? Color("Navy") : Color("TextMuted").opacity(0.4))
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if valor > 0 { accion() } }
    }
}
