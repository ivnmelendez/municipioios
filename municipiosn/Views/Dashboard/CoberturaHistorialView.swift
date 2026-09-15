import SwiftUI

struct CoberturaHistorialView: View {
    @State private var añoSeleccionado: Int
    @State private var datos: [CoberturaMensual] = []
    @State private var cargando = false
    @State private var errorMsg: String? = nil
    @State private var mesDrilldown: CoberturaMensual? = nil

    private static let añoInicio = 2026
    private static let mesInicio = 6  // junio 2026

    private let años: [Int]

    init() {
        let añoActual = Calendar.current.component(.year, from: Date())
        años = Array(Self.añoInicio...añoActual)
        _añoSeleccionado = State(initialValue: añoActual)
    }

    private var mesInicioParaAño: Int {
        añoSeleccionado == Self.añoInicio ? Self.mesInicio : 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if años.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(años.reversed(), id: \.self) { año in
                                Button {
                                    guard año != añoSeleccionado else { return }
                                    añoSeleccionado = año
                                    Task { await cargar() }
                                } label: {
                                    Text(String(año))
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(
                                            año == añoSeleccionado
                                                ? Color("Azul")
                                                : Color("TextMuted").opacity(0.12),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(año == añoSeleccionado ? .white : Color("Navy"))
                                        .animation(.easeInOut(duration: 0.18), value: añoSeleccionado)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                if cargando {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else if let err = errorMsg {
                    ContentUnavailableView(
                        "Error al cargar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(err)
                    )
                    .padding(.top, 16)
                } else if datos.isEmpty {
                    ContentUnavailableView(
                        "Sin registros",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No hay registros de campo para \(String(añoSeleccionado)).")
                    )
                    .padding(.top, 16)
                } else {
                    mesesList
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color("Background"))
        .navigationTitle("Historial de cobertura")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $mesDrilldown) { mes in
            CoberturaFaltantesView(cobertura: mes)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(años.reversed(), id: \.self) { año in
                        Button {
                            guard año != añoSeleccionado else { return }
                            añoSeleccionado = año
                            Task { await cargar() }
                        } label: {
                            Label(String(año), systemImage: añoSeleccionado == año ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(String(añoSeleccionado), systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await cargar() }
    }

    private var mesesList: some View {
        let ordenados = Array(datos.reversed())
        return VStack(spacing: 0) {
            ForEach(ordenados) { mes in
                MesCoberturaRow(mes: mes) { mesDrilldown = mes }
                if mes.id != ordenados.last?.id {
                    Divider().padding(.leading, 20)
                }
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func cargar() async {
        cargando = true
        errorMsg = nil
        defer { cargando = false }
        do {
            datos = try await EstructurasService.shared.fetchHistorialCobertura(
                año: añoSeleccionado,
                mesInicio: mesInicioParaAño
            )
        } catch {
            print("🔴 CoberturaHistorial error: \(error)")
            errorMsg = "\(error)"
            datos = []
        }
    }
}

// MARK: - Row

private struct MesCoberturaRow: View {
    let mes: CoberturaMensual
    let onTap: () -> Void

    private var nombreMes: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "MMMM"
        var c = DateComponents(); c.year = mes.año; c.month = mes.mes; c.day = 1
        guard let d = Calendar.current.date(from: c) else { return "" }
        return fmt.string(from: d).capitalized
    }

    private var barColor: Color {
        if mes.enCurso { return Color("Azul") }
        switch mes.porcentaje {
        case 1.0:        return Color(hex: "#16a34a")
        case 0.8..<1.0:  return Color("Azul")
        case 0.5..<0.8:  return Color(hex: "#d97706")
        default:         return Color(hex: "#dc2626")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nombreMes)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Navy"))
                    if mes.enCurso {
                        Text("en curso")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color("Azul"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("Azul").opacity(0.12), in: Capsule())
                    }
                }
                Text("\(mes.visitadas) de \(mes.total) estructuras")
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
            .frame(minWidth: 130, alignment: .leading)

            Spacer(minLength: 0)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color("TextMuted").opacity(0.12))
                    Capsule().fill(barColor)
                        .frame(width: geo.size.width * mes.porcentaje)
                }
            }
            .frame(width: 72, height: 6)

            HStack(spacing: 6) {
                Text("\(Int(mes.porcentaje * 100))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(barColor)
                    .frame(width: 38, alignment: .trailing)
                if mes.completo {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#16a34a"))
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("TextMuted").opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
