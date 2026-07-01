import SwiftUI

struct CampoAdminView: View {
    @Binding var badge: Int
    @State private var seccion: Seccion = .visitas
    @State private var resumen = CampoAdminViewModel()
    @State private var reporteTexto: String? = nil
    @State private var generandoReporte = false
    @State private var periodo: FiltroFecha = .semana
    @State private var mostrarPickerMes = false
    @State private var fechaPickerMes = Date()

    enum Seccion: String, CaseIterable {
        case visitas   = "Visitas"
        case coroplast = "Coroplast"

        var icono: String {
            switch self {
            case .visitas:   "checkmark.circle.fill"
            case .coroplast: "arrow.2.squarepath"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

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
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // MARK: Tab chips
                tabChips
                    .padding(.bottom, 12)

                // MARK: Contenido
                ZStack {
                    HistorialCampoView(periodo: periodo)
                        .opacity(seccion == .visitas   ? 1 : 0)
                        .allowsHitTesting(seccion == .visitas)
                    IntervencionesView(periodo: periodo)
                        .opacity(seccion == .coroplast ? 1 : 0)
                        .allowsHitTesting(seccion == .coroplast)
                }
                .animation(.easeInOut(duration: 0.2), value: seccion)
            }
            .background(Color("Background"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { periodo = .semana } label: {
                            Label("Esta semana", systemImage: periodo == .semana ? "checkmark" : "")
                        }
                        Button { periodo = .mes } label: {
                            Label("Este mes", systemImage: periodo == .mes ? "checkmark" : "")
                        }
                        Button { mostrarPickerMes = true } label: {
                            Label(mesElegidoLabel, systemImage: "calendar")
                        }
                    } label: {
                        Label(periodoLabel, systemImage: "line.3.horizontal.decrease.circle")
                            .symbolVariant(
                                { if case .mesElegido = periodo { return true }; return false }()
                                ? .fill : .none
                            )
                            .foregroundStyle(Color("Navy"))
                    }
                }
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
        .sheet(isPresented: $mostrarPickerMes) {
            NavigationStack {
                DatePicker(
                    "",
                    selection: $fechaPickerMes,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color("Navy"))
                .padding(.horizontal)
                .navigationTitle("Elegir mes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { mostrarPickerMes = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") {
                            periodo = .mesElegido(fechaPickerMes)
                            mostrarPickerMes = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
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
        .onChange(of: seccion) { _, _ in HapticService.seleccion() }
        .onReceive(NotificationCenter.default.publisher(for: .mostrarSeccionVisitas)) { _ in
            seccion = .visitas
        }
        .task { await resumen.cargar() }
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

    private var periodoLabel: String {
        switch periodo {
        case .semana:        return "Esta semana"
        case .mes:           return "Este mes"
        case .mesElegido:    return mesElegidoLabel
        case .todo:          return "Todo"
        }
    }

    private var mesElegidoLabel: String {
        if case .mesElegido(let d) = periodo {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM yyyy"
            fmt.locale = Locale(identifier: "es_MX")
            return fmt.string(from: d).capitalized
        }
        return "Elegir mes"
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
