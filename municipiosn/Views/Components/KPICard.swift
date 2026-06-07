import SwiftUI

struct KPICard: View {
    let titulo: String
    let valor: Int
    let icono: String
    let color: Color
    var subtitulo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: icono)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(9)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
            }

            Spacer(minLength: 14)

            Text("\(valor)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())

            Text(titulo)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)

            if let subtitulo {
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted").opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct CoberturaColoniasCard: View {
    let conEstructuras: Int
    let sinEstructuras: Int

    private var total: Int { conEstructuras + sinEstructuras }
    private var porcentaje: Double {
        guard total > 0 else { return 0 }
        return Double(conEstructuras) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Navy"))
                Text("Cobertura territorial")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(porcentaje * 100))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("Navy"))
                    .contentTransition(.numericText())
                Text("de colonias cubiertas")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))
                    .padding(.bottom, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color("Navy").opacity(0.08))
                            .frame(width: geo.size.width, height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color("Navy"), Color("MunicipioCyan")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * porcentaje, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Label("\(conEstructuras) con estructuras", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color("Navy"))
                    Spacer()
                    Label("\(sinEstructuras) sin estructuras", systemImage: "circle.dotted")
                        .foregroundStyle(Color("TextMuted"))
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct KPICardPrincipal: View {
    let titulo: String
    let valor: Int
    let icono: String
    var porcentajeOperativas: Double? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))

                Text("\(valor)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("Navy"))
                    .contentTransition(.numericText())

                if let pct = porcentajeOperativas {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "#16a34a"))
                            .frame(width: 6, height: 6)
                        Text("\(Int(pct * 100))% operativas")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color(hex: "#16a34a"))
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            Image(systemName: icono)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color("Navy").opacity(0.12))
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct DashboardSectionHeader: View {
    let titulo: String

    var body: some View {
        Text(titulo.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color("TextMuted"))
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }
}
