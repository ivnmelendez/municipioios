import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = DashboardViewModel()
    @State private var mostrarConfiguracion = false
    @State private var aparecer = false
    @State private var ultimaActualizacion: Date? = nil
    @State private var fotoPerfil: Image? = nil

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
        return "Actualizado \(fmt.string(from: fecha))"
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
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(saludo)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        Text(auth.displayName.isEmpty ? "Bienvenido" : auth.displayName.components(separatedBy: " ").first ?? auth.displayName)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color("Navy"))
                        if !horaActualizacion.isEmpty {
                            Text(horaActualizacion)
                                .font(.caption)
                                .foregroundStyle(Color("TextMuted").opacity(0.7))
                                .padding(.top, 1)
                        }
                    }

                    Spacer()

                    Button {
                        mostrarConfiguracion = true
                    } label: {
                        Group {
                            if let foto = fotoPerfil {
                                foto
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
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
                    .padding(.top, 4)
                    .onAppear { cargarFotoPerfil() }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        cargarFotoPerfil()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {

                    // MARK: Inventario principal
                    KPICardPrincipal(
                        titulo: "Total de estructuras",
                        valor: vm.kpi.totalEstructuras,
                        icono: "square.stack.fill",
                        porcentajeOperativas: vm.kpi.isLoaded ? porcentajeOperativas : nil
                    )
                    .padding(.horizontal, 20)
                    .opacity(aparecer ? 1 : 0)
                    .offset(y: aparecer ? 0 : 14)
                    .animation(.spring(duration: 0.5, bounce: 0.15).delay(0.05), value: aparecer)

                    // MARK: Estado
                    DashboardSectionHeader(titulo: "Estado del inventario")
                        .padding(.top, 20)
                        .opacity(aparecer ? 1 : 0)
                        .offset(y: aparecer ? 0 : 10)
                        .animation(.spring(duration: 0.45).delay(0.15), value: aparecer)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        KPICard(
                            titulo: "Activas",
                            valor: vm.kpi.activas,
                            icono: "checkmark.circle.fill",
                            color: Color(hex: "#16a34a")
                        )
                        KPICard(
                            titulo: "Dañadas",
                            valor: vm.kpi.dañadas,
                            icono: "exclamationmark.triangle.fill",
                            color: Color(hex: "#dc2626")
                        )
                        KPICard(
                            titulo: "Necesitan coroplast",
                            valor: vm.kpi.necesitanCoroplast,
                            icono: "printer.fill",
                            color: Color(hex: "#f59e0b")
                        )
                        KPICard(
                            titulo: "Campañas activas",
                            valor: vm.kpi.campanasActivas,
                            icono: "megaphone.fill",
                            color: Color("MunicipioCyan")
                        )
                        KPICard(
                            titulo: "Cambios este mes",
                            valor: vm.kpi.cambiosRotoplasEsteMes,
                            icono: "arrow.triangle.2.circlepath",
                            color: Color("Navy")
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .opacity(aparecer ? 1 : 0)
                    .offset(y: aparecer ? 0 : 14)
                    .animation(.spring(duration: 0.5, bounce: 0.12).delay(0.22), value: aparecer)

                    // MARK: Esta semana
                    if vm.kpi.isLoaded {
                        DashboardSectionHeader(titulo: "Esta semana")
                            .padding(.top, 24)
                            .opacity(aparecer ? 1 : 0)
                            .offset(y: aparecer ? 0 : 10)
                            .animation(.spring(duration: 0.45).delay(0.32), value: aparecer)

                        ActividadSemanaCard(kpi: vm.kpi)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .opacity(aparecer ? 1 : 0)
                            .offset(y: aparecer ? 0 : 14)
                            .animation(.spring(duration: 0.5, bounce: 0.12).delay(0.36), value: aparecer)
                    }

                    // MARK: Estadísticas
                    if !vm.usoCampanas.isEmpty || vm.kpi.isLoaded {
                        DashboardSectionHeader(titulo: "Estadísticas")
                            .padding(.top, 24)
                            .opacity(aparecer ? 1 : 0)
                            .offset(y: aparecer ? 0 : 10)
                            .animation(.spring(duration: 0.45).delay(0.40), value: aparecer)

                        VStack(spacing: 10) {
                            CampanasChartCard(datos: vm.usoCampanas)
                            if !vm.usoColonias.isEmpty || vm.kpi.isLoaded {
                                ColoniasChartCard(datos: vm.usoColonias, detalle: vm.coloniasDetalle)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .opacity(aparecer ? 1 : 0)
                        .offset(y: aparecer ? 0 : 18)
                        .animation(.spring(duration: 0.55, bounce: 0.1).delay(0.46), value: aparecer)
                    }
                }

                if let error = vm.errorMessage {
                    ContentUnavailableView(
                        "Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.top, 40)
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
        }
    }
}

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
            Divider().padding(.leading, 44)
            fila(
                icono: "arrow.triangle.2.circlepath",
                color: Color("MunicipioCyan"),
                titulo: "Cambios realizados",
                valor: kpi.cambiosSemana
            )
            Divider().padding(.leading, 44)
            fila(
                icono: "exclamationmark.triangle.fill",
                color: Color(hex: "#dc2626"),
                titulo: "Daños reportados",
                valor: kpi.danosSemana
            )
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func fila(icono: String, color: Color, titulo: String, valor: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            Text(titulo)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(valor)")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }
}
