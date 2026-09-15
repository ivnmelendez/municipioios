import SwiftUI

struct PagosGastosCard: View {
    let vm: PagosViewModel

    @AppStorage("pagos_monto_oculto") private var montoOculto = false

    private var totalMesFormateado: String {
        if montoOculto { return "••••••" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return "$\(fmt.string(from: NSNumber(value: vm.totalMes)) ?? "0.00")"
    }

    private var ultimoPago: PagoManoObra? { vm.pagos.first }

    var body: some View {
        NavigationLink(destination: PagosView()) {
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
                        .background(Color("TextMuted").opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                VStack(spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(totalMesFormateado)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color("Navy"))
                            .contentTransition(.numericText())
                            .monospacedDigit()
                            .animation(.default, value: montoOculto)

                        Button {
                            montoOculto.toggle()
                        } label: {
                            Image(systemName: montoOculto ? "eye.slash" : "eye")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color("Navy").opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text("total pagado")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("TextMuted"))
                }
                .padding(.top, 20)
                .padding(.bottom, ultimoPago != nil ? 16 : 20)

                if let pago = ultimoPago {
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
                            Text(montoOculto ? "•••••" : pago.montoDisplay)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("Navy"))
                                .monospacedDigit()
                                .animation(.default, value: montoOculto)
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
    }
}
