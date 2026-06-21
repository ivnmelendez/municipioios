import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map controller

final class UbicacionMapController {
    weak var mapView: MKMapView?

    func volar(a coordenada: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordenada,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
        mapView?.setRegion(region, animated: true)
    }

    func centrarEnUsuario() {
        mapView?.setUserTrackingMode(.follow, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.mapView?.setUserTrackingMode(.none, animated: false)
        }
    }
}

// MARK: - Embedded map picker

private struct MapaUbicacionPicker: UIViewRepresentable {
    @Binding var coordenada: CLLocationCoordinate2D?
    let controller: UbicacionMapController

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.7367, longitude: -100.2726),
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        ), animated: false)
        map.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        map.addGestureRecognizer(tap)
        controller.mapView = map
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        if let coord = coordenada {
            let ann = MKPointAnnotation()
            ann.coordinate = coord
            mapView.addAnnotation(ann)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(coordenada: $coordenada) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var coordenada: Binding<CLLocationCoordinate2D?>

        init(coordenada: Binding<CLLocationCoordinate2D?>) {
            self.coordenada = coordenada
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            coordenada.wrappedValue = map.convert(gesture.location(in: map), toCoordinateFrom: map)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "pin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.markerTintColor = UIColor(named: "Navy")
            view.animatesWhenAdded = true
            return view
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class NuevaEstructuraViewModel {
    var parques: [ParqueParaCrear] = []
    var busqueda: String = ""
    var parqueSeleccionado: ParqueParaCrear? = nil
    var coordenada: CLLocationCoordinate2D? = nil
    var estado: EstadoEstructura = .activa
    var incluirFecha: Bool = false
    var fecha: Date = Date()
    var fotoUI: UIImage? = nil
    var guardando: Bool = false
    var error: String? = nil

    let mapController = UbicacionMapController()

    var parquesFiltrados: [ParqueParaCrear] {
        let q = busqueda.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return parques }
        return parques.filter { $0.etiqueta.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var puedeAvanzar: Bool { coordenada != nil }
    var carasCreadas: CarasCreadas? = nil
    var estructuraCreada: EstructuraCreada? = nil

    func cargarParques() async {
        do {
            parques = try await EstructurasService.shared.fetchParquesParaCrear()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func seleccionar(_ parque: ParqueParaCrear) {
        parqueSeleccionado = parque
        busqueda = ""
        if let lat = parque.lat, let lng = parque.lng {
            mapController.volar(a: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
    }

    func guardar() async -> Bool {
        guard let coord = coordenada else { return false }
        guardando = true
        defer { guardando = false }
        do {
            var fotoUrl: String? = nil
            if let img = fotoUI, let data = img.jpegData(compressionQuality: 0.85) {
                let path = "estructuras/\(UUID().uuidString).jpg"
                fotoUrl = try? await CoroplastService.shared.uploadFoto(data: data, path: path)
            }
            let creada = try await EstructurasService.shared.crearEstructura(
                parqueId: parqueSeleccionado?.id,
                lat: coord.latitude,
                lng: coord.longitude,
                estado: estado,
                fechaInstalacion: incluirFecha ? fecha : nil,
                fotoUrl: fotoUrl
            )
            let caras = try await EstructurasService.shared.crearCaras(estructuraId: creada.id)
            estructuraCreada = creada
            carasCreadas = caras
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

// MARK: - View

struct NuevaEstructuraView: View {
    let onCreada: (EstructuraCreada) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var vm = NuevaEstructuraViewModel()
    @State private var mostrarFoto = false
    @State private var showParquePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress + parque button
                VStack(spacing: 10) {
                    progresoIndicador(paso: 1)
                    parqueButton
                        .padding(.horizontal, 14)
                }
                .padding(.top, 10)
                .padding(.bottom, 8)

                // Map fills all remaining space
                ZStack(alignment: .bottomTrailing) {
                    MapaUbicacionPicker(coordenada: $vm.coordenada, controller: vm.mapController)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if vm.coordenada != nil {
                        Label("Ubicación marcada", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(10)
                    }

                    Button { vm.mapController.centrarEnUsuario() } label: {
                        Image(systemName: "location.fill").foregroundStyle(Color("Navy"))
                    }
                    .buttonStyle(.glass(.regular))
                    .controlSize(.regular)
                    .buttonBorderShape(.circle)
                    .padding(12)
                }

                // Bottom bar: estado + fecha + botón
                bottomBar
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Nueva Estructura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color("Navy"))
                }
            }
            .navigationDestination(isPresented: $mostrarFoto) {
                FotoEstructuraStep(vm: vm) {
                    if let creada = vm.estructuraCreada { onCreada(creada) }
                    dismiss()
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK") { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
        }
        .task { await vm.cargarParques() }
    }

    // MARK: Parque compact button

    private var parqueButton: some View {
        Button { showParquePicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: vm.parqueSeleccionado != nil ? "mappin.circle.fill" : "magnifyingglass")
                    .foregroundStyle(Color("Navy"))
                    .imageScale(.medium)
                if let p = vm.parqueSeleccionado {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.nombre)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let c = p.colonias?.nombre {
                            Text(c).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Elegir parque (opcional)")
                        .font(.subheadline)
                        .foregroundStyle(Color("Navy"))
                }
                Spacer()
                if vm.parqueSeleccionado != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.small)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showParquePicker) {
            ParquePickerSheet(parques: vm.parques, seleccionado: vm.parqueSeleccionado) { parque in
                vm.seleccionar(parque)
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Picker("Estado", selection: $vm.estado) {
                Text("Activa").tag(EstadoEstructura.activa)
                Text("Dañada").tag(EstadoEstructura.dañada)
                Text("En rep.").tag(EstadoEstructura.en_reparacion)
                Text("Inactiva").tag(EstadoEstructura.inactiva)
            }
            .pickerStyle(.segmented)

            HStack {
                Toggle(isOn: $vm.incluirFecha) {
                    Text("Fecha instalación").font(.subheadline)
                }
                .tint(Color("Navy"))
                if vm.incluirFecha {
                    DatePicker("", selection: $vm.fecha, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }

            Button { mostrarFoto = true } label: {
                HStack {
                    Text("Siguiente")
                    Image(systemName: "chevron.right")
                }
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    vm.puedeAvanzar ? Color("Navy") : Color.secondary.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(!vm.puedeAvanzar)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .background(.regularMaterial)
    }
}

// MARK: - Progress helper

private func progresoIndicador(paso: Int) -> some View {
    HStack(spacing: 8) {
        ForEach(1...3, id: \.self) { n in
            Capsule()
                .fill(n <= paso ? Color("Navy") : Color.secondary.opacity(0.25))
                .frame(width: n == paso ? 28 : 10, height: 8)
                .animation(.easeInOut(duration: 0.25), value: paso)
        }
    }
}

// MARK: - Paso 2: Foto

struct FotoEstructuraStep: View {
    let vm: NuevaEstructuraViewModel
    let onDone: () -> Void
    @State private var mostrarCampanas = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Foto de la estructura")
                    .font(.title2.bold())
                    .foregroundStyle(Color("Navy"))
                Text("Toma una foto del estado actual")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)

            progresoIndicador(paso: 2)
                .padding(.bottom, 24)

            ScrollView {
                FotoCapturaView(imagen: Binding(
                    get: { vm.fotoUI },
                    set: { vm.fotoUI = $0 }
                ), altura: 280)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            Button {
                Task {
                    if await vm.guardar() { mostrarCampanas = true }
                }
            } label: {
                HStack {
                    if vm.guardando { ProgressView().tint(.white) }
                    else {
                        Text("Siguiente")
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("Navy"), in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.guardando)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .navigationDestination(isPresented: $mostrarCampanas) {
            if let caras = vm.carasCreadas, let creada = vm.estructuraCreada {
                AsignarCampanasView(caras: caras, numero: creada.numero, onDone: onDone)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }
}

// MARK: - ParquePickerSheet

private struct ParquePickerSheet: View {
    let parques: [ParqueParaCrear]
    let seleccionado: ParqueParaCrear?
    let onSelect: (ParqueParaCrear) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var busqueda = ""

    private var filtrados: [ParqueParaCrear] {
        guard !busqueda.isEmpty else { return parques }
        return parques.filter {
            $0.etiqueta.range(of: busqueda, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        NavigationStack {
            List(filtrados) { parque in
                Button {
                    onSelect(parque)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("Navy").opacity(0.1))
                                .frame(width: 50, height: 50)
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("Navy"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parque.nombre)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.primary)
                            if let c = parque.colonias?.nombre {
                                Text(c).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if seleccionado?.id == parque.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("Navy"))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $busqueda, prompt: "Buscar parque")
            .navigationTitle("Elige el parque")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color("Navy"))
                }
            }
        }
    }
}

// MARK: - Paso 2: Asignar campañas

@Observable
@MainActor
final class AsignarCampanasViewModel {
    var campanas: [CampanaBasica] = []
    var seleccionA: CampanaBasica? = nil
    var seleccionB: CampanaBasica? = nil
    var guardando = false
    var error: String? = nil

    func cargar() async {
        do { campanas = try await EstructurasService.shared.fetchCampanasActivas() }
        catch { self.error = error.localizedDescription }
    }

    func guardar(caras: CarasCreadas) async -> Bool {
        guardando = true
        defer { guardando = false }
        do {
            if let c = seleccionA {
                try await EstructurasService.shared.asignarCampana(caraId: caras.caraAId, campanaId: c.id)
            }
            if let c = seleccionB {
                try await EstructurasService.shared.asignarCampana(caraId: caras.caraBId, campanaId: c.id)
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

struct AsignarCampanasView: View {
    let caras: CarasCreadas
    let numero: String
    let onDone: () -> Void

    @State private var vm = AsignarCampanasViewModel()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("¿Qué campaña va en cada cara?")
                    .font(.title2.bold())
                    .foregroundStyle(Color("Navy"))
                    .multilineTextAlignment(.center)
                Text("Asigna la campaña que tiene instalada cada cara")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)

            progresoIndicador(paso: 3)
                .padding(.bottom, 24)

            if vm.campanas.isEmpty {
                ProgressView("Cargando campañas…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        CaraAsignarRow(tipo: "A", campana: $vm.seleccionA, campanas: vm.campanas)
                        CaraAsignarRow(tipo: "B", campana: $vm.seleccionB, campanas: vm.campanas)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                Button {
                    Task { if await vm.guardar(caras: caras) { onDone() } }
                } label: {
                    HStack {
                        if vm.guardando { ProgressView().tint(.white) }
                        else { Text("Guardar") }
                    }
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        (vm.seleccionA != nil || vm.seleccionB != nil) ? Color("Navy") : Color.secondary.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(vm.guardando || (vm.seleccionA == nil && vm.seleccionB == nil))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(numero)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Saltar") { onDone() }
                    .foregroundStyle(Color("Navy"))
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        .task { await vm.cargar() }
    }
}

// MARK: - CaraAsignarRow

private struct CaraAsignarRow: View {
    let tipo: String
    @Binding var campana: CampanaBasica?
    let campanas: [CampanaBasica]
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cara \(tipo.uppercased())")
                .font(.headline)
                .foregroundStyle(Color("Navy"))

            Button { showPicker = true } label: {
                HStack(spacing: 12) {
                    if let c = campana {
                        CampanaThumbnail(campana: c, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.nombre)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Label("Campaña asignada", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("Navy").opacity(0.08))
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus.circle.dashed")
                                .font(.title2)
                                .foregroundStyle(Color("Navy"))
                        }
                        Text("Tocar para elegir campaña")
                            .font(.subheadline)
                            .foregroundStyle(Color("Navy"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPicker) {
                CampanaPickerSheet(campanas: campanas, seleccionada: $campana)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Previews

#Preview("Paso 1 — Nueva Estructura") {
    NuevaEstructuraView { _ in }
}

#Preview("Paso 2 — Asignar Campañas") {
    NavigationStack {
        AsignarCampanasView(
            caras: CarasCreadas(caraAId: UUID(), caraBId: UUID()),
            numero: "SN-275"
        ) { }
    }
}
