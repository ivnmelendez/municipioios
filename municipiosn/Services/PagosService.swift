import Foundation
import Supabase

struct PagosService {
    static let shared = PagosService()
    private init() {}

    func fetchPagos() async throws -> [PagoManoObra] {
        try await SupabaseService.shared.client
            .from("pagos_mano_obra")
            .select()
            .order("fecha", ascending: false)
            .execute()
            .value
    }

    func registrar(fecha: String, trabajador: String, monto: Double, concepto: String?, creadoPor: UUID) async throws {
        struct Payload: Encodable {
            let fecha: String
            let trabajador: String
            let monto: Double
            let concepto: String?
            let creado_por: String
        }
        try await SupabaseService.shared.client
            .from("pagos_mano_obra")
            .insert(Payload(
                fecha: fecha,
                trabajador: trabajador,
                monto: monto,
                concepto: concepto?.isEmpty == true ? nil : concepto,
                creado_por: creadoPor.uuidString
            ))
            .execute()
    }

    func eliminar(id: UUID) async throws {
        try await SupabaseService.shared.client
            .from("pagos_mano_obra")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
