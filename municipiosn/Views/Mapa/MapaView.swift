import SwiftUI
import MapKit
import CoreLocation

struct EstructuraAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let estado: EstadoEstructura
    let numero: String
    let estructura: EstructuraConParque
}

struct GeoPolygon: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
}

private func loadGeoPolygons(named filename: String) -> [GeoPolygon] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson"),
          let data = try? Data(contentsOf: url),
          let features = try? MKGeoJSONDecoder().decode(data) else { return [] }

    return features.compactMap { $0 as? MKGeoJSONFeature }.flatMap { feature in
        feature.geometry.compactMap { $0 as? MKPolygon }.map { polygon in
            let coords = (0..<polygon.pointCount).map { polygon.points()[$0].coordinate }
            return GeoPolygon(coordinates: coords)
        }
    }
}

struct MapaView: View {
    @State private var vm = MapaViewModel()
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.7327, longitude: -100.2726),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var coloniasPolygons: [GeoPolygon] = []
    @State private var municipioPolygons: [GeoPolygon] = []
    @State private var locationManager = CLLocationManager()
    @State private var busqueda = ""
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

    private static let municipioRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.7327, longitude: -100.2726),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
                Map(position: $mapCameraPosition) {
                    ForEach(coloniasPolygons) { poly in
                        MapPolygon(coordinates: poly.coordinates)
                            .foregroundStyle(Color("Navy").opacity(0.06))
                            .stroke(Color("Navy").opacity(0.4), lineWidth: 1)
                    }
                    ForEach(municipioPolygons) { poly in
                        MapPolygon(coordinates: poly.coordinates)
                            .foregroundStyle(.clear)
                            .stroke(Color("Navy"), lineWidth: 2.5)
                    }
                    UserAnnotation()
                    ForEach(anotacionesFiltradas) { anotacion in
                        Annotation("", coordinate: anotacion.coordinate) {
                            EstructuraMarker(estado: anotacion.estado)
                                .onTapGesture {
                                    searchFocused = false
                                    busqueda = ""
                                    Task { await vm.seleccionar(anotacion.estructura) }
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15, weight: .medium))
                            TextField("Buscar por SN, colonia o parque", text: $busqueda)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($searchFocused)
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .glassEffect(.regular, in: Capsule())

                        if !busqueda.trimmingCharacters(in: .whitespaces).isEmpty {
                            BusquedaResultados(
                                resultados: anotacionesFiltradas,
                                onSeleccionar: { anotacion in
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        mapCameraPosition = .region(MKCoordinateRegion(
                                            center: anotacion.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                                        ))
                                    }
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
                            withAnimation(.easeInOut(duration: 0.5)) {
                                mapCameraPosition = .userLocation(fallback: .region(Self.municipioRegion))
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .foregroundStyle(Color("MunicipioCyan"))
                        }
                        .buttonStyle(.glass(.regular))
                        .controlSize(.large)
                        .buttonBorderShape(.circle)

                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                mapCameraPosition = .region(Self.municipioRegion)
                            }
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
                await vm.cargar()
                coloniasPolygons = loadGeoPolygons(named: "colonias_san_nicolas")
                municipioPolygons = loadGeoPolygons(named: "san_nicolas")
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
            HStack(spacing: 12) {
                EstructuraMarker(estado: anotacion.estado)
                    .scaleEffect(0.7)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(anotacion.numero)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !subtitulo.isEmpty {
                        Text(subtitulo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BusquedaResultados: View {
    let resultados: [EstructuraAnnotation]
    let onSeleccionar: (EstructuraAnnotation) -> Void

    private var visibles: [EstructuraAnnotation] { Array(resultados.prefix(8)) }

    var body: some View {
        if resultados.isEmpty {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Sin resultados")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(visibles.enumerated()), id: \.element.id) { index, anotacion in
                    BusquedaResultRow(anotacion: anotacion) {
                        onSeleccionar(anotacion)
                    }
                    if index < visibles.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

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
                    Button {
                        dismiss()
                    } label: {
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
