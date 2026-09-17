import SwiftUI

struct CampoAvisosListView: View {
    let avisos: [EstructuraConParque]
    let userId: UUID?

    var body: some View {
        List {
            if avisos.isEmpty {
                ContentUnavailableView(
                    "Sin avisos pendientes",
                    systemImage: "checkmark.circle",
                    description: Text("No hay estructuras con avisos de coroplast activos.")
                )
            } else {
                ForEach(avisos) { e in
                    NavigationLink(value: e) {
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
            }
        }
        .navigationTitle("Reportes a atender")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: EstructuraConParque.self) { e in
            CampoEstructuraDetalleView(
                estructura: e,
                userId: userId,
                campanas: [],
                rutaSemanaId: nil,
                yaVisitada: false,
                requiereFoto: false
            )
        }
    }
}
