import Foundation

struct PagoManoObra: Codable, Identifiable {
    let id: UUID
    var fecha: String        // yyyy-MM-dd (DATE en Supabase)
    var trabajador: String
    var monto: Double
    var concepto: String?
    var creadoPor: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, fecha, trabajador, monto, concepto
        case creadoPor   = "creado_por"
        case createdAt   = "created_at"
    }

    var fechaDate: Date {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "America/Monterrey")
        return fmt.date(from: fecha) ?? Date()
    }

    var fechaDisplay: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "d 'de' MMMM, yyyy"
        fmt.timeZone = TimeZone(identifier: "America/Monterrey")
        return fmt.string(from: fechaDate)
    }

    var montoDisplay: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale(identifier: "es_MX")
        fmt.currencySymbol = "$"
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: monto)) ?? "$\(monto)"
    }
}
