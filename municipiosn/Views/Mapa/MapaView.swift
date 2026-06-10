import SwiftUI
import MapKit
import CoreLocation

// MARK: - Models

struct EstructuraAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let estado: EstadoEstructura
    let numero: String
    let estructura: EstructuraConParque
}

// MARK: - Helpers

private let municipioRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 25.7367, longitude: -100.2726),
    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
)

private func computarColoniasConEstructuras(
    polygons: [GeoPolygon],
    estructuras: [EstructuraConParque]
) -> Set<String> {
    let coords = estructuras.compactMap { e -> CLLocationCoordinate2D? in
        guard let lat = e.lat, let lng = e.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    var result = Set<String>()
    for polygon in polygons where !polygon.cvegeo.isEmpty {
        for coord in coords {
            if pointInPolygon(coord, polygon.coordinates) {
                result.insert(polygon.cvegeo)
                break
            }
        }
    }
    return result
}

private func computarColoniasConSemana(
    polygons: [GeoPolygon],
    estructuras: [EstructuraConParque],
    semanaMap: [UUID: RutaSemana]
) -> [String: String] {
    var result: [String: String] = [:]
    for e in estructuras {
        guard let lat = e.lat, let lng = e.lng,
              let semana = semanaMap[e.id] else { continue }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        for polygon in polygons where !polygon.cvegeo.isEmpty && result[polygon.cvegeo] == nil {
            if pointInPolygon(coord, polygon.coordinates) {
                result[polygon.cvegeo] = semana.color
            }
        }
    }
    return result
}

// MARK: - Exterior dim overlay (even-odd fill, winding-order independent)

private final class ExteriorDimOverlay: NSObject, MKOverlay {
    let boundingMapRect: MKMapRect = .world
    let coordinate = CLLocationCoordinate2D(latitude: 25.7367, longitude: -100.2726)
    let municipioPolygons: [GeoPolygon]
    init(_ polygons: [GeoPolygon]) { self.municipioPolygons = polygons }
}

private final class ExteriorDimRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? ExteriorDimOverlay else { return }
        context.addRect(rect(for: .world))
        for geoPolygon in overlay.municipioPolygons {
            let pts = geoPolygon.coordinates.map { point(for: MKMapPoint($0)) }
            guard let first = pts.first else { continue }
            context.move(to: first)
            pts.dropFirst().forEach { context.addLine(to: $0) }
            context.closePath()
        }
        context.setFillColor(UIColor.black.withAlphaComponent(0.10).cgColor)
        context.fillPath(using: .evenOdd)
    }
}

// MARK: - Map controller (bypasses SwiftUI state to avoid re-render flicker)

private final class MapController {
    weak var mapView: MKMapView?

    func centerOnUser() {
        mapView?.setUserTrackingMode(.follow, animated: true)
    }

    func resetRegion() {
        mapView?.setRegion(municipioRegion, animated: true)
    }

    func centerOn(_ coord: CLLocationCoordinate2D) {
        mapView?.setRegion(
            MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)),
            animated: true
        )
    }

    func updateRouteColors(mostrarRutas: Bool, colors: [String: String], tieneEstructuras: Set<String>) {
        guard let mapView else { return }
        for overlay in mapView.overlays {
            guard let polygon = overlay as? MKPolygon,
                  let renderer = mapView.renderer(for: overlay) as? MKPolygonRenderer,
                  polygon.title != "__municipio__" else { continue }
            let cvegeo = polygon.title ?? ""
            if mostrarRutas, let hexColor = colors[cvegeo], let color = UIColor(hex: hexColor) {
                renderer.fillColor = color.withAlphaComponent(0.20)
                renderer.strokeColor = color.withAlphaComponent(0.60)
                renderer.lineWidth = 1.5
            } else {
                let tiene = tieneEstructuras.contains(cvegeo)
                renderer.fillColor = UIColor(named: "Navy")?.withAlphaComponent(tiene ? 0.20 : 0.05)
                renderer.strokeColor = UIColor(named: "Navy")?.withAlphaComponent(tiene ? 0.55 : 0.25)
                renderer.lineWidth = 1
            }
            renderer.setNeedsDisplay()
        }
    }
}

// MARK: - MKAnnotation wrapper

