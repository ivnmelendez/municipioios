import SwiftUI

struct PagosView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = PagosViewModel()
    @State private var mostrarNuevoPago = false
    @State private var periodo: Periodo = .mes

    enum Periodo: String, CaseIterable {
        case semana = "Esta semana"
        case mes    = "Este mes"
        case todo   = "Todo"
    }

    private var pagosFiltrados: [PagoManoObra] {
        let cal = Calendar.current
        switch periodo {
        case .semana:
            return vm.pagos.filter { cal.isDate($0.fechaDate, equalTo: Date(), toGranularity: .weekOfYear) }
        case .mes:
            return vm.pagos.filter { cal.isDate($0.fechaDate, equalTo: Date(), toGranularity: .month) }
        case .todo:
            return vm.pagos
        }
    }

    private var totalFiltrado: Double {
        pagosFiltrados.reduce(0) { $0 + $1.monto }
    }

    private var trabajadoresFiltrados: [String] {
        Array(Set(pagosFiltrados.map { $0.trabajador })).sorted()
    }

    private func totalPorTrabajador(_ trabajador: String) -> Double {
        pagosFiltrados.filter { $0.trabajador == trabajador }.reduce(0) { $0 + $1.monto }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if vm.isLoading && vm.pagos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if pagosFiltrados.isEmpty {
                    ContentUnavailableView(
                        "Sin pagos",
                        systemImage: "banknote",
                        description: Text(vm.pagos.isEmpty
                            ? "Toca + para registrar un pago de mano de obra."
                            : "No hay pagos en \(periodo.rawValue.lowercased()).")
                    )
                } else {
                    List {
                        // Resumen del periodo
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total · \(periodo.rawValue)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color("TextMuted"))
                                    Text(formatMonto(totalFiltrado))
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color("Navy"))
                                        .contentTransition(.numericText())
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)

                            ForEach(trabajadoresFiltrados, id: \.self) { trabajador in
                                HStack {
                                    Label(trabajador, systemImage: "person.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(formatMonto(totalPorTrabajador(trabajador)))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color("Navy"))
                                }
                            }
                        }

                        // Historial
                        Section("Historial") {
                            ForEach(pagosFiltrados) { pago in
                                PagoRow(pago: pago)
                            }
                            .onDelete { indexSet in
                                let targets = indexSet.map { pagosFiltrados[$0] }
                                for pago in targets {
                                    Task { await vm.eliminar(pago) }
                                }
                            }
                        }
                    }
                    .refreshable { await vm.cargar() }
                    .animation(.easeInOut(duration: 0.2), value: periodo)
                }
            }

            // FAB
            Button {
                mostrarNuevoPago = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color("Navy"), in: Circle())
                    .shadow(color: Color("Navy").opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(Periodo.allCases, id: \.self) { p in
                        Button {
                            withAnimation { periodo = p }
                        } label: {
                            if periodo == p {
                                Label(p.rawValue, systemImage: "checkmark")
                            } else {
                                Text(p.rawValue)
                            }
                        }
                    }
                } label: {
                    Label(periodo.rawValue, systemImage: "calendar")
                        .symbolVariant(.fill)
                }
                .tint(Color("Navy"))
            }
        }
        .task { await vm.cargar() }
        .sheet(isPresented: $mostrarNuevoPago) {
            NuevoPagoSheet(perfilId: auth.perfilId) { fecha, trabajador, monto, concepto in
                Task { await vm.registrar(fecha: fecha, trabajador: trabajador, monto: monto, concepto: concepto, creadoPor: auth.perfilId ?? UUID()) }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func formatMonto(_ monto: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale(identifier: "es_MX")
        fmt.currencySymbol = "$"
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: monto)) ?? "$\(monto)"
    }
}

// MARK: - Row

