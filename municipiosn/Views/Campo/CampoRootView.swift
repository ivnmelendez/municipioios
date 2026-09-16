import SwiftUI

struct CampoRootView: View {
    let authVM: AuthViewModel
    @State private var vm = CampoViewModel()
    @State private var tabSeleccionada = "inicio"


    var body: some View {
        TabView(selection: $tabSeleccionada) {
            Tab("Inicio", systemImage: "house.fill", value: "inicio") {
                CampoInicioView()
            }
            Tab("Ruta", systemImage: "figure.walk", value: "ruta") {
                RutaSeleccionView(vm: vm, userId: authVM.perfilId)
            }
            Tab("Mapa", systemImage: "map.fill", value: "mapa") {
                MapaView(
                    mostrarCampanas: false,
                    userId: authVM.perfilId,
                    campanas: vm.campanas,
                    puedeCrearEstructuras: true,
                    esCampo: true
                )
                .task { if vm.campanas.isEmpty { await vm.cargar() } }
            }
            if authVM.rol == "campo_admin" {
                Tab("Estructuras", systemImage: "square.stack.fill", value: "estructuras") {
                    NavigationStack {
                        EstructurasListView(esCampo: true)
                    }
                }
            }
        }
        .tint(Color("Azul"))
        .onReceive(NotificationCenter.default.publisher(for: .abrirMapaEnEstructura)) { _ in
            tabSeleccionada = "mapa"
        }
    }

}