private final class EstructuraMKAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let estructura: EstructuraConParque
    let estado: EstadoEstructura

    init(from a: EstructuraAnnotation) {
        self.coordinate = a.coordinate
        self.estructura = a.estructura
        self.estado = a.estado
    }
}

// MARK: - MapaView

struct MapaView: View {
    var mostrarCampanas: Bool = true
    var userId: UUID? = nil
    var campanas: [CampanaBasica] = []

    @State private var vm = MapaViewModel()
    @State private var coloniasPolygons: [GeoPolygon] = []
    @State private var municipioPolygons: [GeoPolygon] = []
    @State private var coloniasConEstructuras: Set<String> = []
    @State private var locationManager = CLLocationManager()
    @State private var busqueda = ""
    @State private var mapController = MapController()
    @FocusState private var searchFocused: Bool

    @State private var estructuraSemanaMap: [UUID: RutaSemana] = [:]
    @State private var coloniaSemanaColors: [String: String] = [:]
    @State private var mostrarRutas: Bool = false
    @State private var estructuraParaAccion: EstructuraConParque? = nil
    @State private var estructuraParaDano: EstructuraConParque? = nil

    private var anotaciones: [EstructuraAnnotation] {
        vm.estructuras.compactMap { e in
            guard let lat = e.lat, let lng = e.lng else { return nil }
            return EstructuraAnnotation(
                id: e.id,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                estado: e.estado,
                numero: e.numero,
                estructura: e
            )
        }
    }

