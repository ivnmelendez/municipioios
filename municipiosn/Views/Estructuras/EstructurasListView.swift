import SwiftUI

@MainActor
@Observable
final class EstructurasListViewModel {
    var estructuras: [EstructuraConParque] = []
    var filtradas: [EstructuraConParque] = []
    var busqueda = ""
    var isLoading = false
    var errorMessage: String?
    var estructuraSeleccionada: EstructuraConParque?
    var carasDetalle: [CaraDetalle] = []
    var mostrarDetalle = false

    func cargar() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            estructuras = try await EstructurasService.shared.fetchEstructuras()
            filtrar()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filtrar() {
        guard !busqueda.isEmpty else { filtradas = estructuras; return }
        filtradas = estructuras.filter {
            $0.numero.localizedCaseInsensitiveContains(busqueda) ||
            ($0.parques?.nombre.localizedCaseInsensitiveContains(busqueda) ?? false) ||
            ($0.parques?.colonias?.nombre.localizedCaseInsensitiveContains(busqueda) ?? false)
        }
    }

    func seleccionar(_ estructura: EstructuraConParque) async {
        estructuraSeleccionada = estructura
        carasDetalle = []
        do {
            carasDetalle = try await EstructurasService.shared.fetchCarasDetalle(estructuraId: estructura.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        mostrarDetalle = true
    }
}

struct EstructurasListView: View {
    @State private var vm = EstructurasListViewModel()
    @State private var isScrolled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estructuras")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color("Navy"))
                    Text(vm.estructuras.isEmpty ? "Cargando…" : "\(vm.estructuras.count) registradas")
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

                if vm.isLoading && vm.estructuras.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if vm.filtradas.isEmpty && !vm.busqueda.isEmpty {
                    ContentUnavailableView.search(text: vm.busqueda)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.filtradas) { estructura in
                            EstructuraRow(estructura: estructura)
                                .onTapGesture {
                                    Task { await vm.seleccionar(estructura) }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color("Background"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 0)
                .ignoresSafeArea(edges: .top)
                .opacity(isScrolled ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isScrolled)
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y > 8
        } action: { _, scrolled in
            isScrolled = scrolled
        }
        .searchable(text: $vm.busqueda, prompt: "Número, parque o colonia")
        .onChange(of: vm.busqueda) { vm.filtrar() }
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
        .sheet(isPresented: $vm.mostrarDetalle) {
            if let estructura = vm.estructuraSeleccionada {
                EstructuraDetalleSheet(
                    estructura: estructura,
                    caras: vm.carasDetalle
                )
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.resizes)
            }
        }
    }
}

struct EstructuraRow: View {
    let estructura: EstructuraConParque

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: estructura.estado.icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(estructura.estado.color)
                .frame(width: 44, height: 44)
                .background(estructura.estado.color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(estructura.numero)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                if let parque = estructura.parques {
                    Text(parque.nombre)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                        .lineLimit(1)
                }
            }

            Spacer()

            EstadoBadge(estado: estructura.estado)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
