import Foundation
import Supabase

struct EstructuraConParque: Codable, Identifiable, Hashable {
    let id: UUID
    let numero: String
    let numeroLocal: String?
    let parqueId: UUID?
    let lat: Double?
    let lng: Double?
    let estado: EstadoEstructura
    let fotoUrl: String?
    let notas: String?
    let fechaInstalacion: Date?
    let parques: ParqueConColonia?

    enum CodingKeys: String, CodingKey {
        case id, numero, estado, lat, lng, notas
        case numeroLocal = "numero_local"
        case parqueId = "parque_id"
        case fotoUrl = "foto_url"
        case fechaInstalacion = "fecha_instalacion"
        case parques
    }
}

struct ParqueConColonia: Codable, Identifiable, Hashable {
    let id: UUID
    let nombre: String
    let colonias: Colonia?
}

struct ParqueParaCrear: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let lat: Double?
    let lng: Double?
    let colonias: ColoniaSimple?

    struct ColoniaSimple: Codable {
        let nombre: String
    }

    var etiqueta: String {
        [nombre, colonias?.nombre].compactMap { $0 }.joined(separator: " — ")
    }
}

struct EstructuraCreada: Decodable {
    let id: UUID
    let numero: String
}

struct CarasCreadas {
    let caraAId: UUID
    let caraBId: UUID
}


struct CaraDetalle: Identifiable {
    let id: UUID
    let tipo: String
    let fotoUrl: String?
    let campana: CampanaDetalle?
    let fotoCampana: String?

    struct CampanaDetalle: Identifiable {
        let id: UUID
        let nombre: String
        let fotoUrl: String?
    }
}

private struct CaraRaw: Codable {
    let id: UUID
    let tipo: String
    let fotoUrl: String?
    let carasCampanas: [CaraCampanaRaw]

    struct CaraCampanaRaw: Codable {
        let activa: Bool
        let fotoUrl: String?
        let campanas: CampanaRaw?

        struct CampanaRaw: Codable {
            let id: UUID
            let nombre: String
            let fotoUrl: String?

            enum CodingKeys: String, CodingKey {
                case id, nombre
                case fotoUrl = "foto_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case activa
            case fotoUrl = "foto_url"
            case campanas
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, tipo
        case fotoUrl = "foto_url"
        case carasCampanas = "caras_campanas"
    }
}

private struct CaraCampanaColoniaRaw: Codable {
    let campanas: CampanaInfo
    let caras: CaraInfo

    struct CampanaInfo: Codable {
        let id: UUID
        let nombre: String
        let fotoUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, nombre
            case fotoUrl = "foto_url"
        }
    }

    struct CaraInfo: Codable {
        let estructuras: EstructuraInfo?

        struct EstructuraInfo: Codable {
            let parques: ParqueInfo?

            struct ParqueInfo: Codable {
                let colonias: ColoniaInfo?

                struct ColoniaInfo: Codable {
                    let id: UUID
                    let nombre: String
                }
            }
        }
    }
}

private struct CaraCampanaItem: Codable {
    let campanaId: UUID
    let campanas: CampanaResumen
    let caras: CaraResumen

    struct CampanaResumen: Codable {
        let id: UUID
        let nombre: String
        let fotoUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, nombre
            case fotoUrl = "foto_url"
        }
    }

    struct CaraResumen: Codable {
        let estructuraId: String

        enum CodingKeys: String, CodingKey {
            case estructuraId = "estructura_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case campanaId = "campana_id"
        case campanas, caras
    }
}

final class EstructurasService {
    static let shared = EstructurasService()
    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    private var campanasCached: [CampanaBasica] = []
    private var campanasCachedAt: Date? = nil
    private let campanasTTL: TimeInterval = 300

    private var estructurasCache: [EstructuraConParque]? = nil
    private var estructurasCachedAt: Date? = nil
    private let estructurasTTL: TimeInterval = 120

    func fetchEstructuras() async throws -> [EstructuraConParque] {
        if let cache = estructurasCache,
           let cachedAt = estructurasCachedAt,
           Date().timeIntervalSince(cachedAt) < estructurasTTL {
            return cache
        }
        let result: [EstructuraConParque] = try await client
            .from("estructuras")
            .select("*, parques(id, nombre, colonias(id, nombre, activo))")
            .execute()
            .value
        estructurasCache = result
        estructurasCachedAt = Date()
        return result
    }

