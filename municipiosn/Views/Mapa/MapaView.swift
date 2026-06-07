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

// MARK: - Map command bridge

private enum MapCommand {
    case centerOnUser
    case resetRegion
    case centerOn(CLLocationCoordinate2D)
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
    @State private var vm = MapaViewModel()
    @State private var coloniasPolygons: [GeoPolygon] = []
    @State private var municipioPolygons: [GeoPolygon] = []
    @State private var coloniasConEstructuras: Set<String> = []
    @State private var locationManager = CLLocationManager()
    @State private var busqueda = ""
    @State private var pendingCommand: MapCommand? = nil
    @FocusState private var searchFocused: Bool

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
        ZStack(alignment: .bottom) {
            MKMapViewWrapper(
                coloniasPolygons: coloniasPolygons,
                municipioPolygons: municipioPolygons,
                coloniasConEstructuras: coloniasConEstructuras,
                anotaciones: anotacionesFiltradas,
                pendingCommand: $pendingCommand,
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
                                pendingCommand = .centerOn(anotacion.coordinate)
                                Task { await vm.seleccionar(anotacion.estructura) }
                                busqueda = ""
                                searchFocused = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 8) {
                    Button {
                        locationManager.requestWhenInUseAuthorization()
                        pendingCommand = .centerOnUser
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color("MunicipioCyan"))
                    }
                    .buttonStyle(.glass(.regular))
                    .controlSize(.large)
                    .buttonBorderShape(.circle)

                    Button {
                        pendingCommand = .resetRegion
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
            }

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
        }
        .sheet(isPresented: $vm.mostrarDetalle) {
            if let estructura = vm.estructuraSeleccionada {
                EstructuraDetalleSheet(
                    estructura: estructura,
                    caras: vm.carasDetalle
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - UIViewRepresentable

private struct MKMapViewWrapper: UIViewRepresentable {
    let coloniasPolygons: [GeoPolygon]
    let municipioPolygons: [GeoPolygon]
    let coloniasConEstructuras: Set<String>
    let anotaciones: [EstructuraAnnotation]
    @Binding var pendingCommand: MapCommand?
    let onSelect: (EstructuraConParque) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Defer initial region to next run loop so SwiftUI layout finishes first
        if !context.coordinator.initialRegionSet {
            context.coordinator.initialRegionSet = true
            DispatchQueue.main.async {
                mapView.setRegion(municipioRegion, animated: false)
            }
        }

        // Handle imperative commands
        if let cmd = pendingCommand {
            switch cmd {
            case .centerOnUser:
                mapView.setUserTrackingMode(.follow, animated: true)
            case .resetRegion:
                mapView.setRegion(municipioRegion, animated: true)
            case .centerOn(let coord):
                mapView.setRegion(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                    ),
                    animated: true
                )
            }
            DispatchQueue.main.async { pendingCommand = nil }
        }

        // Keep coordinator in sync for renderers
        context.coordinator.coloniasConEstructuras = coloniasConEstructuras

        // Reload overlays when polygon data or highlight data changes
        let needsOverlayReload = context.coordinator.loadedPolygonCount != coloniasPolygons.count
            || context.coordinator.loadedHighlightCount != coloniasConEstructuras.count

        if needsOverlayReload {
            context.coordinator.loadedPolygonCount = coloniasPolygons.count
            context.coordinator.loadedHighlightCount = coloniasConEstructuras.count
            mapView.removeOverlays(mapView.overlays)

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

            // Fade in on first load
            if context.coordinator.isFirstLoad && !coloniasPolygons.isEmpty {
                context.coordinator.isFirstLoad = false
                mapView.alpha = 0
                UIView.animate(withDuration: 0.5, delay: 0.1, options: .curveEaseIn) {
                    mapView.alpha = 1
                }
            }
        }

        // Sync annotations (handles search filtering too)
        let currentIds = Set(mapView.annotations.compactMap { ($0 as? EstructuraMKAnnotation)?.estructura.id })
        let newIds = Set(anotaciones.map { $0.id })
        if currentIds != newIds {
            mapView.removeAnnotations(mapView.annotations.filter { $0 is EstructuraMKAnnotation })
            mapView.addAnnotations(anotaciones.map { EstructuraMKAnnotation(from: $0) })
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let onSelect: (EstructuraConParque) -> Void
        var coloniasConEstructuras: Set<String> = []
        var loadedPolygonCount = 0
        var loadedHighlightCount = 0
        var isFirstLoad = true
        var initialRegionSet = false

        private static let markerImage: UIImage = {
            let size: CGFloat = 20
            let canvas = CGSize(width: size + 3, height: size + 3)
            return UIGraphicsImageRenderer(size: canvas).image { ctx in
                let rect = CGRect(x: 1.5, y: 1.5, width: size, height: size)
                ctx.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 2), blur: 3,
                    color: UIColor.black.withAlphaComponent(0.3).cgColor
                )
                UIColor(named: "Navy")?.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(2.5)
                ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1.25, dy: 1.25))
            }
        }()

        init(onSelect: @escaping (EstructuraConParque) -> Void) {
            self.onSelect = onSelect
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
                let tieneEstructuras = coloniasConEstructuras.contains(polygon.title ?? "")
                renderer.fillColor = UIColor(named: "Navy")?.withAlphaComponent(tieneEstructuras ? 0.18 : 0.04)
                renderer.strokeColor = UIColor(named: "Navy")?.withAlphaComponent(tieneEstructuras ? 0.55 : 0.3)
                renderer.lineWidth = 1
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is EstructuraMKAnnotation else { return nil }
            let id = "estructura"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.image = Self.markerImage
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            guard let ann = annotation as? EstructuraMKAnnotation else { return }
            onSelect(ann.estructura)
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

    private var visibles: [EstructuraAnnotation] { Array(resultados.prefix(8)) }

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
            VStack(spacing: 6) {
                ForEach(visibles) { anotacion in
                    BusquedaResultRow(anotacion: anotacion) {
                        onSeleccionar(anotacion)
                    }
                }
            }
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

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
    let titulo: String
}

struct EstructuraDetalleSheet: View {
    let estructura: EstructuraConParque
    let caras: [CaraDetalle]

    @State private var fotoFullscreen: IdentifiableURL?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                // Compact header — visible at small detent
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

                Divider()

                // Foto estructura
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
                                    .frame(height: 240)
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
                                .frame(height: 240)
                                .overlay { ProgressView() }
                        }
                    }

                    Divider()
                }

                // Ubicación completa
                if let parque = estructura.parques {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ubicación")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        if let colonia = parque.colonias {
                            Label(colonia.nombre, systemImage: "map")
                                .font(.subheadline)
                        }
                        Label(parque.nombre, systemImage: "tree")
                            .font(.subheadline)
                            .foregroundStyle(Color("TextMuted"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    Divider()
                }

                // Campañas
                if !caras.isEmpty {
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

                    Divider()
                }

                // Notas
                if let notas = estructura.notas, !notas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notas")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color("TextMuted"))
                        Text(notas)
                            .font(.body)
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationContentInteraction(.resizes)
        .presentationDragIndicator(.visible)
        .fullScreenCover(item: $fotoFullscreen) { item in
            FotoFullscreenView(url: item.url, titulo: item.titulo)
        }
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
