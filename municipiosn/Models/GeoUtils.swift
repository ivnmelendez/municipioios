import MapKit

struct GeoPolygon: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let cvegeo: String
    let poblacion: Int
}

func loadGeoPolygons(named filename: String) -> [GeoPolygon] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson"),
          let data = try? Data(contentsOf: url),
          let features = try? MKGeoJSONDecoder().decode(data) else { return [] }

    return features.compactMap { $0 as? MKGeoJSONFeature }.flatMap { feature in
        let props = (try? JSONSerialization.jsonObject(with: feature.properties ?? Data())) as? [String: Any]
        let cvegeo = props?["CVEGEO"] as? String ?? ""
        let poblacion = props?["POBTOT"] as? Int ?? 0
        return feature.geometry.compactMap { $0 as? MKPolygon }.map { polygon in
            let coords = (0..<polygon.pointCount).map { polygon.points()[$0].coordinate }
            return GeoPolygon(coordinates: coords, cvegeo: cvegeo, poblacion: poblacion)
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
    var agebs = Set<String>()
    var total = 0
    for polygon in polygons where !polygon.cvegeo.isEmpty && polygon.poblacion > 0 {
        guard !agebs.contains(polygon.cvegeo) else { continue }
        for coord in coordenadas {
            if pointInPolygon(coord, polygon.coordinates) {
                agebs.insert(polygon.cvegeo)
                total += polygon.poblacion
                break
            }
        }
    }
    return total
}
