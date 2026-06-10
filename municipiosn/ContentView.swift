import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @State private var campoBadge = 0

    var body: some View {
        if authVM.rol == "campo" {
            CampoRootView(authVM: authVM)
        } else {
            TabView {
                Tab("Inicio", systemImage: "house.fill") {
                    DashboardView()
                }

                Tab("Mapa", systemImage: "map.fill") {
                    MapaView()
                }

                Tab("Campo", systemImage: "person.2.fill") {
                    CampoAdminView(badge: $campoBadge)
                }
                .badge(campoBadge > 0 ? campoBadge : 0)
            }
            .tint(Color("MunicipioCyan"))
            .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in
                campoBadge += 1
            }
        }
    }
}
