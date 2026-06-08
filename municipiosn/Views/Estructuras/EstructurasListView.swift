import SwiftUI

@MainActor
@Observable
final class EstructurasListViewModel {
    var estructuras: [EstructuraConParque] = []
    var filtradas: [EstructuraConParque] = []
    var busqueda = ""
    var filtroEstado: EstadoEstructura? = nil
    var isLoading = false
    var errorMessage: String?
    var estructuraSeleccionada: EstructuraConParque?
    var carasDetalle: [CaraDetalle] = []
    var mostrarDetalle = false

    func conteo(_ estado: EstadoEstructura) -> Int {
        estructuras.filter { $0.estado == estado }.count
    }

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
        var base = estructuras
        if let filtro = filtroEstado {
            base = base.filter { $0.estado == filtro }
        }
        guard !busqueda.isEmpty else { filtradas = base; return }
        filtradas = base.filter {
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

// MARK: - Main View

struct EstructurasListView: View {
    @State private var vm = EstructurasListViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !vm.estructuras.isEmpty {
                        StatsStrip(vm: vm)
                    }

                    FiltroChips(vm: vm)

                    ListaEstructuras(vm: vm)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color("Background"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.busqueda, prompt: "Número, parque o colonia")
            .onChange(of: vm.busqueda) { vm.filtrar() }
            .task { await vm.cargar() }
            .refreshable { await vm.cargar() }
            .sheet(isPresented: $vm.mostrarDetalle) {
                if let estructura = vm.estructuraSeleccionada {
                    EstructuraDetalleSheet(estructura: estructura, caras: vm.carasDetalle)
                        .presentationDetents([.medium, .large])
                        .presentationContentInteraction(.resizes)
                }
            }
        }
    }
}

// MARK: - Stats Strip

private struct StatsStrip: View {
    let vm: EstructurasListViewModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(EstadoEstructura.allCases, id: \.self) { estado in
                StatChip(
                    estado: estado,
                    count: vm.conteo(estado),
                    isActive: vm.filtroEstado == estado
                )
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) {
                        if vm.filtroEstado == estado {
                            vm.filtroEstado = nil
                        } else {
                            vm.filtroEstado = estado
                        }
                        vm.filtrar()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct StatChip: View {
    let estado: EstadoEstructura
    let count: Int
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: estado.icono)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? .white : estado.color)

            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .white : Color("Navy"))
                .contentTransition(.numericText())

            Text(estado.etiqueta)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isActive ? .white.opacity(0.8) : Color("TextMuted"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(estado.color)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Filtro Chips

private struct FiltroChips: View {
    let vm: EstructurasListViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FiltroChip(
                    label: "Todas",
                    icon: "square.stack.fill",
                    color: Color("MunicipioCyan"),
                    isActive: vm.filtroEstado == nil
                ) {
                    withAnimation(.spring(duration: 0.3)) {
                        vm.filtroEstado = nil
                        vm.filtrar()
                    }
                }

                ForEach(EstadoEstructura.allCases, id: \.self) { estado in
                    FiltroChip(
                        label: estado.etiqueta,
                        icon: estado.icono,
                        color: estado.color,
                        isActive: vm.filtroEstado == estado
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            vm.filtroEstado = vm.filtroEstado == estado ? nil : estado
                            vm.filtrar()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct FiltroChip: View {
    let label: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isActive ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isActive {
                        Capsule().fill(color)
                    }
                }
                .glassEffect(in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lista

private struct ListaEstructuras: View {
    let vm: EstructurasListViewModel

    var body: some View {
        if vm.isLoading && vm.estructuras.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if vm.filtradas.isEmpty && !vm.busqueda.isEmpty {
            ContentUnavailableView.search(text: vm.busqueda)
                .padding(.top, 40)
        } else if vm.filtradas.isEmpty && vm.filtroEstado != nil {
            ContentUnavailableView(
                "Sin estructuras",
                systemImage: vm.filtroEstado?.icono ?? "square.stack",
                description: Text("No hay estructuras con estado \"\(vm.filtroEstado?.etiqueta ?? "")\"")
            )
            .padding(.top, 40)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.filtradas.enumerated()), id: \.element.id) { index, estructura in
                    EstructuraRow(estructura: estructura)
                        .onTapGesture {
                            Task { await vm.seleccionar(estructura) }
                        }

                    if index < vm.filtradas.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Row

struct EstructuraRow: View {
    let estructura: EstructuraConParque

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(estructura.estado.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: estructura.estado.icono)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(estructura.estado.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(estructura.numero)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color("Navy"))

                if let parque = estructura.parques {
                    if let colonia = parque.colonias {
                        Text("\(parque.nombre) · \(colonia.nombre)")
                            .font(.caption)
                            .foregroundStyle(Color("TextMuted"))
                            .lineLimit(1)
                    } else {
                        Text(parque.nombre)
                            .font(.caption)
                            .foregroundStyle(Color("TextMuted"))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("TextMuted").opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
