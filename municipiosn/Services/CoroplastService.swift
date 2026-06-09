import Foundation
import Supabase

struct CaraParaCambio: Identifiable {
    let id: UUID
    let tipo: String
    let campanaActual: CampanaBasica?
    var nuevaCampana: CampanaBasica?
}

struct CampanaBasica: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let fotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre
        case fotoUrl = "foto_url"
    }
}

private struct CaraConCampanaRaw: Codable {
    let id: UUID
    let tipo: String
    let carasCampanas: [CaraCampanaSimple]

    struct CaraCampanaSimple: Codable {
        let activa: Bool
        let campanas: CampanaBasica?

        enum CodingKeys: String, CodingKey {
            case activa, campanas
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, tipo
        case carasCampanas = "caras_campanas"
    }
}

private struct RondinInsert: Encodable {
    let fecha: String
    let created_by: String
    let ruta_semana_id: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fecha, forKey: .fecha)
        try c.encode(created_by, forKey: .created_by)
        if let id = ruta_semana_id { try c.encode(id, forKey: .ruta_semana_id) }
    }

    enum CodingKeys: String, CodingKey { case fecha, created_by, ruta_semana_id }
}

private struct RondinEstructuraInsert: Encodable {
    let rondin_id: String
    let estructura_id: String
    let accion: String
    let tipo_dano: String?
    let foto_antes_url: String?
    let foto_despues_url: String?
    let notas: String?
}

private struct CaraCampanaInsert: Encodable {
    let cara_id: String
    let campana_id: String
    let fecha_inicio: String
    let activa: Bool
}

private struct CerrarCampanaUpdate: Encodable {
    let activa: Bool
    let fecha_fin: String
}

private struct EstadoUpdate: Encodable {
    let estado: String
}

final class CoroplastService {
    static let shared = CoroplastService()
    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchCampanasActivas() async throws -> [CampanaBasica] {
        try await client
            .from("campanas")
            .select("id, nombre, foto_url")
            .eq("activa", value: true)
            .order("nombre")
            .execute()
            .value
    }

    func fetchCarasParaCambio(estructuraId: UUID) async throws -> [CaraParaCambio] {
        let raw: [CaraConCampanaRaw] = try await client
            .from("caras")
            .select("id, tipo, caras_campanas(activa, campanas(id, nombre, foto_url))")
            .eq("estructura_id", value: estructuraId.uuidString)
            .execute()
            .value

        return raw.map { cara in
            let activa = cara.carasCampanas.first(where: { $0.activa })
            return CaraParaCambio(
                id: cara.id,
                tipo: cara.tipo,
                campanaActual: activa?.campanas,
                nuevaCampana: nil
            )
        }
    }

    func registrarReparacion(
        estructuraId: UUID,
        userId: UUID,
        rutaSemanaId: UUID? = nil,
        fotoAntesUrl: String?,
        fotoDespuesUrl: String?,
        notas: String?
    ) async throws {
        let rondinId = try await crearRondin(userId: userId, rutaSemanaId: rutaSemanaId)
        try await client
            .from("rondines_estructuras")
            .insert(RondinEstructuraInsert(
                rondin_id: rondinId.uuidString,
                estructura_id: estructuraId.uuidString,
                accion: "reparacion_coroplast",
                tipo_dano: nil,
                foto_antes_url: fotoAntesUrl,
                foto_despues_url: fotoDespuesUrl,
                notas: notas
            ))
            .execute()
    }

    func registrarCambio(
        estructuraId: UUID,
        estadoActual: EstadoEstructura,
        userId: UUID,
        rutaSemanaId: UUID? = nil,
        carasNuevasCampanas: [(caraId: UUID, campanaId: UUID)],
        fotoAntesUrl: String?,
        fotoDespuesUrl: String?,
        notas: String?
    ) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let hoy = formatter.string(from: Date())

        let caraIds = carasNuevasCampanas.map { $0.caraId.uuidString }

        try await client
            .from("caras_campanas")
            .update(CerrarCampanaUpdate(activa: false, fecha_fin: hoy))
            .eq("activa", value: true)
            .in("cara_id", values: caraIds)
            .execute()

