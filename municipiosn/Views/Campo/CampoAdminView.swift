import SwiftUI

struct CampoAdminView: View {
    @Binding var badge: Int
    @State private var seccion: Seccion = .visitas
    @State private var resumen = CampoAdminViewModel()
    @State private var reporteTexto: String? = nil
    @State private var generandoReporte = false

    enum Seccion: String, CaseIterable {
        case visitas   = "Visitas"
        case coroplast = "Coroplast"
        case danos     = "Daños"

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

                // MARK: Stats
                statsBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // MARK: Pagos card
                NavigationLink(destination: PagosView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "banknote.fill")
                            .font(.title2)
                            .foregroundStyle(Color("Navy"))
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pagos de mano de obra")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Historial y registro de pagos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // MARK: Tab chips
                tabChips
                    .padding(.bottom, 12)

                // MARK: Contenido
                ZStack {
                    if seccion == .visitas   { HistorialCampoView().transition(.opacity) }
                    if seccion == .coroplast { IntervencionesView().transition(.opacity) }
                    if seccion == .danos     { DañosView().transition(.opacity) }
                }
                .animation(.easeInOut(duration: 0.2), value: seccion)
            }
            .background(Color("Background"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Stats bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCol(
                valor: resumen.cargado ? "\(resumen.visitas)" : "—",
                label: "Visitas",
                icono: "checkmark.circle.fill",
                color: Color(hex: "#16a34a"),
                borde: true
            )
            statCol(
                valor: resumen.cargado ? "\(resumen.cambios)" : "—",
                label: "Coroplast",
                icono: "arrow.2.squarepath",
                color: Color("Navy"),
                borde: true
            )
            statCol(
                valor: resumen.cargado ? "\(resumen.danos)" : "—",
                label: "Daños",
                icono: "exclamationmark.triangle.fill",
                color: resumen.danos > 0 ? Color(hex: "#dc2626") : Color("TextMuted"),
                borde: false
            )
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statCol(valor: String, label: String, icono: String, color: Color, borde: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
            Text(valor)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Navy"))
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("TextMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .overlay(alignment: .trailing) {
            if borde {
                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 1)
            }
        }
    }

    // MARK: - Tab chips

    private var tabChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Seccion.allCases, id: \.self) { s in
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) { seccion = s }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: s.icono)
                                .font(.subheadline.weight(.medium))
                            Text(s.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(seccion == s ? .white : Color("Navy"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            seccion == s ? Color("Navy") : Color("Navy").opacity(0.08),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
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
}
