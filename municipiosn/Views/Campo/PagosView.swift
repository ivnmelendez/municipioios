import SwiftUI

struct PagosView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = PagosViewModel()
    @State private var mostrarNuevoPago = false

    private var mesActual: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "MMMM yyyy"
        let s = fmt.string(from: Date())
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if vm.isLoading && vm.pagos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.pagos.isEmpty {
                    ContentUnavailableView(
                        "Sin pagos registrados",
                        systemImage: "banknote",
                        description: Text("Toca + para registrar un pago de mano de obra.")
                    )
                } else {
                    List {
                        // Resumen del mes
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total \(mesActual)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color("TextMuted"))
                                    Text(formatMonto(vm.totalMes))
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color("Navy"))
                                        .contentTransition(.numericText())
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)

                            if !vm.trabajadores.isEmpty {
                                ForEach(vm.trabajadores, id: \.self) { trabajador in
                                    let total = vm.totalMesPor(trabajador: trabajador)
                                    if total > 0 {
                                        HStack {
                                            Label(trabajador, systemImage: "person.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text(formatMonto(total))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color("Navy"))
                                        }
                                    }
                                }
                            }
                        }

                        // Historial
                        Section("Historial") {
                            ForEach(vm.pagos) { pago in
                                PagoRow(pago: pago)
                            }
                            .onDelete { indexSet in
                                for i in indexSet {
                                    Task { await vm.eliminar(vm.pagos[i]) }
                                }
                            }
                        }
                    }
                    .refreshable { await vm.cargar() }
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
        .task { await vm.cargar() }
        .sheet(isPresented: $mostrarNuevoPago) {
            NuevoPagoSheet(perfilId: auth.perfilId) { fecha, trabajador, monto, concepto in
                Task { await vm.registrar(fecha: fecha, trabajador: trabajador, monto: monto, concepto: concepto, creadoPor: auth.perfilId ?? UUID()) }
            }
            .presentationDetents([.medium])
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
    @State private var trabajadorSeleccionado = "Don Cruz"
    @State private var trabajadorCustom = ""
    @State private var montoTexto = ""
    @State private var concepto = ""

    private let trabajadoresDefault = ["Don Cruz", "Pepín", "Otro"]

    private var trabajadorFinal: String {
        trabajadorSeleccionado == "Otro" ? trabajadorCustom : trabajadorSeleccionado
    }

    private var montoValido: Double? {
        let limpio = montoTexto.replacingOccurrences(of: ",", with: ".")
        return Double(limpio)
    }

    private var puedeGuardar: Bool {
        montoValido != nil && montoValido! > 0 && !trabajadorFinal.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trabajador") {
                    Picker("Trabajador", selection: $trabajadorSeleccionado) {
                        ForEach(trabajadoresDefault, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)

                    if trabajadorSeleccionado == "Otro" {
                        TextField("Nombre del trabajador", text: $trabajadorCustom)
                    }
                }

                Section("Pago") {
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "es_MX"))

                    HStack {
                        Text("$")
                            .foregroundStyle(Color("TextMuted"))
                        TextField("0.00", text: $montoTexto)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Concepto (opcional)") {
                    TextField("Ej: Rondín del sábado, Coroplast...", text: $concepto)
                }
            }
            .navigationTitle("Registrar pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .tint(Color("TextMuted"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        guard let monto = montoValido else { return }
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyy-MM-dd"
                        onGuardar(fmt.string(from: fecha), trabajadorFinal, monto, concepto.isEmpty ? nil : concepto)
                        HapticService.impacto(.medium)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Color("Navy"))
                    .disabled(!puedeGuardar)
                }
            }
        }
    }
}