    func fetchEstructura(id: UUID) async throws -> EstructuraConParque? {
        let todas = try await fetchEstructuras()
        return todas.first { $0.id == id }
    }

    func invalidarCacheEstructuras() {
        estructurasCache = nil
        estructurasCachedAt = nil
    }

    func fetchKPIs() async throws -> KPIData {
        async let estructuras: [EstructuraConParque] = fetchEstructuras()
        async let campanas: [Campana] = client
            .from("campanas")
            .select()
            .eq("activa", value: true)
            .execute()
            .value
        async let coroplastCount = fetchCoroplastMes()
        async let semana = fetchResumenSemana()

        let (e, c) = try await (estructuras, campanas)
        let cm = (try? await coroplastCount) ?? 0
        let (visitas, cambios, danos) = (try? await semana) ?? (0, 0, 0)

        var kpi = KPIData()
        kpi.totalEstructuras = e.count
        kpi.activas = e.filter { $0.estado == .activa }.count
        kpi.dañadas = e.filter { $0.estado == .dañada }.count
        kpi.enReparacion = e.filter { $0.estado == .en_reparacion }.count
        kpi.inactivas = e.filter { $0.estado == .inactiva }.count
        kpi.campanasActivas = c.count
        kpi.coroplastMes = cm
        kpi.visitasSemana = visitas
        kpi.cambiosSemana = cambios
        kpi.danosSemana = danos
        kpi.isLoaded = true
        return kpi
    }

    func fetchResumenMes() async throws -> (visitas: Int, cambios: Int, danos: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Monterrey")!
        let hoy = Date()
        let inicioMes = cal.dateInterval(of: .month, for: hoy)?.start ?? hoy
        return try await fetchResumenEntre(desde: inicioMes, hasta: hoy)
    }

    func fetchResumenSemana() async throws -> (visitas: Int, cambios: Int, danos: Int) {
        let calendar = Calendar.current
        let hoy = Date()
        let inicioSemana = calendar.dateInterval(of: .weekOfYear, for: hoy)?.start ?? hoy
        return try await fetchResumenEntre(desde: inicioSemana, hasta: hoy)
    }

    private func fetchResumenEntre(desde: Date, hasta: Date) async throws -> (visitas: Int, cambios: Int, danos: Int) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let desdeStr = isoFormatter.string(from: desde)
        let hastaStr = isoFormatter.string(from: hasta)

        struct VisitaRow: Codable {
            let estructuraId: UUID
            enum CodingKeys: String, CodingKey { case estructuraId = "estructura_id" }
        }
        struct AccionRow: Codable {
            let accion: String
        }

        async let visitasRaw: [VisitaRow] = client
            .from("rondines_estructuras")
            .select("estructura_id, rondines!inner(fecha)")
            .gte("rondines.fecha", value: desdeStr)
            .lte("rondines.fecha", value: hastaStr)
            .execute()
            .value

        async let accionesRaw: [AccionRow] = client
            .from("rondines_estructuras")
            .select("accion, rondines!inner(fecha)")
            .gte("rondines.fecha", value: desdeStr)
            .lte("rondines.fecha", value: hastaStr)
            .execute()
            .value

        let (visitas, acciones) = try await (visitasRaw, accionesRaw)
        let visitasUnicas = Set(visitas.map { $0.estructuraId }).count
        let cambios = acciones.filter { ["cambio_coroplast", "reparacion_coroplast", "reactivacion"].contains($0.accion) }.count
        let danos = acciones.filter { $0.accion == "reporte_dano" }.count
        return (visitasUnicas, cambios, danos)
    }

