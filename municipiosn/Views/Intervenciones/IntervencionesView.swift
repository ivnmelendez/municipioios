import SwiftUI

struct IntervencionesView: View {
    let periodo: FiltroFecha
    @State private var vm = IntervencionesViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.intervenciones.isEmpty {
                ProgressView("Cargando intervenciones…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.intervenciones.isEmpty {
                ScrollView {
                    ContentUnavailableView(
                        "Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            } else if vm.intervenciones.isEmpty {
                ScrollView {
                    ContentUnavailableView(
                        "Sin intervenciones",
                        systemImage: "arrow.triangle.2.circlepath",
                        description: Text("No hay cambios en el período seleccionado.")
                    )
                }
            } else {
                List(vm.intervenciones) { intervencion in
                    IntervencionRow(intervencion: intervencion)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .background(Color("Background"))
        .refreshable { await vm.cargar() }
        .task { await vm.aplicarFiltro(periodo) }
        .onChange(of: periodo) { _, new in
            Task { await vm.aplicarFiltro(new) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in
            Task { await vm.cargar() }
        }
    }
}


struct IntervencionRow: View {
    let intervencion: IntervencionCompleta

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(intervencion.estructuras?.numero ?? "—")
                        .font(.headline)
                        .foregroundStyle(Color("Navy"))
                    if let parque = intervencion.estructuras?.parques?.nombre {
                        Text(parque)
                            .font(.caption)
                            .foregroundStyle(Color("TextMuted"))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(intervencion.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("TextMuted"))
                    if let nombre = intervencion.rondines?.perfiles?.nombre {
                        Text(nombre)
                            .font(.caption2)
                            .foregroundStyle(Color("Navy"))
                    }
                }
            }

            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    FotoAsyncImage(url: intervencion.fotoAntesUrl, aspectRatio: 1, cornerRadius: 10, thumbnailWidth: 200)
                    Text("Antes")
                        .font(.caption2)
                        .foregroundStyle(Color("TextMuted"))
                }
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color("Navy"))
                VStack(spacing: 4) {
                    FotoAsyncImage(url: intervencion.fotoDespuesUrl, aspectRatio: 1, cornerRadius: 10, thumbnailWidth: 200)
                    Text("Después")
                        .font(.caption2)
                        .foregroundStyle(Color("TextMuted"))
                }
            }

            if let notas = intervencion.notas, !notas.isEmpty {
                Text(notas)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
