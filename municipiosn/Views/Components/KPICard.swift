import SwiftUI

struct KPICard: View {
    let titulo: String
    let valor: Int
    let icono: String
    let color: Color
    var subtitulo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icono)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            Text("\(valor)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())

            Text(titulo)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("TextPrimary"))

            if let subtitulo {
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct KPICardPrincipal: View {
    let titulo: String
    let valor: Int
    let icono: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icono)
                    .font(.title2)
                    .foregroundStyle(.white)
                Spacer()
            }

            Text("\(valor)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(titulo)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(20)
        .background(Color("Navy"), in: RoundedRectangle(cornerRadius: 18))
    }
}
