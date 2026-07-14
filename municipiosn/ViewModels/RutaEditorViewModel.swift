import Foundation
import SwiftUI

@MainActor
@Observable
final class RutaEditorViewModel {
    var semanas: [RutaSemana] = []
    var items: [[RutaEditorItem]] = []         // items[rutaIndex] = ordered stops
    var todasEstructuras: [EstructuraConParque] = []
    var asignaciones: [UUID: (junctionId: UUID, rutaSemanaId: UUID)] = [:]

    var rutaActivaIndex: Int = 0
    var cargando = false
    var guardando = false
    var errorMensaje: String?
    var confirmacionMover: ConfirmacionMover?
    var pdfURL: IdentifiableURL?
    var pinInfosVersion: Int = 0

    struct ConfirmacionMover: Identifiable {
        let id = UUID()
        let estructuraId: UUID
        let junctionId: UUID
        let deRutaNumero: Int
    }

    private var reorderTask: Task<Void, Never>?
    private let service = RutaEditorService.shared

    var rutaActiva: RutaSemana? {
        semanas.indices.contains(rutaActivaIndex) ? semanas[rutaActivaIndex] : nil
    }

    var itemsActivos: [RutaEditorItem] {
        items.indices.contains(rutaActivaIndex) ? items[rutaActivaIndex] : []
    }

    var pinInfos: [UUID: PinInfo] {
        guard let activaSemana = rutaActiva else { return [:] }
        var result: [UUID: PinInfo] = [:]
        for e in todasEstructuras {
            guard e.lat != nil, e.lng != nil else { continue }
            if let asig = asignaciones[e.id] {
                if asig.rutaSemanaId == activaSemana.id {
                    result[e.id] = PinInfo(color: uiColor(hex: activaSemana.color), opacity: 1.0)
                } else if let semana = semanas.first(where: { $0.id == asig.rutaSemanaId }) {
                    result[e.id] = PinInfo(color: uiColor(hex: semana.color), opacity: 0.3)
                }
            } else {
                result[e.id] = PinInfo(color: .systemGray3, opacity: 0.5)
            }
        }
        return result
    }

    // MARK: - Load

    func cargar() async {
        cargando = true
        defer { cargando = false }
        do {
            async let semanasTask = service.fetchSemanas()
            async let estructurasTask = service.fetchTodasEstructuras()
            let (fetchedSemanas, fetchedEstructuras) = try await (semanasTask, estructurasTask)

            semanas = fetchedSemanas.sorted { $0.numero < $1.numero }
            todasEstructuras = fetchedEstructuras

            let semanaIds = semanas.map { $0.id }
            let junctions = try await service.fetchJunctions(semanaIds: semanaIds)

            asignaciones = [:]
            var groupedItems: [UUID: [RutaEditorItem]] = [:]
            let estructurasById = Dictionary(uniqueKeysWithValues: fetchedEstructuras.map { ($0.id, $0) })

            for j in junctions {
                asignaciones[j.estructuraId] = (junctionId: j.id, rutaSemanaId: j.rutaSemanaId)
                if let e = estructurasById[j.estructuraId] {
                    let item = RutaEditorItem(id: j.id, orden: j.orden, estructura: e)
                    groupedItems[j.rutaSemanaId, default: []].append(item)
                }
            }

            items = semanas.map { semana in
                (groupedItems[semana.id] ?? []).sorted { $0.orden < $1.orden }
            }

            pinInfosVersion += 1
        } catch {
            errorMensaje = error.localizedDescription
        }
    }

    // MARK: - Selection

    func seleccionarRuta(_ index: Int) {
        rutaActivaIndex = index
        pinInfosVersion += 1
    }

    // MARK: - Pin tap

    func tapPin(estructuraId: UUID) {
        guard let activaSemana = rutaActiva else { return }

        if let asig = asignaciones[estructuraId] {
            if asig.rutaSemanaId == activaSemana.id { return }
            let deNumero = semanas.first { $0.id == asig.rutaSemanaId }?.numero ?? 0
            confirmacionMover = ConfirmacionMover(
                estructuraId: estructuraId,
                junctionId: asig.junctionId,
                deRutaNumero: deNumero
            )
        } else {
            Task { await _agregarEstructura(estructuraId) }
        }
    }

