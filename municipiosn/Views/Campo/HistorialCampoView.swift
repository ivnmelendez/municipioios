import SwiftUI

private struct EstructuraDetalleLoader: View {
    let id: UUID
    @State private var estructura: EstructuraConParque? = nil
    @State private var cargando = true

    var body: some View {
        Group {
            if cargando {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let e = estructura {
                EstructuraDetalleView(estructura: e)
            } else {
                ContentUnavailableView("No encontrada", systemImage: "exclamationmark.triangle")
            }
        }
        .task {
            estructura = try? await EstructurasService.shared.fetchEstructura(id: id)
            cargando = false
        }
    }
}

struct HistorialCampoView: View {
    let periodo: FiltroFecha
    @State private var vm = HistorialViewModel()

    private var dias: [DiaVisita] {
        switch periodo {
        case .semana:        return vm.diasSemana
        case .mes:           return vm.diasMes
        case .mesElegido:    return vm.diasMesElegido
        case .todo:          return vm.diasMes
        }
    }

    private var mostrarResumenMes: Bool {
        switch periodo {
        case .mes, .mesElegido: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            if vm.cargando {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dias.isEmpty {
                ContentUnavailableView(
                    "Sin visitas",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No hay estructuras visitadas en este periodo.")
                )
            } else {
                List {
                    if mostrarResumenMes {
                        resumenMesSection(dias: dias)
                    }
                    ForEach(dias) { dia in
                        diaSection(dia: dia)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
        .onChange(of: periodo) { (_: FiltroFecha, new: FiltroFecha) in
            if case .mesElegido(let d) = new {
                Task { await vm.cargarMesElegido(fecha: d) }
            }
        }
    }

    private func diaSection(dia: DiaVisita) -> some View {
        Section {
            ForEach(dia.estructuras) { e in
                NavigationLink(destination: EstructuraDetalleLoader(id: e.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.numero)
                            .font(.subheadline.weight(.medium))
                        if let colonia = e.colonia {
                            Text(colonia)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            HStack {
                Text(dia.fecha, style: .date)
                Spacer()
                Text("\(dia.estructuras.count) estructuras")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func resumenMesSection(dias: [DiaVisita]) -> some View {
        let semanas = agruparPorSemana(dias: dias)
        Section("Resumen del mes") {
            ForEach(semanas, id: \.label) { semana in
                HStack {
                    Text(semana.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(semana.total) estructuras")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("Navy"))
                }
            }
        }
    }

    private struct SemanaResumen {
        let label: String
        let total: Int
    }

    private func agruparPorSemana(dias: [DiaVisita]) -> [SemanaResumen] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Monterrey")!
        calendar.firstWeekday = 2 // lunes
        var porSemana: [Int: Int] = [:]
        var semanaFecha: [Int: Date] = [:]
        for dia in dias {
            let semana = calendar.component(.weekOfYear, from: dia.fecha)
            porSemana[semana, default: 0] += dia.estructuras.count
            if semanaFecha[semana] == nil { semanaFecha[semana] = dia.fecha }
        }
        return porSemana.sorted { $0.key > $1.key }.map { key, total in
            let fecha = semanaFecha[key] ?? Date()
            let inicio = calendar.dateInterval(of: .weekOfYear, for: fecha)?.start ?? fecha
            let fin = calendar.date(byAdding: .day, value: 6, to: inicio) ?? inicio
            let fmt = DateFormatter()
            fmt.dateFormat = "d MMM"
            fmt.locale = Locale(identifier: "es_MX")
            let label = "\(fmt.string(from: inicio)) – \(fmt.string(from: fin))"
            return SemanaResumen(label: label, total: total)
        }
    }
}
