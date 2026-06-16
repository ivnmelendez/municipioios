import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @SceneStorage("tabSeleccionada") private var tabSeleccionada = "inicio"
    @State private var campoBadge = 0

    var body: some View {
        if authVM.rol == "campo" {
            CampoRootView(authVM: authVM)
                .overlay(alignment: .top) { NetworkStatusBanner() }
        } else if sizeClass == .regular {
            iPadLayout
                .overlay(alignment: .top) { NetworkStatusBanner() }
        } else {
            iPhoneLayout
                .overlay(alignment: .top) { NetworkStatusBanner() }
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        TabView(selection: $tabSeleccionada) {
            Tab("Inicio", systemImage: "house.fill", value: "inicio") {
                DashboardView()
            }
            Tab("Mapa", systemImage: "map.fill", value: "mapa") {
                MapaView()
            }
            Tab("Estructuras", systemImage: "square.stack.fill", value: "estructuras") {
                NavigationStack {
                    EstructurasListView()
                        .navigationDestination(for: EstructuraConParque.self) { e in
                            EstructuraDetalleView(estructura: e)
                        }
                }
            }
            Tab("Campo", systemImage: "person.2.fill", value: "campo") {
                CampoAdminView(badge: $campoBadge)
            }
            .badge(campoBadge > 0 ? campoBadge : 0)
        }
        .tint(Color("Navy"))
        .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in campoBadge += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in tabSeleccionada = "campo" }
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $tabSeleccionada) {
                Label("Inicio", systemImage: "house.fill").tag("inicio")
                    .accessibilityLabel("Dashboard de inicio")
                Label("Mapa", systemImage: "map.fill").tag("mapa")
                    .accessibilityLabel("Mapa de estructuras")
                Label("Estructuras", systemImage: "square.stack.fill").tag("estructuras")
                    .accessibilityLabel("Lista de estructuras")

                Divider()

                HStack {
                    Label("Campo", systemImage: "person.2.fill").tag("campo")
                    if campoBadge > 0 {
                        Spacer()
                        Text("\(campoBadge)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                    }
                }
            }
            .navigationTitle("Municipio SN")
            .tint(Color("Navy"))
        } detail: {
            switch tabSeleccionada {
            case "mapa":
                MapaView()
            case "estructuras":
                NavigationStack {
                    EstructurasListView()
                        .navigationDestination(for: EstructuraConParque.self) { e in
                            EstructuraDetalleView(estructura: e)
                        }
                }
            case "campo":
                CampoAdminView(badge: $campoBadge)
            default:
                DashboardView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in campoBadge += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in tabSeleccionada = "campo" }
    }
}
