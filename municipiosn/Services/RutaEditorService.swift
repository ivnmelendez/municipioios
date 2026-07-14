import Foundation
import Supabase

enum RutaEditorError: Error, LocalizedError {
    case insertFailed
    case noRoutes

    var errorDescription: String? {
        switch self {
        case .insertFailed: return "No se pudo agregar la estructura a la ruta."
        case .noRoutes: return "No se encontraron rutas activas."
        }
    }
}

final class RutaEditorService {
    static let shared = RutaEditorService()
    private var client: SupabaseClient { SupabaseService.shared.client }
    private init() {}

    func fetchSemanas() async throws -> [RutaSemana] {
        try await RutasService.shared.fetchSemanasRecientes()
    }

    func fetchJunctions(semanaIds: [UUID]) async throws -> [RutaJunction] {
        guard !semanaIds.isEmpty else { return [] }
        return try await client
            .from("rutas_estructuras")
            .select("id, ruta_semana_id, estructura_id, orden")
            .in("ruta_semana_id", values: semanaIds.map { $0.uuidString })
            .order("orden", ascending: true)
            .execute()
            .value
    }

    func fetchTodasEstructuras() async throws -> [EstructuraConParque] {
        try await client
            .from("estructuras")
            .select("*, parques(id, nombre, colonias(id, nombre, activo))")
            .neq("estado", value: "inactiva")
            .order("numero", ascending: true)
            .execute()
            .value
    }

    func agregarEstructura(estructuraId: UUID, rutaSemanaId: UUID, orden: Int) async throws -> UUID {
        struct Row: Encodable {
            let ruta_semana_id: String
            let estructura_id: String
            let orden: Int
        }
        struct Result: Decodable { let id: UUID }
        let result: [Result] = try await client
            .from("rutas_estructuras")
            .insert(Row(ruta_semana_id: rutaSemanaId.uuidString,
                        estructura_id: estructuraId.uuidString,
                        orden: orden))
            .select("id")
            .execute()
            .value
        guard let first = result.first else { throw RutaEditorError.insertFailed }
        return first.id
    }

    func moverEstructura(junctionId: UUID, nuevaRutaSemanaId: UUID, nuevoOrden: Int) async throws {
        struct Row: Encodable {
            let ruta_semana_id: String
            let orden: Int
        }
        try await client
            .from("rutas_estructuras")
            .update(Row(ruta_semana_id: nuevaRutaSemanaId.uuidString, orden: nuevoOrden))
            .eq("id", value: junctionId.uuidString)
            .execute()
    }

    func eliminarEstructura(junctionId: UUID) async throws {
        try await client
            .from("rutas_estructuras")
            .delete()
            .eq("id", value: junctionId.uuidString)
            .execute()
    }

    func actualizarOrden(items: [(junctionId: UUID, orden: Int)]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { [self] in
                    try await self.client
                        .from("rutas_estructuras")
                        .update(["orden": item.orden])
                        .eq("id", value: item.junctionId.uuidString)
                        .execute()
                }
            }
            try await group.waitForAll()
        }
    }
}
