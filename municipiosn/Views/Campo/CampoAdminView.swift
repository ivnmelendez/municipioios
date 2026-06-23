import SwiftUI

struct CampoAdminView: View {
    @Binding var badge: Int
    @State private var seccion: Seccion = .visitas
    @State private var resumen = CampoAdminViewModel()
    @State private var reporteTexto: String? = nil
    @State private var generandoReporte = false

    enum Seccion: String, CaseIterable {
        case visitas    = "Visitas"
        case coroplast  = "Coroplast"
        case danos      = "Daños"
        case pagos      = "Pagos"

        var icono: String {
            switch self {
            case .visitas:   "checkmark.circle.fill"
            case .coroplast: "arrow.2.squarepath"
            case .danos:     "exclamationmark.triangle.fill"
            case .pagos:     "banknote.fill"
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
                    if seccion == .pagos      { PagosView().transition(.opacity) }
                }
                .animation(.easeInOut(duration: 0.2), value: seccion)
            }
            .background(Color("Background"))
            .navigationTitle("Campo")
            .navigationBarTitleDisplayMode(.large)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await generarReporte() }
                } label: {
                    if generandoReporte {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(generandoReporte)
            }
        }
        .sheet(isPresented: Binding(get: { reporteTexto != nil }, set: { if !$0 { reporteTexto = nil } })) {
            if let texto = reporteTexto {
                ShareLink(item: texto) {
                    Label("Compartir reporte", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .presentationDetents([.height(140)])
            }
        }
        .onChange(of: seccion) { _, new in
            if new == .coroplast { badge = 0 }
            HapticService.seleccion()
        }
        .onReceive(NotificationCenter.default.publisher(for: .abrirRondines)) { _ in
            seccion = .visitas
        }
        .task { await resumen.cargar() }
    }

    // MARK: - Reporte

    private func generarReporte() async {
        generandoReporte = true
        defer { generandoReporte = false }

        let (visitas, cambios, danos) = (try? await EstructurasService.shared.fetchResumenMes()) ?? (0, 0, 0)
        let pendientes = (try? await IntervencionesService.shared.fetchDanos(filtro: .mes))?.filter {
            $0.estructuras?.estado == .dañada
        } ?? []

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "MMMM yyyy"
        let mes = fmt.string(from: Date()).capitalized

        let fmtHora = DateFormatter()
        fmtHora.locale = Locale(identifier: "es_MX")
        fmtHora.dateFormat = "d 'de' MMMM 'de' yyyy, h:mm a"

        var lineas = [
            "MUNICIPIO DE SAN NICOLÁS DE LOS GARZA",
            "Reporte de campo — \(mes)",
            "Generado: \(fmtHora.string(from: Date()))",
            "",
            "────────────────────────────────",
            "ACTIVIDAD DEL MES",
            "  • Estructuras revisadas: \(visitas)",
            "  • Coroplast cambiados:   \(cambios)",
            "  • Daños reportados:      \(danos)",
        ]

        if !pendientes.isEmpty {
            lineas += ["", "────────────────────────────────",
                       "ESTRUCTURAS DAÑADAS PENDIENTES (\(pendientes.count))"]
            for d in pendientes {
                let num    = d.estructuras?.numero ?? "—"
                let parque = d.estructuras?.parques?.nombre ?? ""
                let fecha  = d.createdAt.formatted(date: .abbreviated, time: .omitted)
                lineas.append("  • \(num) — \(parque) (\(fecha))")
            }
        }

        lineas += ["", "────────────────────────────────",
                   "San Nicolás de los Garza, NL"]

        reporteTexto = lineas.joined(separator: "\n")
        HapticService.impacto(.light)
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
