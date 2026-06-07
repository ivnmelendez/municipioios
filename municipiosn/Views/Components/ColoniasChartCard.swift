import SwiftUI

struct ColoniasChartCard: View {
    let datos: [UsoColonia]
    let detalle: [ColoniaConCampanas]
    @State private var mostrarTodo = false
    @State private var animado = false

    private var top: [UsoColonia] { Array(datos.prefix(5)) }
    private var maximo: Int { top.first?.totalEstructuras ?? 1 }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Navy"))
                    Text("Estructuras por colonia")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextPrimary"))
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Ver todo")
                            .font(.caption)
                            .foregroundStyle(Color("Navy"))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color("Navy"))
                    }
                }

                if top.isEmpty {
                    Text("Sin datos de colonias")
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                            ColoniaRankRow(
                                rank: index + 1,
                                nombre: item.nombre,
                                valor: item.totalEstructuras,
                                maximo: maximo,
                                progreso: animado ? Double(item.totalEstructuras) / Double(max(maximo, 1)) : 0
                            )
                        }
                    }
                    .onAppear {
                        withAnimation(.spring(duration: 0.6).delay(0.1)) { animado = true }
                    }
                    .onChange(of: datos.map(\.id)) {
                        animado = false
                        withAnimation(.spring(duration: 0.6).delay(0.1)) { animado = true }
                    }
                }
            }
            .padding(20)
            .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $mostrarTodo) {
            ColoniasListaCompleta(datos: datos, detalle: detalle)
        }
    }
}

private struct ColoniaRankRow: View {
    let rank: Int
    let nombre: String
    let valor: Int
    let maximo: Int
    let progreso: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("\(rank)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(rankColor, in: Circle())
                Text(nombre)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(valor)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("Navy").opacity(0.08))
                        .frame(width: geo.size.width, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("Navy"))
                        .frame(width: geo.size.width * progreso, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: Color("Navy")
        case 2: Color("Navy").opacity(0.7)
        case 3: Color("Navy").opacity(0.5)
        default: Color("Navy").opacity(0.3)
        }
    }
}

// MARK: - Lista completa

private struct ColoniasListaCompleta: View {
    let datos: [UsoColonia]
    let detalle: [ColoniaConCampanas]
    @Environment(\.dismiss) private var dismiss
    private var maximo: Int { datos.first?.totalEstructuras ?? 1 }

    private func detalleParaColonia(_ nombre: String) -> ColoniaConCampanas? {
        detalle.first { $0.nombre == nombre }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(datos.enumerated()), id: \.element.id) { index, item in
                    let detColonia = detalleParaColonia(item.nombre)
                    NavigationLink {
                        ColoniaDetalleView(colonia: detColonia ?? ColoniaConCampanas(
                            id: item.id,
                            nombre: item.nombre,
                            totalEstructuras: item.totalEstructuras,
                            campanas: []
                        ))
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color("TextMuted"))
                                    .frame(width: 24, alignment: .trailing)
                                Text(item.nombre)
                                    .font(.subheadline)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(item.totalEstructuras)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color("Navy"))
                                        .monospacedDigit()
                                    if let d = detColonia, !d.campanas.isEmpty {
                                        Text("\(d.campanas.count) campaña\(d.campanas.count == 1 ? "" : "s")")
                                            .font(.caption2)
                                            .foregroundStyle(Color("MunicipioCyan"))
                                    }
                                }
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color("Navy").opacity(0.08))
                                        .frame(width: geo.size.width, height: 3)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color("Navy"))
                                        .frame(width: geo.size.width * Double(item.totalEstructuras) / Double(max(maximo, 1)), height: 3)
                                }
                            }
                            .frame(height: 3)
                            .padding(.leading, 28)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
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

// MARK: - Detalle de colonia

private struct CampanaFotoItem: Identifiable {
    let id = UUID()
    let url: URL
    let titulo: String
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Navy"))
                }
            }

            if colonia.campanas.isEmpty {
                Section("Campañas activas") {
                    Text("Sin campañas activas")
                        .foregroundStyle(Color("TextMuted"))
                        .font(.subheadline)
                }
            } else {
                Section("Campañas activas") {
                    ForEach(colonia.campanas) { campana in
                        Button {
                            if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                                fotoItem = CampanaFotoItem(url: url, titulo: campana.nombre)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(campana.nombre)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(campana.totalCaras) cara\(campana.totalCaras == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(Color("TextMuted"))
                                }
                                Spacer()
                                if campana.fotoUrl != nil {
                                    Image(systemName: "photo")
                                        .font(.caption)
                                        .foregroundStyle(Color("MunicipioCyan"))
                                } else {
                                    Image(systemName: "megaphone.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color("MunicipioCyan"))
                                }
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
