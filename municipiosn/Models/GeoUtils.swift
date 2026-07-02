import MapKit

struct GeoPolygon: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let cvegeo: String
    // Población total y género
    let poblacion: Int
    let pobFem: Int
    let pobMas: Int
    let p18ymas: Int
    // Grupos de edad (F=femenino, M=masculino)
    let p0a2F: Int;  let p0a2M: Int
    let p3a5F: Int;  let p3a5M: Int
    let p6a11F: Int; let p6a11M: Int
    let p12a14F: Int; let p12a14M: Int
    let p15a17F: Int; let p15a17M: Int
    let p18a24F: Int; let p18a24M: Int
    let p60ymasF: Int; let p60ymasM: Int
    // Segmentos agregados
    let pob0a14: Int
    let pob15a64: Int
    let p60ymas: Int
    // Servicios
    let psinder: Int     // sin seguro médico
    let vphInter: Int    // hogares con internet
    let vphSinInter: Int // hogares sin internet
    let tvivhab: Int     // total viviendas habitadas
    let pderSS: Int      // con seguridad social
}

func loadGeoPolygons(named filename: String) -> [GeoPolygon] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson"),
          let data = try? Data(contentsOf: url),
          let features = try? MKGeoJSONDecoder().decode(data) else { return [] }

    return features.compactMap { $0 as? MKGeoJSONFeature }.flatMap { feature in
        let props = (try? JSONSerialization.jsonObject(with: feature.properties ?? Data())) as? [String: Any]
        let cvegeo = props?["CVEGEO"] as? String
            ?? props?["name"] as? String
            ?? props?["NAME"] as? String
            ?? (props?["@id"].map { "\($0)" })
            ?? ""
        func i(_ k: String) -> Int { props?[k] as? Int ?? 0 }
        return feature.geometry.compactMap { $0 as? MKPolygon }.map { polygon in
            let coords = (0..<polygon.pointCount).map { polygon.points()[$0].coordinate }
            return GeoPolygon(
                coordinates: coords, cvegeo: cvegeo,
                poblacion: i("POBTOT"), pobFem: i("POBFEM"), pobMas: i("POBMAS"), p18ymas: i("P_18YMAS"),
                p0a2F: i("P_0A2_F"), p0a2M: i("P_0A2_M"),
                p3a5F: i("P_3A5_F"), p3a5M: i("P_3A5_M"),
                p6a11F: i("P_6A11_F"), p6a11M: i("P_6A11_M"),
                p12a14F: i("P_12A14_F"), p12a14M: i("P_12A14_M"),
                p15a17F: i("P_15A17_F"), p15a17M: i("P_15A17_M"),
                p18a24F: i("P_18A24_F"), p18a24M: i("P_18A24_M"),
                p60ymasF: i("P_60YMAS_F"), p60ymasM: i("P_60YMAS_M"),
                pob0a14: i("POB0_14"), pob15a64: i("POB15_64"), p60ymas: i("P_60YMAS"),
                psinder: i("PSINDER"), vphInter: i("VPH_INTER"),
                vphSinInter: i("VPH_SINCINT"), tvivhab: i("TVIVHAB"), pderSS: i("PDER_SS")
            )
        }
    }
}

func pointInPolygon(_ point: CLLocationCoordinate2D, _ polygon: [CLLocationCoordinate2D]) -> Bool {
    var inside = false
    let n = polygon.count
    var j = n - 1
    for i in 0..<n {
        let xi = polygon[i].longitude, yi = polygon[i].latitude
        let xj = polygon[j].longitude, yj = polygon[j].latitude
        if ((yi > point.latitude) != (yj > point.latitude)) &&
            (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
            inside.toggle()
        }
        j = i
    }
    return inside
}

func alcanceEstimado(polygons: [GeoPolygon], coordenadas: [CLLocationCoordinate2D]) -> Int {
    alcanceDetallado(polygons: polygons, coordenadas: coordenadas).pobtot
}

struct AlcanceDetalle {
    let pobtot: Int
    let pobFem: Int
    let pobMas: Int
    let p18ymas: Int
    let pob0a14: Int
    let pob15a64: Int
    let p60ymas: Int
    let dem: DemografiaAlcance
}

func alcanceDetallado(polygons: [GeoPolygon], coordenadas: [CLLocationCoordinate2D]) -> AlcanceDetalle {
    var agebs = Set<String>()
    var pobtot = 0; var pobFem = 0; var pobMas = 0; var p18ymas = 0
    var pob0a14 = 0; var pob15a64 = 0; var p60ymas = 0
    var dem = DemografiaAlcance()

    for coord in coordenadas {
        var matched = polygons.first(where: { !$0.cvegeo.isEmpty && pointInPolygon(coord, $0.coordinates) })
        if matched == nil || matched!.poblacion == 0 {
            matched = polygons
                .filter { $0.poblacion > 0 && !$0.cvegeo.isEmpty }
                .min(by: { distancia(coord, centroide($0)) < distancia(coord, centroide($1)) })
        }
        guard let p = matched, !agebs.contains(p.cvegeo) else { continue }
        agebs.insert(p.cvegeo)
        pobtot += p.poblacion; pobFem += p.pobFem; pobMas += p.pobMas; p18ymas += p.p18ymas
        pob0a14 += p.pob0a14; pob15a64 += p.pob15a64; p60ymas += p.p60ymas
        dem.p0a5F  += p.p0a2F  + p.p3a5F;  dem.p0a5M  += p.p0a2M  + p.p3a5M
        dem.p6a11F += p.p6a11F;             dem.p6a11M += p.p6a11M
        dem.p12a17F += p.p12a14F + p.p15a17F; dem.p12a17M += p.p12a14M + p.p15a17M
        dem.p18a24F += p.p18a24F;           dem.p18a24M += p.p18a24M
        dem.p25a59F += max(0, p.pobFem - p.p0a2F - p.p3a5F - p.p6a11F - p.p12a14F - p.p15a17F - p.p18a24F - p.p60ymasF)
        dem.p25a59M += max(0, p.pobMas - p.p0a2M - p.p3a5M - p.p6a11M - p.p12a14M - p.p15a17M - p.p18a24M - p.p60ymasM)
        dem.p60masF += p.p60ymasF;          dem.p60masM += p.p60ymasM
        dem.pob0a14 += p.pob0a14; dem.pob15a64 += p.pob15a64; dem.p60ymas += p.p60ymas
        dem.psinder += p.psinder; dem.pderSS += p.pderSS
        dem.vphInter += p.vphInter; dem.vphSinInter += p.vphSinInter; dem.tvivhab += p.tvivhab
    }
    return AlcanceDetalle(pobtot: pobtot, pobFem: pobFem, pobMas: pobMas, p18ymas: p18ymas,
                          pob0a14: pob0a14, pob15a64: pob15a64, p60ymas: p60ymas, dem: dem)
}

private func centroide(_ polygon: GeoPolygon) -> CLLocationCoordinate2D {
    let n = Double(polygon.coordinates.count)
    guard n > 0 else { return CLLocationCoordinate2D() }
    let lat = polygon.coordinates.reduce(0) { $0 + $1.latitude } / n
    let lng = polygon.coordinates.reduce(0) { $0 + $1.longitude } / n
    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
}

private func distancia(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let dlat = a.latitude - b.latitude
    let dlng = a.longitude - b.longitude
    return dlat * dlat + dlng * dlng
}
