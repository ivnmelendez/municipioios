import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @SceneStorage("tabSeleccionada") private var tabSeleccionada = "inicio"
    @State private var campoBadge = 0

    var body: some View {
        if authVM.rol == "campo" || authVM.rol == "campo_admin" {
            CampoRootView(authVM: authVM)
                .overlay(alignment: .top) { NetworkStatusBanner() }
        } else if authVM.rol == "oficina" {
            OficinaRootView(authVM: authVM)
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
                }
            }
            Tab("Historial", systemImage: "clock.fill", value: "campo") {
                CampoAdminView(badge: $campoBadge)
            }
            .badge(campoBadge > 0 ? campoBadge : 0)
        }
        .tint(Color("Navy"))
        .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in campoBadge += 1 }
        .onChange(of: tabSeleccionada) { _, nuevo in
            if nuevo == "campo" {
                campoBadge = 0
                RealtimeService.shared.badgeCount = 0
            }
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "pendingRondines") {
                UserDefaults.standard.removeObject(forKey: "pendingRondines")
                tabSeleccionada = "campo"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in
            tabSeleccionada = "campo"
        }
        .onReceive(NotificationCenter.default.publisher(for: .abrirMapaEnEstructura)) { _ in tabSeleccionada = "mapa" }
    }

}
