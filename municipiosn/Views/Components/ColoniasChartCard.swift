import SwiftUI

struct ColoniasChartCard: View {
    let datos: [UsoColonia]
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
                    if datos.count > 5 {
                        HStack(spacing: 3) {
                            Text("Ver todo")
                                .font(.caption)
                                .foregroundStyle(Color("Navy"))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color("Navy"))
                        }
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
            ColoniasListaCompleta(datos: datos)
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

private struct ColoniasListaCompleta: View {
    let datos: [UsoColonia]
    @Environment(\.dismiss) private var dismiss
    private var maximo: Int { datos.first?.totalEstructuras ?? 1 }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(datos.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color("TextMuted"))
                                .frame(width: 24, alignment: .trailing)
                            Text(item.nombre)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.totalEstructuras)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("Navy"))
                                .monospacedDigit()
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
