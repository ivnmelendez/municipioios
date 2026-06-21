import SwiftUI

struct CampoRootView: View {
    let authVM: AuthViewModel
    @State private var vm = CampoViewModel()

    var body: some View {
        TabView {
            Tab("Mapa", systemImage: "map.fill") {
                MapaView(
                    mostrarCampanas: false,
                    userId: authVM.perfilId,
                    campanas: vm.campanas,
                    puedeCrearEstructuras: true
                )
                .task { if vm.campanas.isEmpty { await vm.cargar() } }
            }
            Tab("Configuración", systemImage: "gearshape.fill") {
                configTab
            }
        }
        .tint(Color("Navy"))
    }

    private var configTab: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color("Navy"))
                                .frame(width: 56, height: 56)
                            Text(authVM.initiales)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authVM.displayName)
                                .font(.headline)
                            Text("Campo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                let pendientes = OfflineQueueService.shared.pendientes.count
                if pendientes > 0 {
                    Section("Sin sincronizar") {
                        Label {
                            Text("\(pendientes) \(pendientes == 1 ? "acción pendiente" : "acciones pendientes")")
                        } icon: {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await authVM.signOut() }
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
