import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @SceneStorage("tabSeleccionada") private var tabSeleccionada = "inicio"
    @State private var campoBadge = 0

    var body: some View {
        if authVM.rol == "campo" {
            CampoRootView(authVM: authVM)
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
                NavigationStack {
                    MapaView()
                        .navigationDestination(for: EstructuraConParque.self) { e in
                            EstructuraDetalleView(estructura: e)
                        }
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in
            tabSeleccionada = "campo"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: .mostrarSeccionVisitas, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .abrirMapaEnEstructura)) { _ in tabSeleccionada = "mapa" }
    }

}
