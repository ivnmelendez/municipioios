import SwiftUI

struct DashboardView: View {
    @State private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.isLoading && !vm.kpi.isLoaded {
                    ProgressView("Cargando KPIs…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 16) {
                        // Total principal
                        KPICardPrincipal(
                            titulo: "Total de estructuras",
                            valor: vm.kpi.totalEstructuras,
                            icono: "square.stack.fill"
                        )
                        .padding(.horizontal, 16)

                        // Grid estados
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            KPICard(
                                titulo: "Activas",
                                valor: vm.kpi.activas,
                                icono: "checkmark.circle.fill",
                                color: Color(hex: "#16a34a")
                            )
                            KPICard(
                                titulo: "Dañadas",
                                valor: vm.kpi.dañadas,
                                icono: "exclamationmark.triangle.fill",
                                color: Color(hex: "#dc2626")
                            )
                            KPICard(
                                titulo: "En reparación",
                                valor: vm.kpi.enReparacion,
                                icono: "wrench.and.screwdriver.fill",
                                color: Color(hex: "#d97706")
                            )
                            KPICard(
                                titulo: "Inactivas",
                                valor: vm.kpi.inactivas,
                                icono: "xmark.circle.fill",
                                color: Color(hex: "#94a3b8")
                            )
                        }
                        .padding(.horizontal, 16)

                        // Segunda fila
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            KPICard(
                                titulo: "Campañas activas",
                                valor: vm.kpi.campanasActivas,
                                icono: "megaphone.fill",
                                color: Color("MunicipioCyan")
                            )
                            KPICard(
                                titulo: "Cambios de rotoplas",
                                valor: vm.kpi.cambiosRotoplasEsteMes,
                                icono: "arrow.triangle.2.circlepath",
                                color: Color("Navy"),
                                subtitulo: "Este mes"
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }

                if let error = vm.errorMessage {
                    ContentUnavailableView(
                        "Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.top, 60)
                }
            }
            .background(Color("Background"))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.cargar() }
            .task { await vm.cargar() }
        }
    }
}
