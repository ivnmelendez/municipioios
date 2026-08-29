import UIKit

enum RutaEditorPDFService {
    static func generarPDF(semana: RutaSemana, items: [RutaEditorItem]) throws -> URL {
        let pageW: CGFloat = 612
        let pageH: CGFloat = 792
        let margin: CGFloat = 50
        let lineH: CGFloat = 20

        // Group by parque preserving route order
        var parqueOrder: [String] = []
        var grupos: [String: (colonia: String?, items: [(orden: Int, numero: String)])] = [:]
        for (i, item) in items.enumerated() {
            let key = item.estructura.parques?.nombre ?? "Sin parque"
            if grupos[key] == nil {
                parqueOrder.append(key)
                grupos[key] = (item.estructura.parques?.colonias?.nombre, [])
            }
            grupos[key]!.items.append((orden: i + 1, numero: item.estructura.numero))
        }
        let porParque = parqueOrder.map { k in (parque: k, colonia: grupos[k]!.colonia, items: grupos[k]!.items) }

        let fecha: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "es_MX")
            f.dateFormat = "d 'de' MMMM 'de' yyyy"
            return f.string(from: Date())
        }()

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let data = renderer.pdfData { ctx in
            var y: CGFloat = margin
            var pageNumber = 1

            let pageNumAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.systemGray2
            ]

            func drawPageNumber() {
                let label = "Página \(pageNumber)"
                let size = label.size(withAttributes: pageNumAttrs)
                label.draw(at: CGPoint(x: (pageW - size.width) / 2, y: pageH - margin / 2), withAttributes: pageNumAttrs)
            }

            func nuevaPagina() {
                drawPageNumber()
                ctx.beginPage()
                pageNumber += 1
                y = margin
            }

            func espacio(_ h: CGFloat) -> Bool {
                y + h > pageH - margin
            }

            ctx.beginPage()

            // Header
            "Municipio de San Nicolás de los Garza".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.black
            ])
            y += 22
            "Ruta \(semana.numero) — Listado por parque".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.systemGray
            ])
            y += 16
            fecha.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.systemGray2
            ])
            y += 24

            // Separator
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: y))
            linePath.addLine(to: CGPoint(x: pageW - margin, y: y))
            UIColor.systemGray4.setStroke()
            linePath.lineWidth = 0.5
            linePath.stroke()
            y += 16

            // Summary
            "\(items.count) paradas · \(porParque.count) parques".draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray]
            )
            y += 24

            // Groups
            for grupo in porParque {
                if espacio(lineH * 3) { nuevaPagina() }

                let parqueLabel = "\(grupo.parque): \(grupo.items.count) estructura\(grupo.items.count == 1 ? "" : "s")"
                parqueLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.black
                ])
                y += 16

                if let colonia = grupo.colonia {
                    colonia.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.systemGray
                    ])
                    y += 14
                }

                // 2-column layout: "#3 · SN-001"
                let colWidth = (pageW - margin * 2) / 2
                var col = 0
                for entry in grupo.items {
                    let x = margin + CGFloat(col) * colWidth
                    if col == 0 && espacio(lineH) { nuevaPagina(); col = 0 }
                    let label = "#\(entry.orden) · \(entry.numero)"
                    label.draw(at: CGPoint(x: x, y: y), withAttributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: UIColor.darkGray
                    ])
                    col += 1
                    if col == 2 { col = 0; y += lineH }
                }
                if col > 0 { y += lineH }
                y += 12
            }

            drawPageNumber()
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ruta-\(semana.numero)-\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }
}
