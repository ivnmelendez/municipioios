import SwiftUI

struct DañosView: View {
    @State private var vm = DañosViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.danos.isEmpty {
                ProgressView("Cargando daños…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.danos.isEmpty {
                ContentUnavailableView(
                    "Sin daños reportados",
                    systemImage: "checkmark.shield.fill",
                    description: Text("No hay reportes de daño en el período seleccionado.")
                )
            } else {
                List(vm.danos) { dano in
                    DanoRow(dano: dano)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .scrollTransition(.animated.threshold(.visible(0.1))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .offset(y: phase.isIdentity ? 0 : 8)
                        }
                }
                .listStyle(.plain)
            }
        }
        .background(Color("Background"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FiltroMenu(filtroActual: vm.filtro) { f in
                    Task { await vm.aplicarFiltro(f) }
                }
            }
        }
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
    }
}

private struct DanoRow: View {
    let dano: IntervencionCompleta

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dano.estructuras?.numero ?? "—")
                        .font(.headline)
                        .foregroundStyle(Color("Navy"))
                    if let parque = dano.estructuras?.parques?.nombre {
                        Text(parque)
                            .font(.caption)
                            .foregroundStyle(Color("TextMuted"))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dano.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("TextMuted"))
                    if let nombre = dano.rondines?.perfiles?.nombre {
                        Text(nombre)
                            .font(.caption2)
                            .foregroundStyle(Color("Navy"))
                    }
                }
            }

            HStack(spacing: 8) {
                tipoBadge(dano.tipoDano)

                if let estado = dano.estructuras?.estado {
                    let resuelta = estado == .activa
                    Label(
                        resuelta ? "Resuelta" : "Pendiente",
                        systemImage: resuelta ? "checkmark.circle.fill" : "clock.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(resuelta ? Color(hex: "#16a34a") : Color(hex: "#dc2626"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (resuelta ? Color(hex: "#16a34a") : Color(hex: "#dc2626")).opacity(0.12),
                        in: Capsule()
                    )
                }
            }

            if let foto = dano.fotoAntesUrl {
                FotoAsyncImage(url: foto, aspectRatio: 16/9, cornerRadius: 10)
            }

            if let notas = dano.notas, !notas.isEmpty {
                Text(notas)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func tipoBadge(_ tipo: TipoDano?) -> some View {
        let (label, icono, color): (String, String, Color) = {
            switch tipo {
            case .coroplast_roto:
                return ("Coroplast roto", "exclamationmark.triangle.fill", Color(hex: "#f59e0b"))
            case .sin_coroplast:
                return ("Sin coroplast", "minus.square.fill", Color(hex: "#f59e0b"))
            case .destruida:
                return ("Destruida", "xmark.octagon.fill", Color(hex: "#dc2626"))
            case nil:
                return ("Daño estructural", "wrench.and.screwdriver.fill", Color(hex: "#dc2626"))
            }
        }()

        Label(label, systemImage: icono)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
