import SwiftUI

struct ColoniasChartCard: View {
    let datos: [UsoColonia]
    let detalle: [ColoniaConCampanas]
    @State private var mostrarTodo = false
    @State private var animado = false

    private var top: [UsoColonia] { Array(datos.prefix(5)) }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(spacing: 0) {
                HStack {
                    Text("Estructuras por colonia")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    Text("Top 5")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("Navy").opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("Navy").opacity(0.07), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if top.isEmpty {
                    Text("Sin datos de colonias")
                        .font(.body)
                        .foregroundStyle(Color("TextMuted"))
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                } else {
                    let maxVal = top.first?.totalEstructuras ?? 1
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                        fila(item: item, max: maxVal, posicion: index + 1)
                        if item.id != top.last?.id {
                            Divider().padding(.leading, 20)
                        }
                    }
                    Spacer().frame(height: 8)
                }
            }
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.05).delay(0.3)) { animado = true }
        }
        .sheet(isPresented: $mostrarTodo) {
            ColoniasListaCompleta(datos: datos, detalle: detalle)
        }
    }

    private func fila(item: UsoColonia, max: Int, posicion: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(posicion)")
                .font(.caption.weight(.bold))
                .foregroundStyle(posicion == 1 ? Color(hex: "#f59e0b") : Color("TextMuted").opacity(0.5))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.nombre)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.totalEstructuras)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color("Navy"))
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("Navy").opacity(0.08))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    posicion == 1
                                    ? LinearGradient(colors: [Color("Navy"), Color("Navy").opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color("Navy").opacity(0.6), Color("Navy").opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: animado ? geo.size.width * (Double(item.totalEstructuras) / Double(max)) : 0)
                        }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
                                        .foregroundStyle(Color("Navy"))
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
                                    .foregroundStyle(Color("Navy"))
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