        let inserts = carasNuevasCampanas.map { cara in
            CaraCampanaInsert(
                cara_id: cara.caraId.uuidString,
                campana_id: cara.campanaId.uuidString,
                fecha_inicio: hoy,
                activa: true
            )
        }
        try await client
            .from("caras_campanas")
            .insert(inserts)
            .execute()

        let rondinId = try await crearRondin(userId: userId, rutaSemanaId: rutaSemanaId)
        try await client
            .from("rondines_estructuras")
            .insert(RondinEstructuraInsert(
                rondin_id: rondinId.uuidString,
                estructura_id: estructuraId.uuidString,
                accion: "cambio_coroplast",
                tipo_dano: nil,
                foto_antes_url: fotoAntesUrl,
                foto_despues_url: fotoDespuesUrl,
                notas: notas
            ))
            .execute()

        if estadoActual == .dañada {
            try await client
                .from("estructuras")
                .update(EstadoUpdate(estado: "activa"))
                .eq("id", value: estructuraId.uuidString)
                .execute()
        }
    }

    func reportarDano(
        estructuraId: UUID,
        userId: UUID,
        rutaSemanaId: UUID? = nil,
        tipoDano: TipoDano,
        fotoUrl: String?,
        notas: String?
    ) async throws {
        let rondinId = try await crearRondin(userId: userId, rutaSemanaId: rutaSemanaId)
        try await client
            .from("rondines_estructuras")
            .insert(RondinEstructuraInsert(
                rondin_id: rondinId.uuidString,
                estructura_id: estructuraId.uuidString,
                accion: "reporte_dano",
                tipo_dano: tipoDano.rawValue,
                foto_antes_url: fotoUrl,
                foto_despues_url: nil,
                notas: notas
            ))
            .execute()
        try await client
            .from("estructuras")
            .update(EstadoUpdate(estado: tipoDano.estadoResultante.rawValue))
            .eq("id", value: estructuraId.uuidString)
            .execute()
    }

    func reactivarEstructura(
        estructuraId: UUID,
        userId: UUID,
        rutaSemanaId: UUID? = nil,
        fotoProveedorUrl: String?,
        notas: String?
    ) async throws {
        let rondinId = try await crearRondin(userId: userId, rutaSemanaId: rutaSemanaId)
        try await client
            .from("rondines_estructuras")
            .insert(RondinEstructuraInsert(
                rondin_id: rondinId.uuidString,
                estructura_id: estructuraId.uuidString,
                accion: "reactivacion",
                tipo_dano: nil,
                foto_antes_url: fotoProveedorUrl,
                foto_despues_url: nil,
                notas: notas
            ))
            .execute()
        try await client
            .from("estructuras")
            .update(EstadoUpdate(estado: "activa"))
            .eq("id", value: estructuraId.uuidString)
            .execute()
    }

    func uploadFoto(data: Data, path: String) async throws -> String {
        let fileOptions = FileOptions(contentType: "image/jpeg")
        try await client.storage
            .from("rondines")
            .upload(path, data: data, options: fileOptions)
        return try client.storage
            .from("rondines")
            .getPublicURL(path: path)
            .absoluteString
    }

    func registrarRevision(estructuraId: UUID, rutaSemanaId: UUID, userId: UUID) async throws {
        let rondinId = try await crearRondin(userId: userId, rutaSemanaId: rutaSemanaId)
        try await client
            .from("rondines_estructuras")
            .insert(RondinEstructuraInsert(
                rondin_id: rondinId.uuidString,
                estructura_id: estructuraId.uuidString,
                accion: "revision",
                tipo_dano: nil,
                foto_antes_url: nil,
                foto_despues_url: nil,
                notas: nil
            ))
            .execute()
    }

    private func crearRondin(userId: UUID, rutaSemanaId: UUID? = nil) async throws -> UUID {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let hoy = formatter.string(from: Date())

        struct RondinResponse: Codable {
            let id: UUID
        }
        let result: RondinResponse = try await client
            .from("rondines")
            .insert(RondinInsert(
                fecha: hoy,
                created_by: userId.uuidString,
                ruta_semana_id: rutaSemanaId?.uuidString
            ))
            .select("id")
            .single()
            .execute()
            .value
        return result.id
    }
}
