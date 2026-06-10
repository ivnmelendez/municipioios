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
                            .foregroundStyle(Color("MunicipioCyan"))
                    }
                }
            }

            HStack(spacing: 8) {
                if let tipo = dano.tipoDano {
                    Label(tipo.label, systemImage: tipoDanoIcon(tipo))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tipoDanoColor(tipo))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tipoDanoColor(tipo).opacity(0.12), in: Capsule())
                }

                if let estado = dano.estructuras?.estado {
                    let resuelta = estado == .activa
                    Label(resuelta ? "Resuelta" : "Pendiente", systemImage: resuelta ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(resuelta ? Color(hex: "#16a34a") : Color(hex: "#dc2626"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((resuelta ? Color(hex: "#16a34a") : Color(hex: "#dc2626")).opacity(0.12), in: Capsule())
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

    private func tipoDanoIcon(_ tipo: TipoDano) -> String {
        switch tipo {
        case .coroplast_roto: "exclamationmark.triangle.fill"
        case .sin_coroplast: "minus.square.fill"
        case .destruida: "xmark.octagon.fill"
        }
    }

    private func tipoDanoColor(_ tipo: TipoDano) -> Color {
        switch tipo {
        case .coroplast_roto: Color(hex: "#f59e0b")
        case .sin_coroplast: Color(hex: "#f59e0b")
        case .destruida: Color(hex: "#dc2626")
        }
    }
}
