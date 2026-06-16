import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = DashboardViewModel()
    @State private var mostrarConfiguracion = false
    @State private var aparecer = false
    @State private var ultimaActualizacion: Date? = nil
    @State private var fotoPerfil: Image? = nil
    @State private var filtroNavegacion: EstadoEstructura? = nil
    @State private var navegarEstructuras = false

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

    private var sistemaOperativo: Bool { vm.kpi.dañadas == 0 }

    private func cargarFotoPerfil() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perfil.jpg")
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else { return }
        fotoPerfil = Image(uiImage: uiImage)
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

                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 100)
                } else {
                    VStack(spacing: 16) {

                        // MARK: Alerta dañadas
                        if vm.kpi.dañadas > 0 {
                            alertaDañadas
                                .padding(.horizontal, 20)
                                .intro(aparecer, delay: 0.04)
                        }

                        // MARK: Cobertura mensual — hero ring
                        CoberturaRingCard(kpi: vm.kpi)
                            .padding(.horizontal, 20)
                            .intro(aparecer, delay: 0.08)

                        // MARK: Esta semana
                        SemanaCard(kpi: vm.kpi)
                            .padding(.horizontal, 20)
                            .intro(aparecer, delay: 0.16)

                        // MARK: Datos del municipio
                        if !vm.usoColonias.isEmpty || vm.kpi.isLoaded {
                            seccion("Datos del municipio") {
                                VStack(spacing: 12) {
                                    ResumenMunicipalCard(
                                        kpi: vm.kpi,
                                        coloniasConEstructuras: vm.coloniasConEstructuras
                                    )
                                    if !vm.usoColonias.isEmpty {
                                        TopColoniasCard(colonias: vm.usoColonias)
                                    }
                                }
                            }
                            .intro(aparecer, delay: 0.22)
                        }

                        // MARK: Inventario
                        InventarioCard(
                            kpi: vm.kpi,
                            onActivas: {
                                HapticService.seleccion()
                                filtroNavegacion = .activa
                                navegarEstructuras = true
                            },
                            onDañadas: {
                                HapticService.seleccion()
                                filtroNavegacion = .dañada
                                navegarEstructuras = true
                            }
                        )
                        .padding(.horizontal, 20)
                        .intro(aparecer, delay: 0.18)

                        // MARK: Coroplast del mes
                        coroplastMes
                            .padding(.horizontal, 20)
                            .intro(aparecer, delay: 0.26)

                        // MARK: Charts
                        if !vm.usoCampanas.isEmpty || vm.kpi.isLoaded {
                            VStack(spacing: 12) {
                                sectionLabel("Estadísticas")
                                    .padding(.horizontal, 20)
                                CampanasChartCard(datos: vm.usoCampanas)
                                    .padding(.horizontal, 20)
                                if !vm.usoColonias.isEmpty {
                                    ColoniasChartCard(datos: vm.usoColonias, detalle: vm.coloniasDetalle)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .intro(aparecer, delay: 0.34)
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
            await vm.cargar()
            ultimaActualizacion = Date()
        }
        .task {
            await vm.cargar()
            ultimaActualizacion = Date()
            aparecer = true
        }
        .sheet(isPresented: $mostrarConfiguracion) {
            ConfiguracionView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navegarEstructuras) {
            EstructurasListView(filtroInicial: filtroNavegacion)
                .navigationDestination(for: EstructuraConParque.self) { e in
                    EstructuraDetalleView(estructura: e)
                }
        }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
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

                // Sistema de salud
                if vm.kpi.isLoaded {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(sistemaOperativo ? Color(hex: "#16a34a") : Color(hex: "#dc2626"))
                            .frame(width: 7, height: 7)
                            .shadow(color: (sistemaOperativo ? Color(hex: "#16a34a") : Color(hex: "#dc2626")).opacity(0.6), radius: 3)
                        Text(sistemaOperativo
                             ? "Sistema operativo"
                             : "\(vm.kpi.dañadas) \(vm.kpi.dañadas == 1 ? "estructura requiere" : "estructuras requieren") atención")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(sistemaOperativo ? Color(hex: "#16a34a") : Color(hex: "#dc2626"))
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button { mostrarConfiguracion = true } label: {
                    Group {
                        if let foto = fotoPerfil {
                            foto.resizable().scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        } else {
                            Text(auth.initiales.isEmpty ? "?" : auth.initiales)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("Navy"))
                                .frame(width: 48, height: 48)
                        }
                    }
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.large)
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

    // MARK: - Alerta dañadas

    private var alertaDañadas: some View {
        Button {
            HapticService.impacto(.medium)
            filtroNavegacion = .dañada
            navegarEstructuras = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "#dc2626"))
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(vm.kpi.dañadas) estructura\(vm.kpi.dañadas == 1 ? "" : "s") dañada\(vm.kpi.dañadas == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#dc2626"))
                    Text("Toca para ver cuáles son")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#dc2626").opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: "#dc2626").opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color(hex: "#dc2626").opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#dc2626").opacity(0.3), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(vm.kpi.dañadas) estructuras dañadas. Toca para ver la lista.")
    }

    // MARK: - Coroplast del mes

    private var coroplastMes: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color("Navy").opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "arrow.2.squarepath")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Coroplast cambiados")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Durante este mes")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextMuted"))
            }

            Spacer()

            Text("\(vm.kpi.coroplastMes)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionLabel(_ texto: String) -> some View {
        Text(texto)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("TextMuted"))
    }
}

