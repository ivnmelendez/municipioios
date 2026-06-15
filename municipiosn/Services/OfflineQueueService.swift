import Foundation
import Network

@MainActor
@Observable
final class OfflineQueueService {
    static let shared = OfflineQueueService()

    private(set) var pendientes: [AccionPendiente] = []
    private(set) var isConnected: Bool = true
    private(set) var isProcessing: Bool = false

    private let fileURL: URL
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.municipiosn.offline.monitor")

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("offline_queue.json")
        cargarDisco()
        iniciarMonitor()
    }

    // MARK: - Public API

    func encolar(_ accion: AccionPendiente) {
        pendientes.append(accion)
        guardarDisco()
    }

    func procesarQueue() async {
        guard !isProcessing, !pendientes.isEmpty, isConnected else { return }
        isProcessing = true
        defer { isProcessing = false }

        var restantes: [AccionPendiente] = []
        for var accion in pendientes {
            do {
                try await ejecutar(accion)
            } catch {
                accion.intentos += 1
                if accion.intentos < 5 {
                    restantes.append(accion)
                }
                // Más de 5 intentos: ya caducó, se descarta
            }
        }
        pendientes = restantes
        guardarDisco()
    }

    // MARK: - Private

    private func iniciarMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let estabaDesconectado = !self.isConnected
                self.isConnected = path.status == .satisfied
                if estabaDesconectado && self.isConnected && !self.pendientes.isEmpty {
                    await self.procesarQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func ejecutar(_ accion: AccionPendiente) async throws {
        let antesUrl = try await subirFoto(accion.fotoAntesData, userId: accion.userId, sufijo: "antes")
        let despuesUrl = try await subirFoto(accion.fotoDespuesData, userId: accion.userId, sufijo: "despues")

        switch accion.tipo {
        case .revision:
            try await RutasService.shared.marcarRevision(
                estructuraId: accion.estructuraId,
                rutaSemanaId: accion.rutaSemanaId,
                userId: accion.userId
            )

        case .reparacionCoroplast:
            try await CoroplastService.shared.registrarReparacion(
                estructuraId: accion.estructuraId,
                userId: accion.userId,
                rutaSemanaId: accion.rutaSemanaId,
                fotoAntesUrl: antesUrl,
                fotoDespuesUrl: despuesUrl,
                notas: accion.notas
            )

        case .cambioCoroplast:
            let estado = EstadoEstructura(rawValue: accion.estadoEstructura ?? "") ?? .activa
            let asignaciones = (accion.caras ?? []).map { (caraId: $0.caraId, campanaId: $0.campanaId) }
            try await CoroplastService.shared.registrarCambio(
                estructuraId: accion.estructuraId,
                estadoActual: estado,
                userId: accion.userId,
                rutaSemanaId: accion.rutaSemanaId,
                carasNuevasCampanas: asignaciones,
                fotoAntesUrl: antesUrl,
                fotoDespuesUrl: despuesUrl,
                notas: accion.notas
            )

        case .reporteDano:
            try await CoroplastService.shared.reportarDano(
                estructuraId: accion.estructuraId,
                userId: accion.userId,
                rutaSemanaId: accion.rutaSemanaId,
                fotoUrl: antesUrl,
                notas: accion.notas
            )
        }
    }

    private func subirFoto(_ data: Data?, userId: UUID, sufijo: String) async throws -> String? {
        guard let data else { return nil }
        let path = "\(userId.uuidString)/\(UUID().uuidString)_\(sufijo).jpg"
        return try await CoroplastService.shared.uploadFoto(data: data, path: path)
    }

    private func cargarDisco() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AccionPendiente].self, from: data)
        else { return }
        pendientes = decoded
    }

    private func guardarDisco() {
        guard let data = try? JSONEncoder().encode(pendientes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
