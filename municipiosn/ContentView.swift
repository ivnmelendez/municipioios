import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @State private var campoBadge = 0
    @State private var tabSeleccionada = "inicio"

    var body: some View {
        if authVM.rol == "campo" {
            CampoRootView(authVM: authVM)
        } else {
            TabView(selection: $tabSeleccionada) {
                Tab("Inicio", systemImage: "house.fill", value: "inicio") {
                    DashboardView()
                }

                Tab("Mapa", systemImage: "map.fill", value: "mapa") {
                    MapaView()
                }

                Tab("Campo", systemImage: "person.2.fill", value: "campo") {
                    CampoAdminView(badge: $campoBadge)
                }
                .badge(campoBadge > 0 ? campoBadge : 0)
            }
            .tint(Color("MunicipioCyan"))
            .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in
                campoBadge += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in
                tabSeleccionada = "campo"
            }
        }
    }
}
