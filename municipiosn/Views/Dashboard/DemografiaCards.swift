import SwiftUI
import Charts

// MARK: - Pirámide de edad

struct PiramideEdadCard: View {
    let dem: DemografiaAlcance

    private struct GrupoEdad: Identifiable {
        let id = UUID()
        let label: String
        let fem: Int
        let mas: Int
    }

    private var grupos: [GrupoEdad] {
        [
            GrupoEdad(label: "0–5",   fem: dem.p0a5F,   mas: dem.p0a5M),
            GrupoEdad(label: "6–11",  fem: dem.p6a11F,  mas: dem.p6a11M),
            GrupoEdad(label: "12–17", fem: dem.p12a17F, mas: dem.p12a17M),
            GrupoEdad(label: "18–24", fem: dem.p18a24F, mas: dem.p18a24M),
            GrupoEdad(label: "25–59", fem: dem.p25a59F, mas: dem.p25a59M),
            GrupoEdad(label: "60+",   fem: dem.p60masF, mas: dem.p60masM),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 20)
            Chart(grupos) { g in
                barFem(g)
                barMas(g)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { val in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text(abs(v) >= 1000 ? "\(abs(v)/1000)k" : "\(abs(v))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            HStack(spacing: 16) {
                legendaItem(color: Color(hex: "#db2777"), label: "Mujeres")
                legendaItem(color: Color("Navy"),         label: "Hombres")
                Spacer()
                Text("INEGI 2020")
                    .font(.caption2)
                    .foregroundStyle(Color("TextMuted").opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ChartContentBuilder
    private func barFem(_ g: GrupoEdad) -> some ChartContent {
        BarMark(x: .value("Personas", -g.fem), y: .value("Edad", g.label))
            .foregroundStyle(Color(hex: "#db2777").opacity(0.8))
    }

    @ChartContentBuilder
    private func barMas(_ g: GrupoEdad) -> some ChartContent {
        BarMark(x: .value("Personas", g.mas), y: .value("Edad", g.label))
            .foregroundStyle(Color("Navy").opacity(0.75))
    }

    private var header: some View {
        HStack {
            Text("Pirámide de edad")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextMuted"))
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(Color("Navy").opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private func legendaItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 8)
            Text(label).font(.caption2).foregroundStyle(Color("TextMuted"))
        }
    }
}

// MARK: - Conectividad digital

struct ConectividadCard: View {
    let dem: DemografiaAlcance

    private var pctSinInternet: Double {
        guard dem.tvivhab > 0 else { return 0 }
        return Double(dem.vphSinInter) / Double(dem.tvivhab)
    }

    private var pctConInternet: Double { 1 - pctSinInternet }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conectividad digital")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                Text("INEGI 2020")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color("TextMuted").opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 24) {
                ZStack {
                    Chart {
                        SectorMark(angle: .value("Sin", pctSinInternet), innerRadius: .ratio(0.6))
                            .foregroundStyle(Color(hex: "#dc2626").opacity(0.8))
                        SectorMark(angle: .value("Con", pctConInternet), innerRadius: .ratio(0.6))
                            .foregroundStyle(Color("Navy").opacity(0.7))
                    }
                    .frame(width: 120, height: 120)

                    VStack(spacing: 2) {
                        Text("\(Int(pctSinInternet * 100))%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#dc2626"))
                        Text("sin\ninternet")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color("TextMuted"))
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    stat(valor: dem.vphSinInter, label: "Hogares sin internet", color: Color(hex: "#dc2626"))
                    stat(valor: dem.vphInter,    label: "Hogares con internet", color: Color("Navy"))
                    stat(valor: dem.tvivhab,     label: "Total hogares",        color: Color("TextMuted"))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Spacer().frame(height: 4)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stat(valor: Int, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(valor.formatted())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color("TextMuted"))
            }
        }
    }
}

// MARK: - Segmentos por colonia

struct SegmentosColoniaCard: View {
    let colonias: [ColoniaAlcance]
    @State private var mostrarTodo = false

    private var top: [ColoniaAlcance] { Array(colonias.prefix(5)) }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(spacing: 0) {
                HStack {
                    Text("Segmentos por colonia")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    Text("INEGI 2020")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("Navy").opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("Navy").opacity(0.07), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                leyenda
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Divider().padding(.horizontal, 20)

                ForEach(top) { col in
                    filaColonia(col)
                    if col.id != top.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
                Spacer().frame(height: 8)
            }
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .sheet(isPresented: $mostrarTodo) {
            SegmentosLista(colonias: colonias)
        }
    }

    private var leyenda: some View {
        HStack(spacing: 12) {
            legendaItem(color: Color(hex: "#f59e0b"), label: "0–14")
            legendaItem(color: Color("Navy"),         label: "15–64")
            legendaItem(color: Color(hex: "#16a34a"), label: "60+")
            Spacer()
        }
    }

    private func legendaItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(Color("TextMuted"))
        }
    }

    private func filaColonia(_ col: ColoniaAlcance) -> some View {
        let total = max(col.pob0a14 + col.pob15a64 + col.p60ymas, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(col.nombre)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(col.poblacion.formatted())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#f59e0b"))
                        .frame(width: geo.size.width * CGFloat(col.pob0a14) / CGFloat(total), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("Navy").opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(max(col.pob15a64 - col.p60ymas, 0)) / CGFloat(total), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#16a34a"))
                        .frame(width: geo.size.width * CGFloat(col.p60ymas) / CGFloat(total), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Seguro médico

struct SeguroMedicoCard: View {
    let dem: DemografiaAlcance

    private var pctSinSeguro: Double {
        let total = dem.psinder + dem.pderSS
        guard total > 0 else { return 0 }
        return Double(dem.psinder) / Double(total)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Acceso a salud")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                Text("INEGI 2020")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color("TextMuted").opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 24) {
                ZStack {
                    Chart {
                        SectorMark(angle: .value("Sin", pctSinSeguro), innerRadius: .ratio(0.6))
                            .foregroundStyle(Color(hex: "#dc2626").opacity(0.8))
                        SectorMark(angle: .value("Con", 1 - pctSinSeguro), innerRadius: .ratio(0.6))
                            .foregroundStyle(Color(hex: "#16a34a").opacity(0.8))
                    }
                    .frame(width: 120, height: 120)

                    VStack(spacing: 2) {
                        Text("\(Int(pctSinSeguro * 100))%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#dc2626"))
                        Text("sin\nseguro")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color("TextMuted"))
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    statRow(valor: dem.psinder, label: "Sin seguro médico", color: Color(hex: "#dc2626"))
                    statRow(valor: dem.pderSS,  label: "Con seguridad social", color: Color(hex: "#16a34a"))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Spacer().frame(height: 4)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statRow(valor: Int, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(valor.formatted())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color("TextMuted"))
            }
        }
    }
}

private struct SegmentosLista: View {
    let colonias: [ColoniaAlcance]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(colonias) { col in
                HStack {
                    Text(col.nombre)
                        .font(.body.weight(.medium))
                    Spacer()
                    HStack(spacing: 10) {
                        dot(col.pob0a14, color: Color(hex: "#f59e0b"))
                        dot(max(col.pob15a64 - col.p60ymas, 0), color: Color("Navy"))
                        dot(col.p60ymas, color: Color(hex: "#16a34a"))
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Segmentos por colonia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }

    private func dot(_ valor: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(valor.formatted())
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}
