import SwiftUI

struct CampoAdminView: View {
    @Binding var badge: Int
    @State private var seccion: Seccion = .visitas
    @State private var resumen = CampoAdminViewModel()

    enum Seccion: String, CaseIterable {
        case visitas    = "Visitas"
        case coroplast  = "Coroplast"
        case danos      = "Daños"

        var icono: String {
            switch self {
            case .visitas:   "checkmark.circle.fill"
            case .coroplast: "arrow.2.squarepath"
            case .danos:     "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                resumenBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                Divider()

                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()

                ZStack {
                    if seccion == .visitas    { HistorialCampoView().transition(.opacity) }
                    if seccion == .coroplast  { IntervencionesView().transition(.opacity) }
                    if seccion == .danos      { DañosView().transition(.opacity) }
                }
                .animation(.easeInOut(duration: 0.2), value: seccion)
            }
            .background(Color("Background"))
            .navigationTitle("Campo")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: seccion) { _, new in
            if new == .coroplast { badge = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in
            seccion = .visitas
        }
        .task { await resumen.cargar() }
    }

    // MARK: - Stats bar

    private var resumenBar: some View {
        HStack(spacing: 10) {
            statPill(
                valor: resumen.cargado ? "\(resumen.visitas)" : "—",
                label: "visitas",
                icono: "checkmark.circle.fill",
                color: Color(hex: "#16a34a")
            )
            statPill(
                valor: resumen.cargado ? "\(resumen.cambios)" : "—",
                label: "coroplast",
                icono: "arrow.2.squarepath",
                color: Color("Navy")
            )
            statPill(
                valor: resumen.cargado ? "\(resumen.danos)" : "—",
                label: "daños",
                icono: "exclamationmark.triangle.fill",
                color: resumen.danos > 0 ? Color(hex: "#dc2626") : Color("TextMuted")
            )
        }
    }

    private func statPill(valor: String, label: String, icono: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icono)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Text(valor)
                    .font(.headline.bold())
                    .foregroundStyle(Color("Navy"))
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(Seccion.allCases, id: \.self) { s in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { seccion = s }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: s.icono)
                            .font(.subheadline.weight(.medium))
                        Text(s.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(seccion == s ? .white : Color("Navy"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        seccion == s ? Color("Navy") : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