    private func _agregarEstructura(_ estructuraId: UUID) async {
        guard let activaSemana = rutaActiva,
              let estructura = todasEstructuras.first(where: { $0.id == estructuraId }) else { return }

        let nuevoOrden = itemsActivos.count
        do {
            let junctionId = try await service.agregarEstructura(
                estructuraId: estructuraId,
                rutaSemanaId: activaSemana.id,
                orden: nuevoOrden
            )
            let item = RutaEditorItem(id: junctionId, orden: nuevoOrden, estructura: estructura)
            items[rutaActivaIndex].append(item)
            asignaciones[estructuraId] = (junctionId: junctionId, rutaSemanaId: activaSemana.id)
            pinInfosVersion += 1
            HapticService.impacto(.light)
        } catch {
            errorMensaje = error.localizedDescription
        }
    }

    func confirmarMover() async {
        guard let conf = confirmacionMover, let activaSemana = rutaActiva else { return }
        confirmacionMover = nil

        let nuevoOrden = itemsActivos.count
        do {
            try await service.moverEstructura(
                junctionId: conf.junctionId,
                nuevaRutaSemanaId: activaSemana.id,
                nuevoOrden: nuevoOrden
            )
            // Remove from old route and persist its new order
            for i in items.indices {
                if let idx = items[i].firstIndex(where: { $0.id == conf.junctionId }) {
                    items[i].remove(at: idx)
                    recalcularOrdenLocal(rutaIndex: i)
                    let pairs = items[i].map { (junctionId: $0.id, orden: $0.orden) }
                    if !pairs.isEmpty { try await service.actualizarOrden(items: pairs) }
                    break
                }
            }
            // Add to active route
            if let estructura = todasEstructuras.first(where: { $0.id == conf.estructuraId }) {
                items[rutaActivaIndex].append(RutaEditorItem(
                    id: conf.junctionId, orden: nuevoOrden, estructura: estructura
                ))
            }
            asignaciones[conf.estructuraId] = (junctionId: conf.junctionId, rutaSemanaId: activaSemana.id)
            pinInfosVersion += 1
            HapticService.impacto(.medium)
        } catch {
            errorMensaje = error.localizedDescription
        }
    }

    // MARK: - Reorder / Delete

    func moverEnRuta(from: IndexSet, to: Int) {
        items[rutaActivaIndex].move(fromOffsets: from, toOffset: to)
        recalcularOrdenLocal(rutaIndex: rutaActivaIndex)
        flushOrdenDebounced()
    }

    func eliminarDeRuta(at offsets: IndexSet) {
        guard let offset = offsets.first else { return }
        let item = itemsActivos[offset]

        items[rutaActivaIndex].remove(at: offset)
        asignaciones.removeValue(forKey: item.estructura.id)
        recalcularOrdenLocal(rutaIndex: rutaActivaIndex)
        pinInfosVersion += 1

        Task {
            do {
                try await service.eliminarEstructura(junctionId: item.id)
                flushOrdenDebounced()
                HapticService.impacto(.light)
            } catch {
                await cargar()
                errorMensaje = error.localizedDescription
            }
        }
    }

    private func recalcularOrdenLocal(rutaIndex: Int) {
        for i in items[rutaIndex].indices {
            items[rutaIndex][i].orden = i
        }
    }

    private func flushOrdenDebounced() {
        reorderTask?.cancel()
        reorderTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.persistirOrdenActivo()
        }
    }

    private func persistirOrdenActivo() async {
        let pairs = itemsActivos.map { (junctionId: $0.id, orden: $0.orden) }
        guard !pairs.isEmpty else { return }
        guardando = true
        defer { guardando = false }
        do {
            try await service.actualizarOrden(items: pairs)
        } catch {
            errorMensaje = error.localizedDescription
        }
    }

    // MARK: - PDF

    func exportarPDF() async {
        guard let semana = rutaActiva else { return }
        do {
            let url = try RutaEditorPDFService.generarPDF(semana: semana, items: itemsActivos)
            pdfURL = IdentifiableURL(url: url, titulo: "Ruta \(semana.numero)")
        } catch {
            errorMensaje = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func uiColor(hex: String) -> UIColor {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        return UIColor(
            red: CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8) & 0xFF) / 255,
            blue: CGFloat(int & 0xFF) / 255,
            alpha: 1
        )
    }
}
