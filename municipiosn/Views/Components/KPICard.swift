import SwiftUI

struct KPICard: View {
    let titulo: String
    let valor: Int
    let icono: String
    let color: Color
    var subtitulo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icono)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.14), in: Circle())

            Spacer(minLength: 0)

            Text("\(valor)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitulo {
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(Color("TextMuted"))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct KPICardPrincipal: View {
    let titulo: String
    let valor: Int
    let icono: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(titulo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextMuted"))

                Text("\(valor)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("Navy"))
                    .contentTransition(.numericText())
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