private struct PagoRow: View {
    let pago: PagoManoObra

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pago.trabajador)
                        .font(.body.weight(.semibold))
                    if let concepto = pago.concepto, !concepto.isEmpty {
                        Text("·")
                            .foregroundStyle(Color("TextMuted"))
                        Text(concepto)
                            .font(.body)
                            .foregroundStyle(Color("TextMuted"))
                            .lineLimit(1)
                    }
                }
                Text(pago.fechaDisplay)
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
            Spacer()
            Text(pago.montoDisplay)
                .font(.body.weight(.bold))
                .foregroundStyle(Color("Navy"))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Nuevo Pago Sheet

private struct NuevoPagoSheet: View {
    let perfilId: UUID?
    let onGuardar: (String, String, Double, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fecha = Date()
    @State private var trabajadorSeleccionado: String? = nil
    @State private var trabajadorCustom = ""
    @State private var montoTexto = ""
    @State private var concepto = ""
    @State private var exito = false

    private var trabajadorFinal: String {
        trabajadorSeleccionado == "Otro" ? trabajadorCustom : (trabajadorSeleccionado ?? "")
    }

    private var montoValido: Double? {
        let limpio = montoTexto.replacingOccurrences(of: ",", with: ".")
        return Double(limpio)
    }

    private var puedeGuardar: Bool {
        montoValido != nil && montoValido! > 0 &&
        !trabajadorFinal.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Header
                    VStack(spacing: 6) {
                        Text("¿A quién le pagaste?")
                            .font(.title2.bold())
                            .foregroundStyle(Color("Navy"))
                        Text("Selecciona el trabajador")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Opciones de trabajador
                    VStack(spacing: 12) {
                        trabajadorOpcion("Don Cruz", subtitulo: "Trabajador principal")
                        trabajadorOpcion("Pepín", subtitulo: "Trabajador de campo")
                        trabajadorOpcion("Otro", subtitulo: "Agregar otro nombre")

                        if trabajadorSeleccionado == "Otro" {
                            TextField("Nombre del trabajador", text: $trabajadorCustom)
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.2), value: trabajadorSeleccionado)

                    // Monto
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monto pagado")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        HStack(spacing: 8) {
                            Text("$")
                                .font(.title2.bold())
                                .foregroundStyle(Color("Navy"))
                            TextField("0.00", text: $montoTexto)
                                .font(.title2.bold())
                                .keyboardType(.decimalPad)
                                .foregroundStyle(Color("Navy"))
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    // Fecha
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fecha del pago")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        DatePicker("", selection: $fecha, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "es_MX"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    // Concepto
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Concepto (opcional)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        TextField("Ej: Rondín del sábado, cambio de coroplast...",
                                  text: $concepto, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    // Botón guardar
                    Button {
                        guard let monto = montoValido else { return }
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyy-MM-dd"
                        onGuardar(fmt.string(from: fecha), trabajadorFinal, monto,
                                  concepto.isEmpty ? nil : concepto)
                        HapticService.exito()
                        withAnimation { exito = true }
                    } label: {
                        HStack {
                            Image(systemName: "banknote.fill")
                            Text("Guardar pago")
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            puedeGuardar ? Color("Navy") : Color.secondary.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .disabled(!puedeGuardar)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Registrar pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color("Navy"))
                }
            }
            .overlay {
                if exito {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                            Text("Pago registrado")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(40)
                    }
                    .onAppear {
                        HapticService.exito()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                    }
                }
            }
        }
    }

    private func trabajadorOpcion(_ nombre: String, subtitulo: String) -> some View {
        let seleccionado = trabajadorSeleccionado == nombre
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { trabajadorSeleccionado = nombre }
            HapticService.seleccion()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: seleccionado ? "checkmark.circle.fill" : "person.fill")
                    .font(.title2)
                    .foregroundStyle(seleccionado ? .white : Color("Navy"))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(nombre)
                        .font(.headline)
                        .foregroundStyle(seleccionado ? .white : .primary)
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(seleccionado ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
            }
            .padding(18)
            .background(
                seleccionado ? Color("Navy") : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}
