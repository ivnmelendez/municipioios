import SwiftUI

struct ColoniasChartCard: View {
    let datos: [UsoColonia]
    let detalle: [ColoniaConCampanas]
    @State private var mostrarTodo = false

    private var top: [UsoColonia] { Array(datos.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Estructuras por colonia", systemImage: "map.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                Spacer()
                Button {
                    mostrarTodo = true
                } label: {
                    HStack(spacing: 3) {
                        Text("Ver todas")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color("Navy"))
                }
            }

            if top.isEmpty {
                Text("Sin datos de colonias")
                    .font(.body)
                    .foregroundStyle(Color("TextMuted"))
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color("TextMuted"))
                                .frame(width: 20, alignment: .center)
                            Text(item.nombre)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.totalEstructuras)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color("Navy"))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 11)
                        if index < top.count - 1 {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(isPresented: $mostrarTodo) {
            ColoniasListaCompleta(datos: datos, detalle: detalle)
        }
    }
}

private struct ColoniasListaCompleta: View {
    let datos: [UsoColonia]
    let detalle: [ColoniaConCampanas]
    @Environment(\.dismiss) private var dismiss
    @State private var busqueda = ""

    private var filtrados: [UsoColonia] {
        busqueda.isEmpty ? datos : datos.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
    }

    private func detalleParaColonia(_ nombre: String) -> ColoniaConCampanas? {
        detalle.first { $0.nombre == nombre }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(filtrados.enumerated()), id: \.element.id) { index, item in
                    let detColonia = detalleParaColonia(item.nombre)
                    NavigationLink {
                        ColoniaDetalleView(colonia: detColonia ?? ColoniaConCampanas(
                            id: item.id,
                            nombre: item.nombre,
                            totalEstructuras: item.totalEstructuras,
                            campanas: []
                        ))
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color("TextMuted"))
                                .frame(width: 28, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.nombre)
                                    .font(.body)
                                if let d = detColonia, !d.campanas.isEmpty {
                                    Text("\(d.campanas.count) campaña\(d.campanas.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(Color("MunicipioCyan"))
                                }
                            }
                            Spacer()
                            Text("\(item.totalEstructuras)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color("Navy"))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $busqueda, prompt: "Buscar colonia")
            .navigationTitle("Estructuras por colonia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

private struct ColoniaDetalleView: View {
    let colonia: ColoniaConCampanas
    @State private var fotoItem: CampanaFotoItem?

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Estructuras")
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    Text("\(colonia.totalEstructuras)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color("Navy"))
                }
            }

            Section("Campañas activas") {
                if colonia.campanas.isEmpty {
                    Text("Sin campañas activas")
                        .foregroundStyle(Color("TextMuted"))
                } else {
                    ForEach(colonia.campanas) { campana in
                        Button {
                            if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                                fotoItem = CampanaFotoItem(url: url, titulo: campana.nombre)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(campana.nombre)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(campana.totalCaras) cara\(campana.totalCaras == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(Color("TextMuted"))
                                }
                                Spacer()
                                Image(systemName: campana.fotoUrl != nil ? "photo" : "megaphone.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color("MunicipioCyan"))
                            }
                            .padding(.vertical, 2)
                        }
                        .disabled(campana.fotoUrl == nil)
                    }
                }
            }
        }
        .navigationTitle(colonia.nombre)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $fotoItem) { item in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
        }
    }
}

private struct CampanaFotoItem: Identifiable {
    let id = UUID()
    let url: URL
    let titulo: String
}
