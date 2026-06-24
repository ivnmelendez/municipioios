import SwiftUI

struct PagosGastosCard: View {
    let vm: PagosViewModel
    @State private var mostrarPagos = false

    private var totalMesFormateado: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return "$\(fmt.string(from: NSNumber(value: vm.totalMes)) ?? "0.00")"
    }

    private var ultimoPago: PagoManoObra? { vm.pagos.first }

    var body: some View {
        Button { mostrarPagos = true } label: {
            VStack(spacing: 0) {
                HStack {
                    Text("Mano de obra")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextMuted"))
                    Spacer()
                    Text("Este mes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("Navy").opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("Navy").opacity(0.07), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider().padding(.horizontal, 20)

                VStack(spacing: 6) {
                    Text(totalMesFormateado)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("Navy"))
                        .contentTransition(.numericText())
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("total pagado")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("TextMuted"))
                }
                .padding(.top, 20)
                .padding(.bottom, ultimoPago != nil ? 16 : 20)

                if let pago = ultimoPago {
                    Divider().padding(.horizontal, 20)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Último pago")
                                .font(.caption)
                                .foregroundStyle(Color("TextMuted"))
                            Text(pago.trabajador)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(pago.montoDisplay)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("Navy"))
                                .monospacedDigit()
                            Text(pago.fechaDisplay)
                                .font(.caption)
                                .foregroundStyle(Color("TextMuted"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .sheet(isPresented: $mostrarPagos) {
            NavigationStack {
                PagosView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { mostrarPagos = false }
                                .foregroundStyle(Color("Navy"))
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
    }
}
