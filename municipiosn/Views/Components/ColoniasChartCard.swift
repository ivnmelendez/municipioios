import SwiftUI
import Charts

struct ColoniasChartCard: View {
    let datos: [UsoColonia]
    @State private var animado = false

    private var top: [UsoColonia] { Array(datos.prefix(8)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                Text("Estructuras por colonia")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))
                Spacer()
                if !top.isEmpty {
                    Text("Top \(top.count)")
                        .font(.caption)
                        .foregroundStyle(Color("TextMuted"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color("Navy").opacity(0.08), in: Capsule())
                }
            }

            if top.isEmpty {
                Text("Sin datos de colonias")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextMuted"))
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                Chart(top) { item in
                    BarMark(
                        x: .value("Estructuras", animado ? item.totalEstructuras : 0),
                        y: .value("Colonia", item.nombre)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("Navy"), Color("Navy").opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .center) {
                        Text("\(item.totalEstructuras)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color("TextMuted"))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(top.count) * 46)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.65).delay(0.15)) {
                        animado = true
                    }
                }
                .onChange(of: datos.map(\.id)) {
                    animado = false
                    withAnimation(.easeOut(duration: 0.65).delay(0.1)) {
                        animado = true
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
