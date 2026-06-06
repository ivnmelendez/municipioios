import SwiftUI

struct DashboardView: View {
    @State private var vm = DashboardViewModel()

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
        fmt.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
        let raw = fmt.string(from: Date())
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(saludo), Jose Luis.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color("Navy"))
                    Text(fechaFormateada)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    KPICardPrincipal(
                        titulo: "Total de estructuras",
                        valor: vm.kpi.totalEstructuras,
                        icono: "square.stack.fill"
                    )
                    .padding(.horizontal, 20)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
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
                            titulo: "Campañas activas",
                            valor: vm.kpi.campanasActivas,
                            icono: "megaphone.fill",
                            color: Color("MunicipioCyan")
                        )
                        KPICard(
                            titulo: "Cambios de rotoplas",
                            valor: vm.kpi.cambiosRotoplasEsteMes,
                            icono: "arrow.triangle.2.circlepath",
                            color: Color("Navy"),
                            subtitulo: "Este mes"
                        )
                    }
                    .padding(.horizontal, 20)
                }

                if let error = vm.errorMessage {
                    ContentUnavailableView(
                        "Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color("Background"))
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
    }
}
