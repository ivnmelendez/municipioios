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
            List {
                sidebarFila(icono: "house.fill",       label: "Inicio",       tag: "inicio")
                sidebarFila(icono: "map.fill",          label: "Mapa",         tag: "mapa")
                sidebarFila(icono: "square.stack.fill", label: "Estructuras",  tag: "estructuras")

                Divider()

                sidebarFila(icono: "person.2.fill", label: "Campo", tag: "campo", badge: campoBadge)
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

    @ViewBuilder
    private func sidebarFila(icono: String, label: String, tag: String, badge: Int = 0) -> some View {
        let activo = tabSeleccionada == tag
        Button { tabSeleccionada = tag } label: {
            HStack {
                Label(label, systemImage: icono)
                    .foregroundStyle(activo ? Color("Navy") : .primary)
                    .fontWeight(activo ? .semibold : .regular)
                if badge > 0 {
                    Spacer()
                    Text("\(badge)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                }
            }
        }
        .listRowBackground(activo ? Color("Navy").opacity(0.1) : Color.clear)
        .buttonStyle(.plain)
    }
}