    private func fetchCoroplastMes() async throws -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Monterrey")!
        let hoy = Date()
        let inicioMes = cal.dateInterval(of: .month, for: hoy)?.start ?? hoy
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        struct Row: Codable { let id: UUID }
        let rows: [Row] = try await client
            .from("rondines_estructuras")
            .select("id, rondines!inner(fecha)")
            .eq("accion", value: "cambio_coroplast")
            .gte("rondines.fecha", value: fmt.string(from: inicioMes))
            .lte("rondines.fecha", value: fmt.string(from: hoy))
            .execute()
            .value
        return rows.count
    }

    func fetchCaras(estructuraId: UUID) async throws -> [Cara] {
        try await client
            .from("caras")
            .select()
            .eq("estructura_id", value: estructuraId.uuidString)
            .execute()
            .value
    }

    func fetchCarasDetalle(estructuraId: UUID) async throws -> [CaraDetalle] {
        let raw: [CaraRaw] = try await client
            .from("caras")
            .select("id, tipo, foto_url, caras_campanas(activa, foto_url, campanas(id, nombre, foto_url))")
            .eq("estructura_id", value: estructuraId.uuidString)
            .execute()
            .value

        return raw.map { cara in
            let activa = cara.carasCampanas.first(where: { $0.activa })
            return CaraDetalle(
                id: cara.id,
                tipo: cara.tipo,
                fotoUrl: cara.fotoUrl,
                campana: activa?.campanas.map { c in
                    CaraDetalle.CampanaDetalle(id: c.id, nombre: c.nombre, fotoUrl: c.fotoUrl)
                },
                fotoCampana: activa?.fotoUrl
            )
        }
    }

    func fetchCampanaActivaDeCara(caraId: UUID) async throws -> Campana? {
        let result: [CaraCampana] = try await client
            .from("caras_campanas")
            .select("*, campanas(*)")
            .eq("cara_id", value: caraId.uuidString)
            .limit(1)
            .execute()
            .value
        print("🔍 caraId=\(caraId) → \(result.count) registros, campana=\(String(describing: result.first?.campana?.nombre))")
        return result.first?.campana
    }

    func fetchTotalColonias() async throws -> Int {
        let response = try await client
            .from("colonias")
            .select("*", head: true, count: .exact)
            .eq("activo", value: true)
            .execute()
        return response.count ?? 0
    }

    func fetchColoniasConCampanas() async throws -> [ColoniaConCampanas] {
        let raw: [CaraCampanaColoniaRaw] = try await client
            .from("caras_campanas")
            .select("campanas(id, nombre, foto_url), caras(estructuras(parques(colonias(id, nombre))))")
            .eq("activa", value: true)
            .execute()
            .value

        // Aggregate: colonia → campana → cara count
        var coloniaInfo: [UUID: (nombre: String, estructuras: Set<UUID>)] = [:]
        var campanasPorColonia: [UUID: [UUID: (nombre: String, caras: Int, fotoUrl: String?)]] = [:]

        for item in raw {
            guard let colonia = item.caras.estructuras?.parques?.colonias else { continue }
            let cid = colonia.id
            let pid = item.campanas.id

            if coloniaInfo[cid] == nil {
                coloniaInfo[cid] = (colonia.nombre, [])
            }
            campanasPorColonia[cid, default: [:]][pid] = (
                item.campanas.nombre,
                (campanasPorColonia[cid]?[pid]?.caras ?? 0) + 1,
                item.campanas.fotoUrl
            )
        }

        // Fetch estructura counts per colonia
        let estructuras = try await fetchEstructuras()
        var estructurasPorColonia: [UUID: Int] = [:]
        for e in estructuras {
            guard let cid = e.parques?.colonias?.id else { continue }
            estructurasPorColonia[cid, default: 0] += 1
        }

        return coloniaInfo.map { cid, info in
            let campanas = (campanasPorColonia[cid] ?? [:]).map { pid, val in
                CampanaEnColonia(id: pid, nombre: val.nombre, totalCaras: val.caras, fotoUrl: val.fotoUrl)
            }.sorted { $0.totalCaras > $1.totalCaras }
            return ColoniaConCampanas(
                id: cid,
                nombre: info.nombre,
                totalEstructuras: estructurasPorColonia[cid] ?? 0,
                campanas: campanas
            )
        }.sorted { $0.totalEstructuras > $1.totalEstructuras }
    }

    func fetchUsoColonias() async throws -> [UsoColonia] {
        let estructuras = try await fetchEstructuras()
        var counts: [UUID: (nombre: String, count: Int)] = [:]
        for e in estructuras {
            guard let colonia = e.parques?.colonias else { continue }
            counts[colonia.id] = (colonia.nombre, (counts[colonia.id]?.count ?? 0) + 1)
        }
        return counts.map { id, val in
            UsoColonia(id: id, nombre: val.nombre, totalEstructuras: val.count)
        }.sorted { $0.totalEstructuras > $1.totalEstructuras }
    }


    func fetchUsoCampanas() async throws -> [UsoCampana] {
        let items: [CaraCampanaItem] = try await client
            .from("caras_campanas")
            .select("campana_id, campanas(id, nombre, foto_url), caras(estructura_id)")
            .eq("activa", value: true)
            .execute()
            .value

        var data: [UUID: (nombre: String, estructuras: Set<String>, fotoUrl: String?)] = [:]
        for item in items {
            let id = item.campanas.id
            var entry = data[id] ?? (item.campanas.nombre, Set<String>(), item.campanas.fotoUrl)
            entry.estructuras.insert(item.caras.estructuraId)
            data[id] = entry
        }

        return data.map { id, val in
            UsoCampana(id: id, nombre: val.nombre, totalEstructuras: val.estructuras.count, fotoUrl: val.fotoUrl)
        }.sorted { $0.totalEstructuras > $1.totalEstructuras }
    }

    // MARK: - Creación

    func fetchParquesParaCrear() async throws -> [ParqueParaCrear] {
        try await client
            .from("parques")
            .select("id, nombre, lat, lng, colonias(nombre)")
            .eq("activo", value: true)
            .order("nombre")
            .execute()
            .value
    }

    func crearEstructura(
        parqueId: UUID?,
        lat: Double,
        lng: Double,
        estado: EstadoEstructura,
        fechaInstalacion: Date?,
        fotoUrl: String? = nil
    ) async throws -> EstructuraCreada {
        struct Insert: Encodable {
            let parque_id: String?
            let lat: Double
            let lng: Double
            let estado: String
            let fecha_instalacion: String?
            let foto_url: String?
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let insert = Insert(
            parque_id: parqueId?.uuidString,
            lat: lat,
            lng: lng,
            estado: estado.rawValue,
            fecha_instalacion: fechaInstalacion.map { formatter.string(from: $0) },
            foto_url: fotoUrl
        )
        return try await client
            .from("estructuras")
            .insert(insert)
            .select("id, numero")
            .single()
            .execute()
            .value
    }

    func crearCaras(estructuraId: UUID) async throws -> CarasCreadas {
        struct CaraInsert: Encodable {
            let estructura_id: String
            let tipo: String
            let estado: String
        }
        struct CaraRespuesta: Decodable {
            let id: UUID
            let tipo: String
        }
        let result: [CaraRespuesta] = try await client
            .from("caras")
            .insert([
                CaraInsert(estructura_id: estructuraId.uuidString, tipo: "A", estado: "buena"),
                CaraInsert(estructura_id: estructuraId.uuidString, tipo: "B", estado: "buena")
            ])
            .select("id, tipo")
            .execute()
            .value
        guard let a = result.first(where: { $0.tipo == "A" })?.id,
              let b = result.first(where: { $0.tipo == "B" })?.id else {
            throw NSError(domain: "NuevaEstructura", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Error creando caras"])
        }
        return CarasCreadas(caraAId: a, caraBId: b)
    }

    func asignarCampana(caraId: UUID, campanaId: UUID) async throws {
        struct Desactivacion: Encodable {
            let activa: Bool
            let fecha_fin: String
        }
        struct Asignacion: Encodable {
            let cara_id: String
            let campana_id: String
            let activa: Bool
        }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let hoy = fmt.string(from: Date())

        do {
            try await client
                .from("caras_campanas")
                .update(Desactivacion(activa: false, fecha_fin: hoy))
                .eq("cara_id", value: caraId.uuidString)
                .eq("activa", value: true)
                .execute()
            print("[asignarCampana] desactivada cara \(caraId)")
        } catch {
            print("[asignarCampana] ERROR desactivando: \(error)")
        }

        do {
            try await client
                .from("caras_campanas")
                .insert(Asignacion(cara_id: caraId.uuidString, campana_id: campanaId.uuidString, activa: true))
                .execute()
            print("[asignarCampana] insertada campana \(campanaId) en cara \(caraId)")
        } catch {
            print("[asignarCampana] ERROR insertando: \(error)")
            throw error
        }
    }

    func fetchCampanasActivas() async throws -> [CampanaBasica] {
        if let ts = campanasCachedAt, !campanasCached.isEmpty,
           Date().timeIntervalSince(ts) < campanasTTL {
            return campanasCached
        }
        let result: [CampanaBasica] = try await client
            .from("campanas")
            .select("id, nombre, foto_url")
            .eq("activa", value: true)
            .order("nombre")
            .execute()
            .value
        campanasCached = result
        campanasCachedAt = Date()
        return result
    }

}
