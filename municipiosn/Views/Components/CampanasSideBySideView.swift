import SwiftUI

struct CampanasSideBySideView: View {
    let caras: [CaraDetalle]
    var onTapFoto: ((URL, String) -> Void)? = nil
    var onCambiarCampana: ((CaraDetalle) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassEffectContainer(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(caras.sorted(by: { $0.tipo < $1.tipo })) { cara in
                        CampanaCelda(
                            cara: cara,
                            onTapFoto: { url in
                                onTapFoto?(url, "Campaña Cara \(cara.tipo)")
                            },
                            onCambiarCampana: onCambiarCampana != nil ? { onCambiarCampana?(cara) } : nil
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct CampanaCelda: View {
    let cara: CaraDetalle
    var onTapFoto: ((URL) -> Void)? = nil
    var onCambiarCampana: (() -> Void)? = nil

    var fotoURL: URL? {
        if let s = cara.fotoCampana ?? cara.campana?.fotoUrl { return URL(string: s) }
        return nil
    }

    var body: some View {
        Button {
            if let url = fotoURL { onTapFoto?(url) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                imageArea
                    .overlay(alignment: .topLeading) {
                        Text(cara.tipo)
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color("Navy"), in: Circle())
                            .padding(8)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    if let campana = cara.campana {
                        Text(campana.nombre)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    } else {
                        Text("Sin campaña")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
        .frame(maxWidth: .infinity)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if let cambiar = onCambiarCampana {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        cambiar()
                    }
                }
        )
    }

    @ViewBuilder
    private var imageArea: some View {
        if let url = fotoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 100)
                case .failure:
                    placeholderImage
                default:
                    placeholderImage.overlay { ProgressView().tint(Color("Navy")) }
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Color.secondary.opacity(0.08)
            .aspectRatio(1.5, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }
}
