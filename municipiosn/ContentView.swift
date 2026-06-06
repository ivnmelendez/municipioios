import SwiftUI

struct ContentView: View {
    let authVM: AuthViewModel
    @State private var intervencionesVM = IntervencionesViewModel()

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }

            Tab("Mapa", systemImage: "map.fill") {
                MapaView()
            }

            Tab("Intervenciones", systemImage: "arrow.triangle.2.circlepath") {
                IntervencionesView()
            }
            .badge(intervencionesVM.badgeCount > 0 ? intervencionesVM.badgeCount : 0)
        }
        .tint(Color("Cyan"))
        .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in
            intervencionesVM.badgeCount += 1
        }
    }
}
