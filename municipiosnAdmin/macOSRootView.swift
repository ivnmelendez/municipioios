import SwiftUI

enum AdminTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case mapa      = "Mapa"
    case estructuras = "Estructuras"
    case campo     = "Campo"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:   "house.fill"
        case .mapa:        "map.fill"
        case .estructuras: "square.stack.fill"
        case .campo:       "person.2.fill"
        }
    }
}

struct macOSRootView: View {
    let authVM: AuthViewModel
    @State private var seleccion: AdminTab = .dashboard
    @State private var campoBadge = 0

    var body: some View {
        NavigationSplitView {
            List(AdminTab.allCases, selection: $seleccion) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
                    .badge(tab == .campo && campoBadge > 0 ? campoBadge : 0)
            }
            .navigationTitle("Municipio SN")
            .listStyle(.sidebar)

            Divider()

            Button(role: .destructive) {
                Task { await authVM.signOut() }
            } label: {
                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } detail: {
            switch seleccion {
            case .dashboard:
                DashboardView()
                    .environment(authVM)
            case .mapa:
                MapaView()
                    .environment(authVM)
            case .estructuras:
                NavigationStack {
                    EstructurasListView()
                        .navigationDestination(for: EstructuraConParque.self) { e in
                            EstructuraDetalleView(estructura: e)
                        }
                }
                .environment(authVM)
            case .campo:
                CampoAdminView(badge: $campoBadge)
                    .environment(authVM)
            }
        }
        .environment(authVM)
        .onReceive(NotificationCenter.default.publisher(for: .nuevoCambioRotoplas)) { _ in
            campoBadge += 1
        }
    }
}