// MARK: - Animación helper

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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Esta semana")
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
                    valor: kpi.visitasSemana,
                    label: "Revisadas",
                    icono: "checkmark.circle.fill",
                    color: Color(hex: "#16a34a")
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 72)
                columna(
                    valor: kpi.cambiosSemana,
                    label: "Coroplast",
                    icono: "arrow.2.squarepath",
                    color: Color("Navy")
                )
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 72)
                columna(
                    valor: kpi.danosSemana,
                    label: "Daños",
                    icono: "exclamationmark.triangle.fill",
                    color: Color(hex: "#dc2626")
                )
            }
            .padding(.vertical, 20)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

private struct ResumenMunicipalCard: View {
    let kpi: KPIData
    let coloniasConEstructuras: Int

    private var pctOperativas: Int {
        guard kpi.totalEstructuras > 0 else { return 0 }
        return Int(Double(kpi.activas) / Double(kpi.totalEstructuras) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                celda(
                    valor: "\(kpi.totalEstructuras)",
                    label: "Estructuras",
                    icono: "square.stack.fill",
                    color: Color("Navy"),
                    borde: [.trailing, .bottom]
                )
                celda(
                    valor: "\(kpi.campanasActivas)",
                    label: "Campañas activas",
                    icono: "megaphone.fill",
                    color: Color("Navy"),
                    borde: [.bottom]
                )
            }
            HStack(spacing: 0) {
                celda(
                    valor: "\(coloniasConEstructuras)",
                    label: "Colonias cubiertas",
                    icono: "map.fill",
                    color: Color("Navy"),
                    borde: [.trailing]
                )
                celda(
                    valor: "\(pctOperativas)%",
                    label: "Operativas",
                    icono: "checkmark.circle.fill",
                    color: Color(hex: "#16a34a"),
                    borde: []
                )
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func celda(valor: String, label: String, icono: String, color: Color, borde: Edge.Set) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(color.opacity(0.7))
            Text(valor)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .overlay(alignment: .trailing) {
            if borde.contains(.trailing) {
                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if borde.contains(.bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Top Colonias Card

private struct TopColoniasCard: View {
    let colonias: [UsoColonia]
    @State private var animado = false

    private var top5: [UsoColonia] {
        Array(colonias.sorted { $0.totalEstructuras > $1.totalEstructuras }.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Estructuras por colonia")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                Text("Top 5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("Navy").opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color("Navy").opacity(0.07), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            let maxVal = top5.first?.totalEstructuras ?? 1

            ForEach(Array(top5.enumerated()), id: \.element.id) { index, colonia in
                fila(colonia: colonia, max: maxVal, posicion: index + 1)
                if colonia.id != top5.last?.id {
                    Divider().padding(.leading, 20)
                }
            }

            Spacer().frame(height: 8)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0.05).delay(0.3)) { animado = true } }
    }

    private func fila(colonia: UsoColonia, max: Int, posicion: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(posicion)")
                .font(.caption.weight(.bold))
                .foregroundStyle(posicion == 1 ? Color(hex: "#f59e0b") : Color("TextMuted").opacity(0.5))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(colonia.nombre)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(colonia.totalEstructuras)")
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
                                    ? LinearGradient(colors: [Color("Navy"), Color("Navy").opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color("Navy").opacity(0.6), Color("Navy").opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: animado ? geo.size.width * (Double(colonia.totalEstructuras) / Double(max)) : 0)
                        }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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

    private var sinIncidentesMes: Bool { kpi.danosMes == 0 && kpi.isLoaded }

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
                            : LinearGradient(colors: [Color("Navy"), Color("Navy").opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
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

                if sinIncidentesMes {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#16a34a"))
                        Text("Mes sin incidentes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#16a34a"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#16a34a").opacity(0.1),
                                in: Capsule())
                }
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
