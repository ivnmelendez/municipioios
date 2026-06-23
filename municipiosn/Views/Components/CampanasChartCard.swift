import SwiftUI

struct CampanasChartCard: View {
    let datos: [UsoCampana]
    @State private var mostrarTodo = false
    @State private var campanaImagen: UsoCampana? = nil

    private var top: [UsoCampana] { Array(datos.prefix(5)) }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Campañas en uso", systemImage: "megaphone.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Navy"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("Navy").opacity(0.4))
                }

                if top.isEmpty {
                    Text("Sin campañas activas")
                        .font(.body)
                        .foregroundStyle(Color("TextMuted"))
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color("TextMuted"))
                                    .frame(width: 20, alignment: .center)
                                Text(item.nombre)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.totalCaras) caras")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color("Navy"))
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                            .onLongPressGesture {
                                guard item.fotoUrl != nil else { return }
                                HapticService.impacto(.medium)
                                campanaImagen = item
                            }
                            if index < top.count - 1 {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .buttonStyle(.plain)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(isPresented: $mostrarTodo) {
            CampanasListaCompleta(datos: datos)
        }
        .sheet(item: $campanaImagen) { campana in
            CampanaImagenSheet(campana: campana)
        }
    }
}

// MARK: - Imagen sheet

private struct CampanaImagenSheet: View {
    let campana: UsoCampana

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 480)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                    case .failure:
                        Image(systemName: "photo.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.4))
                    default:
                        ProgressView().tint(.white)
                    }
                }
            }
        }
        .presentationBackground(Color.black)
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

// MARK: - Lista completa

private struct CampanasListaCompleta: View {
    let datos: [UsoCampana]
    @Environment(\.dismiss) private var dismiss
    @State private var busqueda = ""
    @State private var campanaImagen: UsoCampana? = nil

    private var filtrados: [UsoCampana] {
        busqueda.isEmpty ? datos : datos.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(filtrados.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color("TextMuted"))
                            .frame(width: 28, alignment: .center)
                        Text(item.nombre)
                            .font(.body)
                        Spacer()
                        Text("\(item.totalCaras) caras")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color("Navy"))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                    .onLongPressGesture {
                        guard item.fotoUrl != nil else { return }
                        HapticService.impacto(.medium)
                        campanaImagen = item
                    }
                }
            }
            .searchable(text: $busqueda, prompt: "Buscar campaña")
            .navigationTitle("Campañas en uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(item: $campanaImagen) { campana in
                CampanaImagenSheet(campana: campana)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
