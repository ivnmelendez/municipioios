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

    private var porcentajeOperativas: Double {
        guard vm.kpi.totalEstructuras > 0 else { return 0 }
        return Double(vm.kpi.activas) / Double(vm.kpi.totalEstructuras)
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
            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    VStack(alignment: .leading, spacing: 16) {

                        // MARK: Alerta dañadas
                        if vm.kpi.dañadas > 0 {
                            alertaDañadas
                                .padding(.horizontal, 20)
                                .intro(aparecer, delay: 0.05)
                        }

                        // MARK: Esta semana (hero)
                        VStack(alignment: .leading, spacing: 10) {
                            label("Esta semana")
                                .padding(.horizontal, 20)
                            ActividadSemanaCard(kpi: vm.kpi)
                                .padding(.horizontal, 20)
                        }
                        .intro(aparecer, delay: 0.1)

                        // MARK: Estado del inventario (compact strip)
                        VStack(alignment: .leading, spacing: 10) {
                            label("Inventario")
                                .padding(.horizontal, 20)
                            estadoStrip
                                .padding(.horizontal, 20)
                        }
                        .intro(aparecer, delay: 0.2)

                        // MARK: Coroplast del mes
                        coroplastMes
                            .padding(.horizontal, 20)
                            .intro(aparecer, delay: 0.28)

                        // MARK: Estadísticas
                        if !vm.usoCampanas.isEmpty || vm.kpi.isLoaded {
                            VStack(alignment: .leading, spacing: 10) {
                                label("Estadísticas")
                                    .padding(.horizontal, 20)
                                VStack(spacing: 10) {
                                    CampanasChartCard(datos: vm.usoCampanas)
                                    if !vm.usoColonias.isEmpty {
                                        ColoniasChartCard(datos: vm.usoColonias, detalle: vm.coloniasDetalle)
                                    }
                                }
                                .padding(.horizontal, 20)
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

                Spacer(minLength: 32)
            }
            .padding(.top, 4)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saludo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))
                Text(auth.displayName.isEmpty ? "Bienvenido" : auth.displayName.components(separatedBy: " ").first ?? auth.displayName)
                    .font(.title.bold())
                    .foregroundStyle(Color("Navy"))
                Text(fechaFormateada)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted").opacity(0.8))
                    .padding(.top, 1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Button { mostrarConfiguracion = true } label: {
                    Group {
                        if let foto = fotoPerfil {
                            foto.resizable().scaledToFill()
                                .frame(width: 40, height: 40).clipShape(Circle())
                        } else {
                            Text(auth.initiales.isEmpty ? "?" : auth.initiales)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("Navy"))
                                .frame(width: 40, height: 40)
                        }
                    }
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.regular)
                .onAppear { cargarFotoPerfil() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in cargarFotoPerfil() }

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
            filtroNavegacion = .dañada
            navegarEstructuras = true
            HapticService.impacto(.medium)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: "#dc2626"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.kpi.dañadas) estructura\(vm.kpi.dañadas == 1 ? "" : "s") dañada\(vm.kpi.dañadas == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "#dc2626"))
                    Text("Requieren atención")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#dc2626").opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "#dc2626").opacity(0.5))
            }
            .padding(16)
            .background(Color(hex: "#dc2626").opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#dc2626").opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Estado strip

    private var estadoStrip: some View {
        HStack(spacing: 10) {
            estadoChip(
                valor: vm.kpi.activas,
                label: "Activas",
                color: Color(hex: "#16a34a"),
                accion: { filtroNavegacion = .activa; navegarEstructuras = true }
            )
            estadoChip(
                valor: vm.kpi.dañadas,
                label: "Dañadas",
                color: Color(hex: "#dc2626"),
                accion: { filtroNavegacion = .dañada; navegarEstructuras = true }
            )
            estadoChip(
                valor: vm.kpi.campanasActivas,
                label: "Campañas",
                color: Color("Navy"),
                accion: nil
            )
        }
    }

    private func estadoChip(valor: Int, label: String, color: Color, accion: (() -> Void)?) -> some View {
        let content = VStack(spacing: 4) {
            Text("\(valor)")
                .font(.title2.bold())
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        if let accion {
            return AnyView(
                Button { accion(); HapticService.seleccion() } label: { content }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label): \(valor). Toca para ver lista.")
            )
        } else {
            return AnyView(content)
        }
    }

    // MARK: - Coroplast del mes

    private var coroplastMes: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.2.squarepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color("Navy"))
                .padding(10)
                .background(Color("Navy").opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("Coroplast cambiados")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text("Este mes")
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
            Spacer()
            Text("\(vm.kpi.coroplastMes)")
                .font(.title.bold())
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private func label(_ texto: String) -> some View {
        Text(texto)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color("TextMuted"))
    }
}

// MARK: - Animación helper

private extension View {
    func intro(_ aparecer: Bool, delay: Double) -> some View {
        self
            .opacity(aparecer ? 1 : 0)
            .offset(y: aparecer ? 0 : 12)
            .animation(.spring(duration: 0.45, bounce: 0.1).delay(delay), value: aparecer)
    }
}

// MARK: - Esta semana card

private struct ActividadSemanaCard: View {
    let kpi: KPIData

    var body: some View {
        HStack(spacing: 0) {
            statCol(
                icono: "checkmark.circle.fill",
                color: Color(hex: "#16a34a"),
                valor: kpi.visitasSemana,
                label: "Revisadas"
            )
            Divider().frame(maxHeight: 56)
            statCol(
                icono: "arrow.2.squarepath",
                color: Color("Navy"),
                valor: kpi.cambiosSemana,
                label: "Coroplast"
            )
            Divider().frame(maxHeight: 56)
            statCol(
                icono: "exclamationmark.triangle.fill",
                color: Color(hex: "#dc2626"),
                valor: kpi.danosSemana,
                label: "Daños"
            )
        }
        .padding(.vertical, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statCol(icono: String, color: Color, valor: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
            Text("\(valor)")
                .font(.title.bold())
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
    }
}
