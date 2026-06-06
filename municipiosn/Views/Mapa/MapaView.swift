import SwiftUI
import MapKit

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

    private static let municipioRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.7327, longitude: -100.2726),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationStack {
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
                    ForEach(anotaciones) { anotacion in
                        Annotation(anotacion.numero, coordinate: anotacion.coordinate) {
                            EstructuraMarker(estado: anotacion.estado)
                                .onTapGesture {
                                    Task { await vm.seleccionar(anotacion.estructura) }
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            mapCameraPosition = .region(Self.municipioRegion)
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color("Navy"))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.trailing, 12)
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
            .task {
                await vm.cargar()
                coloniasPolygons = loadGeoPolygons(named: "colonias_san_nicolas")
                municipioPolygons = loadGeoPolygons(named: "san_nicolas")
            }
            .sheet(isPresented: $vm.mostrarDetalle) {
                if let estructura = vm.estructuraSeleccionada {
                    EstructuraDetalleSheet(
                        estructura: estructura,
                        caras: vm.carasSeleccionadas,
                        campanaA: vm.campanaCaraA,
                        campanaB: vm.campanaCaraB
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

struct EstructuraMarker: View {
    let estado: EstadoEstructura

    var body: some View {
        ZStack {
            Circle()
                .fill(estado.color)
                .frame(width: 28, height: 28)
            Image(systemName: estado.icono)
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
        .shadow(color: estado.color.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

struct EstructuraDetalleSheet: View {
    let estructura: EstructuraConParque
    let caras: [Cara]
    let campanaA: Campana?
    let campanaB: Campana?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Número", value: estructura.numero)
                    if let local = estructura.numeroLocal {
                        LabeledContent("Número local", value: local)
                    }
                    HStack {
                        Text("Estado")
                        Spacer()
                        EstadoBadge(estado: estructura.estado)
                    }
                    if let parque = estructura.parques {
                        LabeledContent("Parque", value: parque.nombre)
                        if let colonia = parque.colonias {
                            LabeledContent("Colonia", value: colonia.nombre)
                        }
                    }
                } header: {
                    Text("Información")
                }

                Section {
                    CampanaRow(tipo: "A", campana: campanaA)
                    CampanaRow(tipo: "B", campana: campanaB)
                } header: {
                    Text("Campañas activas")
                }

                if let notas = estructura.notas, !notas.isEmpty {
                    Section("Notas") {
                        Text(notas)
                            .font(.body)
                            .foregroundStyle(Color("TextMuted"))
                    }
                }
            }
            .navigationTitle(estructura.numero)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct CampanaRow: View {
    let tipo: String
    let campana: Campana?

    var body: some View {
        HStack {
            Label("Cara \(tipo)", systemImage: "rectangle.portrait.fill")
                .foregroundStyle(Color("Navy"))
            Spacer()
            if let campana {
                Text(campana.nombre)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color("MunicipioCyan"))
                    .multilineTextAlignment(.trailing)
            } else {
                Text("Sin campaña")
                    .font(.caption)
                    .foregroundStyle(Color("TextMuted"))
            }
        }
    }
}
