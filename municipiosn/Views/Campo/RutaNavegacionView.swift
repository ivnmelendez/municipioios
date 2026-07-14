import SwiftUI
import MapKit
import CoreLocation

// MARK: - Location tracker

@Observable
private final class LocationTracker: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    private let mgr = CLLocationManager()

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        mgr.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
}

// MARK: - Main view

struct RutaNavegacionView: View {
    let ruta: RutaSemana
    let userId: UUID?
    let campanas: [CampanaBasica]
    let onTerminar: () -> Void
    var todasLasRutas: [RutaSemana] = []  // DEV only

    @State private var rutaActual: RutaSemana? = nil
    @State private var estructuras: [RutaEstructuraItem] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var devIndex: Int? = nil  // DEV only
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationTracker = LocationTracker()
    @State private var estructuraDetalle: RutaEstructuraItem?
    @State private var mostrarCompletada = false

    private var rutaEfectiva: RutaSemana { rutaActual ?? ruta }
    private var rutaColor: Color { Color(hex: rutaEfectiva.color) }
    private var proxima: RutaEstructuraItem? {
        if let i = devIndex, i < estructuras.count { return estructuras[i] }
        return estructuras.first(where: { !$0.visitada })
    }
    private var visitadas: Int { estructuras.filter(\.visitada).count }
    private var total: Int { estructuras.count }
    private var progreso: Double { total > 0 ? Double(visitadas) / Double(total) : 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapaView
            VStack(spacing: 0) {
                topBar
                Spacer()
            }
            if mostrarCompletada {
                completadaOverlay
            } else {
                bottomCard
            }
        }
        .ignoresSafeArea()
        .task { rutaActual = ruta; await cargar() }
        .sheet(item: $estructuraDetalle) { item in
            CampoEstructuraDetalleView(
                estructura: item.estructura,
                userId: userId,
                campanas: campanas,
                rutaSemanaId: ruta.id,
                yaVisitada: item.visitada,
                onMarcarRevision: { Task { await marcar(item: item) } }
            )
        }
    }

    // MARK: Mapa

    private var mapaView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(estructuras) { item in
                let coord = CLLocationCoordinate2D(
                    latitude: item.estructura.lat ?? 0,
                    longitude: item.estructura.lng ?? 0
                )
                Annotation(item.estructura.numero, coordinate: coord) {
                    pinView(item: item)
                }
            }
        }
        .mapStyle(.standard(emphasis: .automatic))
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func pinView(item: RutaEstructuraItem) -> some View {
        let esProxima = item.id == proxima?.id
        ZStack {
            Circle()
                .fill(item.visitada ? Color.green : (esProxima ? rutaColor : Color.white))
                .frame(width: esProxima ? 40 : 28, height: esProxima ? 40 : 28)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            if item.visitada {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(item.orden)")
                    .font(.system(size: esProxima ? 14 : 10, weight: .bold))
                    .foregroundStyle(esProxima ? .white : rutaColor)
            }
        }
        .animation(.spring(duration: 0.3), value: esProxima)
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Button { onTerminar() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }

                VStack(spacing: 4) {
                    ProgressView(value: progreso)
                        .tint(rutaColor)
                        .frame(height: 4)
                        .scaleEffect(x: 1, y: 1.5)
                    Text("\(visitadas) de \(total) estructuras")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                ZStack {
                    Circle()
                        .fill(rutaColor)
                        .frame(width: 36, height: 36)
                    Text("\(rutaEfectiva.numero)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)

            if !todasLasRutas.isEmpty {
                devPill
            }
        }
    }

    private var devPill: some View {
        let idx = devIndex ?? (estructuras.firstIndex(where: { !$0.visitada }) ?? 0)
        let total = estructuras.count
        return HStack(spacing: 14) {
            Image(systemName: "hammer.fill").font(.subheadline)
            Button {
                let prev = max(0, idx - 1)
                devIndex = prev
                panearA(estructuras[prev])
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(idx <= 0 || total == 0)

            Text(total > 0 ? "\(idx + 1)/\(total)" : "--")
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(minWidth: 52)

            Button {
                let next = min(total - 1, idx + 1)
                devIndex = next
                panearA(estructuras[next])
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(idx >= total - 1 || total == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .buttonStyle(.plain)
    }

    private func panearA(_ item: RutaEstructuraItem) {
        guard let lat = item.estructura.lat, let lng = item.estructura.lng else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    // MARK: Bottom card

    private var bottomCard: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .padding(24)
            } else if let item = proxima {
                cardContent(item: item)
            } else {
                sinProximaContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: -4)
        .padding(.horizontal, 0)
    }

    private func cardContent(item: RutaEstructuraItem) -> some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(rutaColor)
                            .font(.subheadline)
                        Text("Próxima parada")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.estructura.numero)
                        .font(.title3.bold())
                    if let parque = item.estructura.parques?.nombre {
                        Text(parque)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let colonia = item.estructura.parques?.colonias?.nombre {
                        Text(colonia)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                distanciaView(item: item)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                if let lat = item.estructura.lat, let lng = item.estructura.lng {
                    Button {
                        abrirNavegacion(lat: lat, lng: lng)
                    } label: {
                        Label("Navegar", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(rutaColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(rutaColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    estructuraDetalle = item
                } label: {
                    Text("Ver / Marcar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(rutaColor, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
    }

    @ViewBuilder
    private func distanciaView(item: RutaEstructuraItem) -> some View {
        if let userCoord = locationTracker.coordinate,
           let lat = item.estructura.lat,
           let lng = item.estructura.lng {
            let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            let destLoc = CLLocation(latitude: lat, longitude: lng)
            let metros = userLoc.distance(from: destLoc)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDistancia(metros))
                    .font(.headline.monospacedDigit())
                Text("de distancia")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sinProximaContent: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            if let err = errorMsg {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Error al cargar estructuras")
                    .font(.headline)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Button {
                    Task { await cargar() }
                } label: {
                    Text("Reintentar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("¡Ruta completada!")
                    .font(.headline)
                Text("Todas las estructuras fueron visitadas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    onTerminar()
                } label: {
                    Text("Terminar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
            }
            Spacer().frame(height: 18)
        }
        .padding(.bottom, 16)
    }

    private var completadaOverlay: some View {
        sinProximaContent
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, y: -4)
    }

    // MARK: Actions

    private func cargar() async {
        isLoading = true
        errorMsg = nil
        mostrarCompletada = false
        guard let uid = userId else { isLoading = false; return }
        do {
            estructuras = try await RutasService.shared.fetchEstructurasEnRuta(
                rutaSemanaId: rutaEfectiva.id, userId: uid
            )
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
        panearAProxima()
    }

    private func cambiarRuta(_ nueva: RutaSemana) async {
        guard nueva.id != rutaEfectiva.id else { return }
        rutaActual = nueva
        estructuras = []
        await cargar()
    }

    private func marcar(item: RutaEstructuraItem) async {
        guard let uid = userId else { return }
        if let idx = estructuras.firstIndex(where: { $0.id == item.id }) {
            estructuras[idx].visitada = true
        }
        do {
            try await RutasService.shared.marcarRevision(
                estructuraId: item.estructura.id,
                rutaSemanaId: ruta.id,
                userId: uid
            )
        } catch {
            if let idx = estructuras.firstIndex(where: { $0.id == item.id }) {
                estructuras[idx].visitada = false
                return
            }
        }
        HapticService.impacto(.medium)
        panearAProxima()
        if proxima == nil { mostrarCompletada = true }
    }

    private func panearAProxima() {
        guard let siguiente = proxima,
              let lat = siguiente.estructura.lat,
              let lng = siguiente.estructura.lng else { return }
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }

    private func abrirNavegacion(lat: Double, lng: Double) {
        let googleURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")!
        if UIApplication.shared.canOpenURL(googleURL) {
            UIApplication.shared.open(googleURL)
            return
        }
        let appleMapsURL = URL(string: "maps://?daddr=\(lat),\(lng)&dirflg=d")!
        UIApplication.shared.open(appleMapsURL)
    }

    private func formatDistancia(_ metros: Double) -> String {
        if metros < 1000 {
            return "\(Int(metros)) m"
        } else {
            let km = metros / 1000
            return String(format: "%.1f km", km)
        }
    }
}
