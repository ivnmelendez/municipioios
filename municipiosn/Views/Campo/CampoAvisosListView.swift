import SwiftUI

struct CampoAvisosListView: View {
    let avisos: [EstructuraConParque]

    var sinCoroplast: [EstructuraConParque] { avisos.filter { $0.coroplastEstado == "sin_coroplast" } }
    var coroplastRoto: [EstructuraConParque] { avisos.filter { $0.coroplastEstado == "coroplast_roto" } }

    var body: some View {
        List {
            if !sinCoroplast.isEmpty {
                Section {
                    ForEach(sinCoroplast) { e in fila(e) }
                } header: {
                    Label("Sin coroplast", systemImage: "square.slash.fill")
                        .foregroundStyle(Color(hex: "#ea580c"))
                }
            }
            if !coroplastRoto.isEmpty {
                Section {
                    ForEach(coroplastRoto) { e in fila(e) }
                } header: {
                    Label("Dañado", systemImage: "exclamationmark.square.fill")
                        .foregroundStyle(Color(hex: "#d97706"))
                }
            }
            if avisos.isEmpty {
                ContentUnavailableView(
                    "Sin avisos pendientes",
                    systemImage: "checkmark.circle",
                    description: Text("No hay estructuras con avisos de coroplast activos.")
                )
            }
        }
        .navigationTitle("Reportes a atender")
        .navigationBarTitleDisplayMode(.large)
    }

    private func fila(_ e: EstructuraConParque) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Estructura \(e.numero)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("Navy"))
            if let parque = e.parques?.nombre {
                Text(parque)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
        }
        .padding(.vertical, 2)
    }
}
