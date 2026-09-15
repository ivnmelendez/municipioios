import SwiftUI

struct CoberturaFaltantesView: View {
    let cobertura: CoberturaMensual

    @State private var faltantes: [EstructuraConParque] = []
    @State private var cargando = false
    @State private var errorMsg: String? = nil

    private var titulo: String {
        let mes = CoberturaNotificacionService.nombreDelMes(cobertura.mes)
        return "\(mes) \(cobertura.año)"
    }

    var body: some View {
        Group {
            if cargando {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMsg {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                       description: Text(err))
            } else if faltantes.isEmpty {
                ContentUnavailableView(
                    "¡Todas revisadas!",
                    systemImage: "checkmark.circle.fill",
                    description: Text("El equipo visitó todas las estructuras en \(titulo).")
                )
            } else {
                List {
                    Section {
                        ForEach(faltantes) { e in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e.numero)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("Navy"))
                                if let parque = e.parques {
                                    Text(parque.nombre)
                                        .font(.caption)
                                        .foregroundStyle(Color("TextMuted"))
                                    if let colonia = parque.colonias {
                                        Text(colonia.nombre)
                                            .font(.caption2)
                                            .foregroundStyle(Color("TextMuted").opacity(0.7))
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("\(faltantes.count) sin visitar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    private func cargar() async {
        cargando = true
        defer { cargando = false }
        do {
            faltantes = try await EstructurasService.shared.fetchEstructurasFaltantesEnMes(
                año: cobertura.año,
                mes: cobertura.mes
            )
            .sorted { ($0.parques?.nombre ?? "") < ($1.parques?.nombre ?? "") }
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
