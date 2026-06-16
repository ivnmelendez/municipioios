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
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView("Cargando…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: Alerta dañadas
                        if vm.kpi.dañadas > 0 {
                            alertaDañadas
                                .padding(.horizontal, 20)
                                .intro(aparecer, delay: 0.04)
                        }

                        // MARK: Esta semana
                        seccion("Esta semana") {
                            ActividadSemanaCard(kpi: vm.kpi)
                        }
                        .intro(aparecer, delay: 0.1)

                        // MARK: Estado
                        seccion("Estado del inventario") {
                            estadoStrip
                        }
                        .intro(aparecer, delay: 0.2)

                        // MARK: Coroplast del mes
                        seccion("Coroplast cambiados este mes") {
                            coroplastMes
                        }
                        .intro(aparecer, delay: 0.28)

                        // MARK: Estadísticas
                        if !vm.usoCampanas.isEmpty || vm.kpi.isLoaded {
                            seccion("Estadísticas") {
                                VStack(spacing: 12) {
                                    CampanasChartCard(datos: vm.usoCampanas)
                                    if !vm.usoColonias.isEmpty {
                                        ColoniasChartCard(datos: vm.usoColonias, detalle: vm.coloniasDetalle)
                                    }
                                }
                            }
                            .intro(aparecer, delay: 0.36)
                        }
                    }
                }

                if let error = vm.errorMessage {
                    ContentUnavailableView(
                        "Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
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
            VStack(alignment: .leading, spacing: 4) {
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

            VStack(alignment: .trailing, spacing: 6) {
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
                        .font(.caption)
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
                .stroke(Color(hex: "#dc2626").opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(vm.kpi.dañadas) estructuras dañadas. Toca para ver la lista.")
    }

    // MARK: - Estado strip

    private var estadoStrip: some View {
        HStack(spacing: 12) {
            estadoChip(
                valor: vm.kpi.activas,
                label: "Activas",
                icono: "checkmark.circle.fill",
                color: Color(hex: "#16a34a"),
                accion: { filtroNavegacion = .activa; navegarEstructuras = true }
            )
            estadoChip(
                valor: vm.kpi.dañadas,
                label: "Dañadas",
                icono: "exclamationmark.triangle.fill",
                color: Color(hex: "#dc2626"),
                accion: { filtroNavegacion = .dañada; navegarEstructuras = true }
            )
            estadoChip(
                valor: vm.kpi.campanasActivas,
                label: "Campañas",
                icono: "megaphone.fill",
                color: Color("Navy"),
                accion: nil
            )
        }
    }

    private func estadoChip(valor: Int, label: String, icono: String, color: Color, accion: (() -> Void)?) -> some View {
        let contenido = VStack(spacing: 8) {
            Image(systemName: icono)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text("\(valor)")
                .font(.title.bold())
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))

        if let accion {
            return AnyView(
                Button {
                    HapticService.seleccion()
                    accion()
                } label: { contenido }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label): \(valor). Toca para ver lista.")
            )
        } else {
            return AnyView(contenido)
        }
    }

    // MARK: - Coroplast del mes

    private var coroplastMes: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.2.squarepath")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color("Navy"))
                .padding(14)
                .background(Color("Navy").opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text("Coroplast cambiados")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Durante este mes")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextMuted"))
            }

            Spacer()

            Text("\(vm.kpi.coroplastMes)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func seccion<Content: View>(_ titulo: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextMuted"))
                .padding(.horizontal, 20)
            content()
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Animación

private extension View {
    func intro(_ aparecer: Bool, delay: Double) -> some View {
        self
            .opacity(aparecer ? 1 : 0)
            .offset(y: aparecer ? 0 : 14)
            .animation(.spring(duration: 0.45, bounce: 0.1).delay(delay), value: aparecer)
    }
}

// MARK: - Esta semana

private struct ActividadSemanaCard: View {
    let kpi: KPIData

    var body: some View {
        VStack(spacing: 0) {
            fila(
                icono: "checkmark.circle.fill",
                color: Color(hex: "#16a34a"),
                titulo: "Estructuras revisadas",
                valor: kpi.visitasSemana
            )
            Divider().padding(.leading, 60)
            fila(
                icono: "arrow.2.squarepath",
                color: Color("Navy"),
                titulo: "Coroplast cambiados",
                valor: kpi.cambiosSemana
            )
            Divider().padding(.leading, 60)
            fila(
                icono: "exclamationmark.triangle.fill",
                color: Color(hex: "#dc2626"),
                titulo: "Daños reportados",
                valor: kpi.danosSemana
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func fila(icono: String, color: Color, titulo: String, valor: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icono)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(titulo)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(valor)")
                .font(.title2.bold())
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.vertical, 18)
    }
}
