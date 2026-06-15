import Foundation

/// Disk cache backed by UserDefaults. TTL default: 24 hours.
final class LocalDataCache {
    static let shared = LocalDataCache()
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 24 * 60 * 60) {
        self.ttl = ttl
    }

    func guardar<T: Encodable>(_ value: T, clave: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: "ldc_\(clave)")
        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: "ldc_ts_\(clave)")
    }

    func cargar<T: Decodable>(_ type: T.Type, clave: String) -> T? {
        let ts = defaults.double(forKey: "ldc_ts_\(clave)")
        guard ts > 0,
              Date().timeIntervalSinceReferenceDate - ts < ttl,
              let data = defaults.data(forKey: "ldc_\(clave)"),
              let value = try? decoder.decode(T.self, from: data)
        else { return nil }
        return value
    }

    func invalidar(clave: String) {
        defaults.removeObject(forKey: "ldc_\(clave)")
        defaults.removeObject(forKey: "ldc_ts_\(clave)")
    }
}
