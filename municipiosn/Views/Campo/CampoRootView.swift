import SwiftUI

struct CampoRootView: View {
    let authVM: AuthViewModel
    @State private var vm = CampoViewModel()
    @State private var estructuraSeleccionada: EstructuraConParque?

    var body: some View {
        TabView {
            Tab("Mapa", systemImage: "map.fill") {
                MapaView(mostrarCampanas: false, onRegistrarCambio: { estructura in
                    estructuraSeleccionada = estructura
                })
                .task { if vm.campanas.isEmpty { await vm.cargar() } }
            }
            Tab("Estructuras", systemImage: "square.stack.fill") {
                listaTab
            }
        }
        .tint(Color("MunicipioCyan"))
    }

    private var listaTab: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.estructuras.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    listaEstructuras
                }
            }
            .navigationTitle("Estructuras")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salir", role: .destructive) {
                        Task { await authVM.signOut() }
                    }
                    .foregroundStyle(.red)
                }
            }
            .searchable(text: $vm.busqueda, placement: .navigationBarDrawer(displayMode: .always), prompt: "Número, parque o colonia")
            .task { await vm.cargar() }
            .sheet(item: $estructuraSeleccionada) { estructura in
                RegistrarCoroplastView(
                    estructura: estructura,
                    campanas: vm.campanas,
                    userId: authVM.perfilId
                )
            }
        }
    }

    private var listaEstructuras: some View {
        List(vm.estructurasFiltradas) { estructura in
            Button {
                estructuraSeleccionada = estructura
            } label: {
                EstructuraCampoRow(estructura: estructura)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .overlay {
            if vm.estructurasFiltradas.isEmpty && !vm.busqueda.isEmpty {
                ContentUnavailableView.search(text: vm.busqueda)
            }
        }
    }
}

private struct EstructuraCampoRow: View {
    let estructura: EstructuraConParque

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(estructura.numero)
                        .font(.headline)
                    if let local = estructura.numeroLocal {
                        Text(local)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let parque = estructura.parques {
                    Text(parque.nombre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let colonia = parque.colonias {
                        Text(colonia.nombre)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
}
