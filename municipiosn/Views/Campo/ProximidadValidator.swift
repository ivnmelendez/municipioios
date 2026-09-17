import CoreLocation
import SwiftUI

// MARK: - Validator

@Observable
final class ProximidadValidator: NSObject, CLLocationManagerDelegate {
    var distancia: Double? = nil
    private(set) var autorizado = true

    private let mgr = CLLocationManager()
    private let estructuraLat: Double
    private let estructuraLng: Double

    init(lat: Double, lng: Double) {
        self.estructuraLat = lat
        self.estructuraLng = lng
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
    }

    var cercano: Bool {
        guard let distancia else { return false }
        return distancia <= 100
    }

    var cargando: Bool { autorizado && distancia == nil }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let target = CLLocation(latitude: estructuraLat, longitude: estructuraLng)
        distancia = loc.distance(from: target)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        autorizado = s == .authorizedWhenInUse || s == .authorizedAlways
        if autorizado { mgr.startUpdatingLocation() }
    }
}

// MARK: - Modifier

private struct ProximidadGuardModifier: ViewModifier {
    @State private var validator: ProximidadValidator
    @Environment(\.dismiss) private var dismiss

    init(lat: Double, lng: Double) {
        _validator = State(initialValue: ProximidadValidator(lat: lat, lng: lng))
    }

    func body(content: Content) -> some View {
        content.overlay {
            if !validator.cercano {
                bloqueOverlay
            }
        }
    }

    private var bloqueOverlay: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: validator.autorizado ? "location.circle.fill" : "location.slash.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color("Navy").opacity(0.35))

                VStack(spacing: 8) {
                    if validator.cargando {
                        ProgressView()
                            .padding(.bottom, 4)
                        Text("Obteniendo ubicación…")
                            .font(.title3.bold())
                            .foregroundStyle(Color("Navy"))
                    } else if !validator.autorizado {
                        Text("GPS no disponible")
                            .font(.title3.bold())
                            .foregroundStyle(Color("Navy"))
                        Text("Activa los permisos de ubicación en Configuración para continuar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if validator.distancia != nil {
                        Text("Debes estar cerca de la estructura")
                            .font(.title3.bold())
                            .foregroundStyle(Color("Navy"))
                        Text("Acércate para poder continuar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Cerrar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("Navy"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - View extension

extension View {
    @ViewBuilder
    func proximidadGuard(lat: Double?, lng: Double?) -> some View {
        if let lat, let lng {
            modifier(ProximidadGuardModifier(lat: lat, lng: lng))
        } else {
            self
        }
    }
}
