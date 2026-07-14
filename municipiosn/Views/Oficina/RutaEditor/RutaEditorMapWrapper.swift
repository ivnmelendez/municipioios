import SwiftUI
import MapKit

// MARK: - Annotation

fileprivate final class EditorAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let estructuraId: UUID

    init(estructuraId: UUID, coordinate: CLLocationCoordinate2D) {
        self.estructuraId = estructuraId
        self.coordinate = coordinate
    }
}

// MARK: - Annotation view (no pulse needed)

fileprivate final class EditorAnnotationView: MKAnnotationView {
    static let reuseID = "editor_estructura"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        centerOffset = .zero
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Map controller

final class EditorMapController {
    weak var mapView: MKMapView?

    func centerOn(_ coord: CLLocationCoordinate2D) {
        mapView?.setRegion(
            MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
            ),
            animated: true
        )
    }

    func resetRegion() {
        mapView?.setRegion(municipioRegion, animated: true)
    }
}

private let municipioRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 25.7367, longitude: -100.2726),
    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
)

// MARK: - Wrapper

struct RutaEditorMapWrapper: UIViewRepresentable {
    let coloniasPolygons: [GeoPolygon]
    let municipioPolygons: [GeoPolygon]
    let anotaciones: [EditorAnotacion]
    let pinInfos: [UUID: PinInfo]
    let ordenes: [UUID: Int]        // estructuraId → 1-based stop number (active route only)
    let pinInfosVersion: Int
    let mapController: EditorMapController
    let onTapPin: (UUID) -> Void

    struct EditorAnotacion: Identifiable {
        let id: UUID                          // estructuraId
        let coordinate: CLLocationCoordinate2D
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapPin: onTapPin)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        mapController.mapView = mapView
        DispatchQueue.main.async {
            mapView.setRegion(municipioRegion, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Overlays (load once)
        if context.coordinator.loadedPolygonCount != coloniasPolygons.count {
            context.coordinator.loadedPolygonCount = coloniasPolygons.count
            mapView.removeOverlays(mapView.overlays)
            for poly in coloniasPolygons {
                let mk = MKPolygon(coordinates: poly.coordinates, count: poly.coordinates.count)
                mk.title = poly.cvegeo
                mapView.addOverlay(mk, level: .aboveRoads)
            }
            for poly in municipioPolygons {
                let mk = MKPolygon(coordinates: poly.coordinates, count: poly.coordinates.count)
                mk.title = "__municipio__"
                mapView.addOverlay(mk, level: .aboveRoads)
            }
        }

        // Pins (diff)
        let currentIds = Set(mapView.annotations.compactMap { ($0 as? EditorAnnotation)?.estructuraId })
        let newIds = Set(anotaciones.map { $0.id })

        if currentIds != newIds {
            let toRemove = mapView.annotations.filter {
                guard let a = $0 as? EditorAnnotation else { return false }
                return !newIds.contains(a.estructuraId)
            }
            let toAdd = anotaciones.filter { !currentIds.contains($0.id) }
                .map { EditorAnnotation(estructuraId: $0.id, coordinate: $0.coordinate) }
            mapView.removeAnnotations(toRemove)
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        // Refresh pin images when route selection or assignments change
        if context.coordinator.loadedPinVersion != pinInfosVersion {
            context.coordinator.loadedPinVersion = pinInfosVersion
            context.coordinator.pinInfos = pinInfos
            context.coordinator.ordenes = ordenes
            context.coordinator.markerCache.removeAll()
            for annotation in mapView.annotations {
                guard let ann = annotation as? EditorAnnotation,
                      let view = mapView.view(for: annotation) else { continue }
                view.image = context.coordinator.markerImage(for: ann)
            }
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let onTapPin: (UUID) -> Void
        var pinInfos: [UUID: PinInfo] = [:]
        var ordenes: [UUID: Int] = [:]
        var loadedPolygonCount = 0
        var loadedPinVersion = -1
        var markerCache: [String: UIImage] = [:]

        init(onTapPin: @escaping (UUID) -> Void) {
            self.onTapPin = onTapPin
        }

        fileprivate func markerImage(for annotation: EditorAnnotation) -> UIImage {
            let info = pinInfos[annotation.estructuraId]
            let color = info?.color ?? .systemGray3
            let opacity = info?.opacity ?? 0.5
            let numero = ordenes[annotation.estructuraId]
            let key = "\(colorHex(color))_\(Int(opacity * 100))_\(numero ?? -1)"
            if let cached = markerCache[key] { return cached }
            let image = renderMarker(color: color.withAlphaComponent(opacity), numero: numero)
            markerCache[key] = image
            return image
        }

        private func renderMarker(color: UIColor, numero: Int?) -> UIImage {
            let size: CGFloat = numero != nil ? 28 : 20
            let canvas = CGSize(width: size + 4, height: size + 4)
            return UIGraphicsImageRenderer(size: canvas).image { ctx in
                let rect = CGRect(x: 2, y: 2, width: size, height: size)
                ctx.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 1), blur: numero != nil ? 4 : 3,
                    color: UIColor.black.withAlphaComponent(0.3).cgColor
                )
                color.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.withAlphaComponent(0.9).setStroke()
                ctx.cgContext.setLineWidth(numero != nil ? 2.5 : 2)
                ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1.25, dy: 1.25))

                if let n = numero {
                    let text = "\(n)"
                    let fontSize: CGFloat = n >= 10 ? 10 : 13
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let attrStr = NSAttributedString(string: text, attributes: attrs)
                    let textSize = attrStr.size()
                    let textOrigin = CGPoint(
                        x: rect.midX - textSize.width / 2,
                        y: rect.midY - textSize.height / 2
                    )
                    attrStr.draw(at: textOrigin)
                }
            }
        }

        private func colorHex(_ color: UIColor) -> String {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            return String(format: "%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? EditorAnnotation else { return nil }
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: EditorAnnotationView.reuseID)
                as? EditorAnnotationView)
                ?? EditorAnnotationView(annotation: annotation, reuseIdentifier: EditorAnnotationView.reuseID)
            view.annotation = annotation
            view.image = markerImage(for: ann)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            guard let ann = annotation as? EditorAnnotation else { return }
            onTapPin(ann.estructuraId)
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            views.forEach { view in
                guard view.annotation is EditorAnnotation else { return }
                view.alpha = 0
                UIView.animate(springDuration: 0.3, bounce: 0) { view.alpha = 1 }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolygonRenderer(polygon: polygon)
            if polygon.title == "__municipio__" {
                renderer.strokeColor = UIColor(named: "Navy")
                renderer.lineWidth = 2.5
                renderer.fillColor = .clear
            } else {
                renderer.fillColor = UIColor(named: "Navy")?.withAlphaComponent(0.08)
                renderer.strokeColor = UIColor(named: "Navy")?.withAlphaComponent(0.35)
                renderer.lineWidth = 1
            }
            return renderer
        }
    }
}
