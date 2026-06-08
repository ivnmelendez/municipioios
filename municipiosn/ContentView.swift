import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @State private var intervencionesVM = IntervencionesViewModel()

    var body: some View {
        if authVM.rol == "campo" {
            CampoRootView(authVM: authVM)
        } else {
            TabView {
                Tab("Dashboard", systemImage: "chart.bar.fill") {
                    DashboardView()
                }

                Tab("Mapa", systemImage: "map.fill") {
                    MapaView()
                }

                Tab("Estructuras", systemImage: "square.stack.fill") {
                    EstructurasListView()
                }

                Tab("Cambios", systemImage: "arrow.triangle.2.circlepath") {
                    IntervencionesView()
                }
                .badge(intervencionesVM.badgeCount > 0 ? intervencionesVM.badgeCount : 0)
            }
            .tint(Color("MunicipioCyan"))
            .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in
                intervencionesVM.badgeCount += 1
            }
        }
    }
}