    private var anotacionesFiltradas: [EstructuraAnnotation] {
        let q = busqueda.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return anotaciones }
        let ql = q.lowercased()
        return anotaciones.filter { a in
            a.numero.lowercased().contains(ql) ||
            a.estructura.parques?.nombre.lowercased().contains(ql) == true ||
            a.estructura.parques?.colonias?.nombre.lowercased().contains(ql) == true
        }
    }


    var body: some View {
        NavigationStack {
        ZStack(alignment: .bottom) {
            MKMapViewWrapper(
                coloniasPolygons: coloniasPolygons,
                municipioPolygons: municipioPolygons,
                coloniasConEstructuras: coloniasConEstructuras,
                coloniaSemanaColors: coloniaSemanaColors,
                mostrarRutas: mostrarRutas,
                anotaciones: anotacionesFiltradas,
                semanaMapVersion: estructuraSemanaMap.count,
                mapController: mapController,
                onSelect: { estructura in
                    Task { await vm.seleccionar(estructura) }
                }
            )
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    Button { searchFocused = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15, weight: .medium))
                            TextField("Buscar por SN, colonia o parque", text: $busqueda)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($searchFocused)
                                .onSubmit { searchFocused = false }
                            if !busqueda.isEmpty {
                                Button {
                                    busqueda = ""
                                    searchFocused = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)

                    if searchFocused && !busqueda.trimmingCharacters(in: .whitespaces).isEmpty {
                        BusquedaResultados(
                            resultados: anotacionesFiltradas,
                            onSeleccionar: { anotacion in
                                mapController.centerOn(anotacion.coordinate)
                                Task { await vm.seleccionar(anotacion.estructura) }
                                busqueda = ""
                                searchFocused = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            VStack(spacing: 8) {
                if !coloniaSemanaColors.isEmpty {
                    Button {
                        let newValue = !mostrarRutas
                        mostrarRutas = newValue
                        mapController.updateRouteColors(
                            mostrarRutas: newValue,
                            colors: coloniaSemanaColors,
                            tieneEstructuras: coloniasConEstructuras
                        )
                    } label: {
                        Image(systemName: "map")
                    }
                    .buttonStyle(.glass(.regular))
                    .controlSize(.large)
                    .buttonBorderShape(.circle)
                }

                Button {
                    locationManager.requestWhenInUseAuthorization()
                    mapController.centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color("MunicipioCyan"))
                }
                .buttonStyle(.glass(.regular))
                .controlSize(.large)
                .buttonBorderShape(.circle)

                Button {
                    mapController.resetRegion()
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color("Navy"))
                }
                .buttonStyle(.glass(.regular))
                .controlSize(.large)
                .buttonBorderShape(.circle)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(true)
            .transaction { $0.animation = nil }

            if vm.isLoading {
                HStack {
                    ProgressView()
                    Text("Cargando estructuras…")
                        .font(.caption)
                }
                .padding(12)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 100)
            }
        }
        .onTapGesture {
            searchFocused = false
        }
        .task {
            guard coloniasPolygons.isEmpty else { return }
            await vm.cargar()
            coloniasPolygons = loadGeoPolygons(named: "colonias_san_nicolas")
            municipioPolygons = loadGeoPolygons(named: "san_nicolas")
            coloniasConEstructuras = computarColoniasConEstructuras(
                polygons: coloniasPolygons,
                estructuras: vm.estructuras
            )
            estructuraSemanaMap = (try? await RutasService.shared.fetchEstructuraSemanaMap()) ?? [:]
            coloniaSemanaColors = computarColoniasConSemana(
                polygons: coloniasPolygons,
                estructuras: vm.estructuras,
                semanaMap: estructuraSemanaMap
            )
        }
        .sheet(isPresented: $vm.mostrarDetalle) {
            if let estructura = vm.estructuraSeleccionada {
                let semana = estructuraSemanaMap[estructura.id]
                EstructuraDetalleSheet(
                    estructura: estructura,
                    caras: vm.carasDetalle,
                    mostrarCampanas: mostrarCampanas,
                    onOk: (userId != nil && semana != nil) ? {
                        guard let uid = userId, let s = semana else { return }
                        Task {
                            try? await RutasService.shared.marcarRevision(
                                estructuraId: estructura.id,
                                rutaSemanaId: s.id,
                                userId: uid
                            )
                        }
                        vm.mostrarDetalle = false
                    } : nil,
                    onRegistrarCambio: userId != nil ? {
                        vm.mostrarDetalle = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            estructuraParaAccion = estructura
                        }
                    } : nil,
                    onReportarDano: userId != nil ? {
                        vm.mostrarDetalle = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            estructuraParaDano = estructura
                        }
                    } : nil
                )
            }
        }
        .sheet(item: $estructuraParaAccion) { estructura in
            RegistrarCoroplastView(
                estructura: estructura,
                campanas: campanas,
                userId: userId,
                rutaSemanaId: estructuraSemanaMap[estructura.id]?.id
            )
        }
        .sheet(item: $estructuraParaDano) { estructura in
            ReportarDanoView(
                estructura: estructura,
                userId: userId,
                rutaSemanaId: estructuraSemanaMap[estructura.id]?.id
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - UIViewRepresentable

private struct MKMapViewWrapper: UIViewRepresentable {
    let coloniasPolygons: [GeoPolygon]
    let municipioPolygons: [GeoPolygon]
    let coloniasConEstructuras: Set<String>
    let coloniaSemanaColors: [String: String]
    let mostrarRutas: Bool
    let anotaciones: [EstructuraAnnotation]
    let semanaMapVersion: Int
    let mapController: MapController
    let onSelect: (EstructuraConParque) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        mapController.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if !context.coordinator.initialRegionSet {
            context.coordinator.initialRegionSet = true
            DispatchQueue.main.async {
                mapView.setRegion(municipioRegion, animated: false)
            }
        }

        context.coordinator.coloniasConEstructuras = coloniasConEstructuras
        context.coordinator.coloniaSemanaColors = coloniaSemanaColors
        context.coordinator.mostrarRutas = mostrarRutas

        let needsOverlayReload = context.coordinator.loadedPolygonCount != coloniasPolygons.count
            || context.coordinator.loadedHighlightCount != coloniasConEstructuras.count
            || context.coordinator.loadedSemanaColorCount != coloniaSemanaColors.count

        if needsOverlayReload {
            context.coordinator.loadedPolygonCount = coloniasPolygons.count
            context.coordinator.loadedHighlightCount = coloniasConEstructuras.count
            context.coordinator.loadedSemanaColorCount = coloniaSemanaColors.count
            mapView.removeOverlays(mapView.overlays)

            // Exterior dim using even-odd renderer
            if !municipioPolygons.isEmpty {
                mapView.addOverlay(ExteriorDimOverlay(municipioPolygons), level: .aboveRoads)
            }

            for poly in coloniasPolygons {
                let mkPoly = MKPolygon(coordinates: poly.coordinates, count: poly.coordinates.count)
                mkPoly.title = poly.cvegeo
                mapView.addOverlay(mkPoly, level: .aboveRoads)
            }
            for poly in municipioPolygons {
                let mkPoly = MKPolygon(coordinates: poly.coordinates, count: poly.coordinates.count)
                mkPoly.title = "__municipio__"
                mapView.addOverlay(mkPoly, level: .aboveRoads)
            }

            if context.coordinator.isFirstLoad && !coloniasPolygons.isEmpty {
                context.coordinator.isFirstLoad = false
                mapView.alpha = 0
                UIView.animate(withDuration: 0.5, delay: 0.1, options: .curveEaseIn) {
                    mapView.alpha = 1
                }
            }
        }

        let currentIds = Set(mapView.annotations.compactMap { ($0 as? EstructuraMKAnnotation)?.estructura.id })
        let newIds = Set(anotaciones.map { $0.id })
        let semanaVersionChanged = context.coordinator.loadedSemanaVersion != semanaMapVersion
        if currentIds != newIds || semanaVersionChanged {
            context.coordinator.loadedSemanaVersion = semanaMapVersion
            mapView.removeAnnotations(mapView.annotations.filter { $0 is EstructuraMKAnnotation })
            mapView.addAnnotations(anotaciones.map { EstructuraMKAnnotation(from: $0) })
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let onSelect: (EstructuraConParque) -> Void
        var coloniasConEstructuras: Set<String> = []
        var coloniaSemanaColors: [String: String] = [:]
        var mostrarRutas: Bool = false
        var loadedPolygonCount = 0
        var loadedHighlightCount = 0
        var loadedSemanaVersion = -1
        var loadedSemanaColorCount = 0
        var isFirstLoad = true
        var initialRegionSet = false
        private var markerCache: [String: UIImage] = [:]

        init(onSelect: @escaping (EstructuraConParque) -> Void) {
            self.onSelect = onSelect
        }

        func markerImage(colorHex: String?) -> UIImage {
            let key = colorHex ?? "default"
            if let cached = markerCache[key] { return cached }
            let fillColor: UIColor
            if let hex = colorHex, let c = UIColor(hex: hex) {
                fillColor = c
            } else {
                fillColor = UIColor(named: "Navy") ?? .systemBlue
            }
            let image = Self.renderMarker(color: fillColor)
            markerCache[key] = image
            return image
        }

        private static func renderMarker(color: UIColor) -> UIImage {
            let size: CGFloat = 20
            let canvas = CGSize(width: size + 3, height: size + 3)
            return UIGraphicsImageRenderer(size: canvas).image { ctx in
                let rect = CGRect(x: 1.5, y: 1.5, width: size, height: size)
                ctx.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 2), blur: 3,
                    color: UIColor.black.withAlphaComponent(0.3).cgColor
                )
                color.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(2.5)
                ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1.25, dy: 1.25))
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let dimOverlay = overlay as? ExteriorDimOverlay {
                return ExteriorDimRenderer(overlay: dimOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolygonRenderer(polygon: polygon)
            if polygon.title == "__municipio__" {
                renderer.strokeColor = UIColor(named: "Navy")
                renderer.lineWidth = 2.5
                renderer.fillColor = .clear
            } else {
                let cvegeo = polygon.title ?? ""
                if mostrarRutas,
                   let hexColor = coloniaSemanaColors[cvegeo],
                   let color = UIColor(hex: hexColor) {
                    renderer.fillColor = color.withAlphaComponent(0.20)
                    renderer.strokeColor = color.withAlphaComponent(0.60)
                    renderer.lineWidth = 1.5
                } else {
                    let tieneEstructuras = coloniasConEstructuras.contains(cvegeo)
                    renderer.fillColor = UIColor(named: "Navy")?.withAlphaComponent(tieneEstructuras ? 0.20 : 0.05)
                    renderer.strokeColor = UIColor(named: "Navy")?.withAlphaComponent(tieneEstructuras ? 0.55 : 0.25)
                    renderer.lineWidth = 1
                }
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is EstructuraMKAnnotation else { return nil }
            let id = "estructura"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.image = markerImage(colorHex: nil)
            return view
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            views.forEach { view in
                guard view.annotation is EstructuraMKAnnotation else { return }
                view.alpha = 0
                UIView.animate(springDuration: 0.35, bounce: 0) {
                    view.alpha = 1
                }
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            guard let ann = annotation as? EstructuraMKAnnotation else { return }
            onSelect(ann.estructura)
        }
    }
}

// MARK: - UIColor hex

private extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        switch hex.count {
        case 6:
            self.init(red: Double(int >> 16) / 255, green: Double(int >> 8 & 0xFF) / 255, blue: Double(int & 0xFF) / 255, alpha: 1)
        default:
            return nil
        }
    }
}

// MARK: - Search UI

private struct BusquedaResultRow: View {
    let anotacion: EstructuraAnnotation
    let onTap: () -> Void

    private var subtitulo: String {
        guard let parque = anotacion.estructura.parques else { return "" }
        return [parque.colonias?.nombre, parque.nombre]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(anotacion.numero)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if !subtitulo.isEmpty {
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glass(.regular))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .controlSize(.regular)
        .tint(.primary)
    }
}

private struct BusquedaResultados: View {
    let resultados: [EstructuraAnnotation]
    let onSeleccionar: (EstructuraAnnotation) -> Void

    var body: some View {
        if resultados.isEmpty {
            Button {} label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("Sin resultados")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass(.regular))
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .disabled(true)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(resultados) { anotacion in
                        BusquedaResultRow(anotacion: anotacion) {
                            onSeleccionar(anotacion)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            .frame(maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Map marker

struct EstructuraMarker: View {
    let estado: EstadoEstructura

    var body: some View {
        Circle()
            .fill(Color("Navy"))
            .frame(width: 20, height: 20)
            .overlay {
                Circle().strokeBorder(.white, lineWidth: 2.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Detail sheet

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
    let titulo: String
}

struct EstructuraDetalleSheet: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let estructura: EstructuraConParque
    let caras: [CaraDetalle]
    var mostrarCampanas: Bool = true
    var onOk: (() -> Void)? = nil
    var onRegistrarCambio: (() -> Void)? = nil
    var onReportarDano: (() -> Void)? = nil
    @State private var fotoFullscreen: IdentifiableURL?
    @State private var contentHeight: CGFloat = 420

    private func abrirGoogleMaps(lat: Double, lng: Double) {
        let gm = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")!
        let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving")!
        UIApplication.shared.open(gm) { success in
            if !success { UIApplication.shared.open(web) }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = sizeClass == .regular && geo.size.width > geo.size.height
            if isLandscape { landscapeLayout } else { portraitLayout }
        }
        .presentationDetents(sizeClass == .regular ? [.large] : [.height(contentHeight)])
        .presentationSizing(.page)
        .presentationDragIndicator(sizeClass == .regular ? .visible : .hidden)
        .presentationContentInteraction(.scrolls)
        .fullScreenCover(item: $fotoFullscreen) { item in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
        }
    }

    // MARK: Layouts

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            fotoView(fixedHeight: nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    headerView
                    Divider()
                    infoView
                    if mostrarCampanas && !caras.isEmpty { Divider(); campanasView }
                    if let n = estructura.notas, !n.isEmpty { Divider(); notasView(n) }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var portraitLayout: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                Divider()
                fotoView(fixedHeight: sizeClass == .regular ? 680 : 380)
                infoView
                if mostrarCampanas && !caras.isEmpty { Divider(); campanasView }
                if let n = estructura.notas, !n.isEmpty { Divider(); notasView(n) }
            }
            .frame(maxWidth: .infinity)
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { contentHeight = min(geo.size.height + 60, 700) }
                    .onChange(of: geo.size.height) { _, h in contentHeight = min(h + 60, 700) }
            })
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Sections

    private var headerView: some View {
        HStack(spacing: 12) {
            Text(estructura.numero)
                .font(.headline)
                .layoutPriority(1)
            Spacer(minLength: 8)
            EstadoBadge(estado: estructura.estado)
                .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func fotoView(fixedHeight: CGFloat?) -> some View {
        if let fotoUrl = estructura.fotoUrl, let url = URL(string: fotoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    Button {
                        fotoFullscreen = IdentifiableURL(url: url, titulo: estructura.numero)
                    } label: {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: fixedHeight)
                            .frame(maxHeight: fixedHeight == nil ? .infinity : nil)
                            .clipped()
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.4), in: Circle())
                                    .padding(10)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                case .failure:
                    EmptyView()
                default:
                    Color.secondary.opacity(0.1)
                        .frame(height: fixedHeight)
                        .frame(maxHeight: fixedHeight == nil ? .infinity : nil)
                        .overlay { ProgressView() }
                }
            }
            if fixedHeight != nil { Divider() }
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ubicación")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color("TextMuted"))
                Spacer()
                if let lat = estructura.lat, let lng = estructura.lng {
                    Button { abrirGoogleMaps(lat: lat, lng: lng) } label: {
                        GoogleMapsCircleButton()
                    }
                    .buttonStyle(.plain)
                }
            }
            if let colonia = estructura.parques?.colonias {
                Label(colonia.nombre, systemImage: "map").font(.subheadline)
            } else {
                Label("Sin colonia asignada", systemImage: "map")
                    .font(.subheadline).foregroundStyle(Color("TextMuted"))
            }
            if let parque = estructura.parques {
                Label(parque.nombre, systemImage: "tree")
                    .font(.subheadline).foregroundStyle(Color("TextMuted"))
            } else {
                Label("Sin parque asignado", systemImage: "tree")
                    .font(.subheadline).foregroundStyle(Color("TextMuted"))
            }
            if onOk != nil || onRegistrarCambio != nil || onReportarDano != nil {
                Divider().padding(.top, 8)
                if let ok = onOk {
                    Button { ok() } label: {
                        Label("Está bien", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                }
                if let registrar = onRegistrarCambio {
                    Button { registrar() } label: {
                        Label("Registrar coroplast", systemImage: "square.and.pencil")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("MunicipioCyan"))
                    .controlSize(.large)
                }
                if let reportar = onReportarDano {
                    Button { reportar() } label: {
                        Label("Reportar daño", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, sizeClass == .regular ? 40 : 16)
    }

    private var campanasView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Campañas activas")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("TextMuted"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            ForEach(caras.sorted(by: { $0.tipo < $1.tipo })) { cara in
                CampanaRow(cara: cara, onTapFoto: { url in
                    fotoFullscreen = IdentifiableURL(url: url, titulo: "Campaña Cara \(cara.tipo)")
                })
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private func notasView(_ notas: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("TextMuted"))
            Text(notas).font(.body)
        }
        .padding(20)
    }
}

struct FotoFullscreenView: View {
    let url: URL
    let titulo: String
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: Image?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear { loadedImage = image }
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo.slash")
                                .font(.largeTitle)
                            Text("No se pudo cargar la imagen")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    default:
                        ProgressView().tint(.white)
                    }
                }
            }
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.title3)
                    }
                }
            }
        }
    }
}

struct CampanaRow: View {
    let cara: CaraDetalle
    var onTapFoto: ((URL) -> Void)? = nil

    var fotoURL: URL? {
        if let s = cara.fotoCampana ?? cara.campana?.fotoUrl { return URL(string: s) }
        return nil
    }

    var body: some View {
        if let campana = cara.campana {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Campaña Cara \(cara.tipo)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("Navy"))
                    Spacer()
                    Text(campana.nombre)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("MunicipioCyan"))
                        .multilineTextAlignment(.trailing)
                }

                if let url = fotoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            Button {
                                onTapFoto?(url)
                            } label: {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 160)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(.black.opacity(0.4), in: Circle())
                                            .padding(8)
                                    }
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        case .failure:
                            EmptyView()
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 160)
                                .overlay { ProgressView() }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } else {
            HStack {
                Text("Campaña Cara \(cara.tipo)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("Navy"))
                Spacer()
                Text("Sin campaña")
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
        }
    }
}

// MARK: - Google Maps icon

private struct GoogleMapsCircleButton: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                .frame(width: 22, height: 22)
                .overlay {
                    Text("G")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            Text("Maps")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(red: 0.26, green: 0.52, blue: 0.96).opacity(0.1), in: Capsule())
    }
}

