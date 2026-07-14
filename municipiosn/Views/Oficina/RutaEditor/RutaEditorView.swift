import SwiftUI
import MapKit

struct RutaEditorView: View {
    @State private var vm = RutaEditorViewModel()
    @State private var coloniasPolygons: [GeoPolygon] = []
    @State private var municipioPolygons: [GeoPolygon] = []
    @State private var mapController = EditorMapController()
    @State private var modoEdicion = false

    private var anotaciones: [RutaEditorMapWrapper.EditorAnotacion] {
        vm.todasEstructuras.compactMap { e in
            guard let lat = e.lat, let lng = e.lng else { return nil }
            return .init(id: e.id, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
    }

    private var ordenesActivos: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: vm.itemsActivos.enumerated().map { i, item in
            (item.estructura.id, i + 1)
        })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RutaEditorMapWrapper(
                coloniasPolygons: coloniasPolygons,
                municipioPolygons: municipioPolygons,
                anotaciones: anotaciones,
                pinInfos: vm.pinInfos,
                ordenes: ordenesActivos,
                pinInfosVersion: vm.pinInfosVersion,
                mapController: mapController,
                onTapPin: { id in vm.tapPin(estructuraId: id) }
            )
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                Group {
                    if vm.cargando {
                        ProgressView("Cargando rutas…")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                    } else if !vm.semanas.isEmpty {
                        RutaSelectorTabsView(
                            semanas: vm.semanas,
                            selectedIndex: Binding(
                                get: { vm.rutaActivaIndex },
                                set: { vm.seleccionarRuta($0) }
                            )
                        )
                    }
                }
                .padding(.horizontal, 16)
                .safeAreaPadding(.top)
                .padding(.top, 6)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    mapController.resetRegion()
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color("Navy"))
                }
                .buttonStyle(.glass(.regular))
                .controlSize(.large)
                .buttonBorderShape(.circle)
                .padding(.trailing, 16)
                .padding(.bottom, 340)
            }

            RutaEstructurasSheet(
                vm: vm,
                modoEdicion: $modoEdicion,
                onCenterMap: { coord in mapController.centerOn(coord) }
            )
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(modoEdicion ? .hidden : .visible, for: .tabBar)
        .task {
            coloniasPolygons = loadGeoPolygons(named: "colonias_san_nicolas")
            municipioPolygons = loadGeoPolygons(named: "san_nicolas")
            await vm.cargar()
        }
        .alert("Mover estructura", isPresented: Binding(
            get: { vm.confirmacionMover != nil },
            set: { if !$0 { vm.confirmacionMover = nil } }
        )) {
            Button("Mover a Ruta \(vm.rutaActiva?.numero ?? 0)", role: .destructive) {
                Task { await vm.confirmarMover() }
            }
            Button("Cancelar", role: .cancel) { vm.confirmacionMover = nil }
        } message: {
            if let conf = vm.confirmacionMover {
                Text("Esta estructura está en Ruta \(conf.deRutaNumero). ¿Moverla a Ruta \(vm.rutaActiva?.numero ?? 0)?")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMensaje != nil },
            set: { if !$0 { vm.errorMensaje = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMensaje = nil }
        } message: {
            Text(vm.errorMensaje ?? "")
        }
        .sheet(item: $vm.pdfURL) { identifiableURL in
            ShareSheet(url: identifiableURL.url)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
