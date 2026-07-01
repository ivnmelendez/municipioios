import MapKit

struct GeoPolygon: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let cvegeo: String
    let poblacion: Int
    let pobFem: Int
    let pobMas: Int
    let p18ymas: Int
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
        let poblacion = props?["POBTOT"] as? Int ?? 0
        let pobFem   = props?["POBFEM"]   as? Int ?? 0
        let pobMas   = props?["POBMAS"]   as? Int ?? 0
        let p18ymas  = props?["P_18YMAS"] as? Int ?? 0
        return feature.geometry.compactMap { $0 as? MKPolygon }.map { polygon in
            let coords = (0..<polygon.pointCount).map { polygon.points()[$0].coordinate }
            return GeoPolygon(coordinates: coords, cvegeo: cvegeo, poblacion: poblacion,
                              pobFem: pobFem, pobMas: pobMas, p18ymas: p18ymas)
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
}

func alcanceDetallado(polygons: [GeoPolygon], coordenadas: [CLLocationCoordinate2D]) -> AlcanceDetalle {
    var agebs = Set<String>()
    var pobtot = 0; var pobFem = 0; var pobMas = 0; var p18ymas = 0

    for coord in coordenadas {
        // Find the AGEB this coordinate falls in
        var matched = polygons.first(where: { !$0.cvegeo.isEmpty && pointInPolygon(coord, $0.coordinates) })

        // If matched AGEB has 0 population, fallback to nearest AGEB with population
        if matched == nil || matched!.poblacion == 0 {
            matched = polygons
                .filter { $0.poblacion > 0 && !$0.cvegeo.isEmpty }
                .min(by: { distancia(coord, centroide($0)) < distancia(coord, centroide($1)) })
        }

        guard let ageb = matched, !agebs.contains(ageb.cvegeo) else { continue }
        agebs.insert(ageb.cvegeo)
        pobtot  += ageb.poblacion
        pobFem  += ageb.pobFem
        pobMas  += ageb.pobMas
        p18ymas += ageb.p18ymas
    }

    return AlcanceDetalle(pobtot: pobtot, pobFem: pobFem, pobMas: pobMas, p18ymas: p18ymas)
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
