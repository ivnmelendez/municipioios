import SwiftUI

struct HistorialCampoView: View {
    @State private var vm = HistorialViewModel()
    @State private var periodo: Periodo = .semana

    enum Periodo: String, CaseIterable {
        case semana = "Esta semana"
        case mes = "Este mes"
    }

    var body: some View {
        Group {
            if vm.cargando {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let dias = periodo == .semana ? vm.diasSemana : vm.diasMes
                if dias.isEmpty {
                    ContentUnavailableView(
                        "Sin visitas",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No hay estructuras visitadas \(periodo == .semana ? "esta semana" : "este mes").")
                    )
                } else {
                    List {
                        if periodo == .mes {
                            resumenMesSection(dias: dias)
                        }
                        ForEach(dias) { dia in
                            diaSection(dia: dia)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(Periodo.allCases, id: \.self) { p in
                        Button(p.rawValue) { periodo = p }
                    }
                } label: {
                    Label(periodo.rawValue, systemImage: "calendar")
                        .symbolVariant(.fill)
                }
            }
        }
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
    }

    private func diaSection(dia: DiaVisita) -> some View {
        Section {
            ForEach(dia.estructuras) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estructura \(e.numero)")
                        .font(.subheadline.weight(.medium))
                    if let colonia = e.colonia {
                        Text(colonia)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .scrollTransition(.animated.threshold(.visible(0.1))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .offset(y: phase.isIdentity ? 0 : 6)
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
        let calendar = Calendar.current
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
