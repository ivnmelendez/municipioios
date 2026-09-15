import SwiftUI

struct CampanasChartCard: View {
    let datos: [UsoCampana]
    var onVerTodas: (() -> Void)? = nil
    @State private var campanaImagen: UsoCampana? = nil
    @State private var animado = false

    private var top5: [UsoCampana] { Array(datos.prefix(5)) }

    var body: some View {
        Button { onVerTodas?() } label: {
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
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.05).delay(0.3)) { animado = true }
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
                                    ? LinearGradient(colors: [Color("Azul"), Color("Azul").opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color("Azul").opacity(0.6), Color("Azul").opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: animado ? geo.size.width * (Double(item.totalEstructuras) / Double(max)) : 0)
                                .animation(.spring(duration: 0.8, bounce: 0.05), value: animado)
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

// MARK: - Lista completa (push view)

struct CampanasListaCompleta: View {
    let datos: [UsoCampana]
    @State private var busqueda = ""
    @State private var categoriaSeleccionada: String? = nil
    @State private var fotoFullscreen: (url: URL, titulo: String)? = nil
    @FocusState private var searchFocused: Bool
    @State private var appeared = false
    @State private var listKey = UUID()
    @State private var animationTask: Task<Void, Never>?

    private var categorias: [String] {
        Array(Set(datos.compactMap(\.categoria))).sorted()
    }

    private var filtrados: [UsoCampana] {
        datos.filter { item in
            let coincideBusqueda = busqueda.isEmpty || item.nombre.localizedCaseInsensitiveContains(busqueda)
            let coincideCategoria = categoriaSeleccionada == nil || item.categoria == categoriaSeleccionada
            return coincideBusqueda && coincideCategoria
        }
    }

    private func triggerAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            appeared = false
            listKey = UUID()
            appeared = true
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button { searchFocused = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 15, weight: .medium))
                        TextField("Buscar campaña", text: $busqueda)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .focused($searchFocused)
                            .onSubmit { searchFocused = false }
                        if !busqueda.isEmpty {
                            Button { busqueda = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                if !categorias.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FiltroChip(label: "Todas", seleccionado: categoriaSeleccionada == nil) {
                                withAnimation(.easeInOut(duration: 0.2)) { categoriaSeleccionada = nil }
                            }
                            ForEach(categorias, id: \.self) { cat in
                                FiltroChip(label: cat.capitalized, seleccionado: categoriaSeleccionada == cat) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        categoriaSeleccionada = categoriaSeleccionada == cat ? nil : cat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                    }
                    .scrollClipDisabled()
                }

                if !datos.isEmpty {
                    HStack {
                        let isFiltered = categoriaSeleccionada != nil || !busqueda.isEmpty
                        Text(isFiltered
                             ? "\(filtrados.count) resultado\(filtrados.count == 1 ? "" : "s")"
                             : "\(datos.count) campaña\(datos.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color("TextMuted"))
                            .contentTransition(.numericText())
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                LazyVStack(spacing: 0) {
                    ForEach(Array(filtrados.enumerated()), id: \.element.id) { index, item in
                        CampanaListaRow(item: item, posicion: index + 1) { url in
                            fotoFullscreen = (url, item.nombre)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(
                            .spring(duration: 0.4, bounce: 0.08).delay(Double(min(index, 14)) * 0.035),
                            value: appeared
                        )
                        Divider().padding(.leading, 76)
                    }
                }
                .padding(.horizontal, 20)
                .id(listKey)
                .onAppear { appeared = true }
                .onChange(of: categoriaSeleccionada) { _, _ in triggerAnimation() }
                .onChange(of: busqueda) { _, _ in triggerAnimation() }
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(Color("Background"))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: Binding(
            get: { fotoFullscreen.map { IdentifiableFoto(url: $0.url, titulo: $0.titulo) } },
            set: { if $0 == nil { fotoFullscreen = nil } }
        )) { item in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
        }
    }
}

private struct IdentifiableFoto: Identifiable {
    let id = UUID()
    let url: URL
    let titulo: String
}

private struct CampanaListaRow: View {
    let item: UsoCampana
    let posicion: Int
    let onTapFoto: (URL) -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            if let urlStr = item.fotoUrl, let url = URL(string: urlStr) {
                Button { onTapFoto(url) } label: {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: "megaphone.fill")
                                        .foregroundStyle(Color("Navy").opacity(0.3))
                                }
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "megaphone.fill")
                            .foregroundStyle(Color("Navy").opacity(0.25))
                    }
            }

            Text(item.nombre)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct FiltroChip: View {
    let label: String
    let seleccionado: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(seleccionado ? .white : Color("Navy"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(seleccionado ? Color("Azul") : Color("Navy").opacity(0.07), in: Capsule())
                .shadow(color: seleccionado ? Color("Azul").opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
                .scaleEffect(seleccionado ? 1.04 : 1.0)
                .animation(.spring(duration: 0.3, bounce: 0.35), value: seleccionado)
        }
        .buttonStyle(.plain)
    }
}
