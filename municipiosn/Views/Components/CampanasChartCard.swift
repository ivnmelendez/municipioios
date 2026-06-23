import SwiftUI

struct CampanasChartCard: View {
    let datos: [UsoCampana]
    @State private var mostrarTodo = false
    @State private var campanaImagen: UsoCampana? = nil
    @State private var animado = false

    private var top5: [UsoCampana] { Array(datos.prefix(5)) }

    var body: some View {
        Button { mostrarTodo = true } label: {
            VStack(spacing: 0) {
                HStack {
                    Text("Campañas en uso")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    Text("Top 5")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("Navy").opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("Navy").opacity(0.07), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if top5.isEmpty {
                    Text("Sin campañas activas")
                        .font(.body)
                        .foregroundStyle(Color("TextMuted"))
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                } else {
                    let maxVal = top5.first?.totalEstructuras ?? 1
                    ForEach(Array(top5.enumerated()), id: \.element.id) { index, item in
                        fila(item: item, max: maxVal, posicion: index + 1)
                        if item.id != top5.last?.id {
                            Divider().padding(.leading, 20)
                        }
                    }
                    Spacer().frame(height: 8)
                }
            }
        }
        .buttonStyle(.plain)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.05).delay(0.3)) { animado = true }
        }
        .sheet(isPresented: $mostrarTodo) {
            CampanasListaCompleta(datos: datos)
        }
        .sheet(item: $campanaImagen) { campana in
            if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                FotoFullscreenView(url: url, titulo: campana.nombre)
            }
        }
    }

    private func fila(item: UsoCampana, max: Int, posicion: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(posicion)")
                .font(.caption.weight(.bold))
                .foregroundStyle(posicion == 1 ? Color(hex: "#f59e0b") : Color("TextMuted").opacity(0.5))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.nombre)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.totalEstructuras)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color("Navy"))
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("Navy").opacity(0.08))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    posicion == 1
                                    ? LinearGradient(colors: [Color("Navy"), Color("Navy").opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color("Navy").opacity(0.6), Color("Navy").opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: animado ? geo.size.width * (Double(item.totalEstructuras) / Double(max)) : 0)
                        }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onLongPressGesture {
            guard item.fotoUrl != nil else { return }
            HapticService.impacto(.medium)
            campanaImagen = item
        }
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
                    HStack {
                        Text(item.nombre)
                            .font(.body)
                        Spacer()
                        Text("\(item.totalEstructuras) estructuras")
                            .font(.subheadline.weight(.semibold))
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
                if let urlStr = campana.fotoUrl, let url = URL(string: urlStr) {
                    FotoFullscreenView(url: url, titulo: campana.nombre)
                }
            }
        }
    }
}
