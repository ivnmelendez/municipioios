import SwiftUI

struct CampanasChartCard: View {
    let datos: [UsoCampana]
    @State private var mostrarTodo = false
    @State private var animado = false

    private var top: [UsoCampana] { Array(datos.prefix(5)) }
    private var maximo: Int { top.first?.totalCaras ?? 1 }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "megaphone.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("MunicipioCyan"))
                    Text("Uso de campañas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextPrimary"))
                    Spacer()
                    if datos.count > 5 {
                        HStack(spacing: 3) {
                            Text("Ver todo")
                                .font(.caption)
                                .foregroundStyle(Color("MunicipioCyan"))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color("MunicipioCyan"))
                        }
                    }
                }

                if top.isEmpty {
                    Text("Sin campañas activas")
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMuted"))
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                            CampanaRankRow(
                                rank: index + 1,
                                nombre: item.nombre,
                                valor: item.totalCaras,
                                progreso: animado ? Double(item.totalCaras) / Double(max(maximo, 1)) : 0
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
            CampanasListaCompleta(datos: datos)
        }
    }
}

private struct CampanaRankRow: View {
    let rank: Int
    let nombre: String
    let valor: Int
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
                    .foregroundStyle(Color("MunicipioCyan"))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("MunicipioCyan").opacity(0.1))
                        .frame(width: geo.size.width, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color("MunicipioCyan"), Color("Navy")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progreso, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: Color("MunicipioCyan")
        case 2: Color("MunicipioCyan").opacity(0.7)
        case 3: Color("MunicipioCyan").opacity(0.5)
        default: Color("MunicipioCyan").opacity(0.3)
        }
    }
}

private struct CampanasListaCompleta: View {
    let datos: [UsoCampana]
    @Environment(\.dismiss) private var dismiss
    private var maximo: Int { datos.first?.totalCaras ?? 1 }

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
                            Text("\(item.totalCaras) caras")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("MunicipioCyan"))
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color("MunicipioCyan").opacity(0.1))
                                    .frame(width: geo.size.width, height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color("MunicipioCyan"), Color("Navy")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * Double(item.totalCaras) / Double(max(maximo, 1)), height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.leading, 28)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Uso de campañas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
