import SwiftUI

struct CampoAdminView: View {
    @Binding var badge: Int
    @State private var seccion: Seccion = .rondines

    enum Seccion: String, CaseIterable {
        case rondines = "Rondines"
        case intervenciones = "Intervenciones"
        case danos = "Daños"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $seccion) {
                    ForEach(Seccion.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                switch seccion {
                case .rondines:
                    HistorialCampoView()
                case .intervenciones:
                    IntervencionesView()
                case .danos:
                    DañosView()
                }
            }
            .navigationTitle("Campo")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: seccion) { _, new in
            if new == .intervenciones { badge = 0 }
        }
    }
}
