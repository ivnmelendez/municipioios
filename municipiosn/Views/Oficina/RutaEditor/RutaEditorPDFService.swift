import UIKit

enum RutaEditorPDFService {
    static func generarPDF(semana: RutaSemana, items: [RutaEditorItem]) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = URL.temporaryDirectory
            .appending(path: "Ruta-\(semana.numero)-\(Int(Date().timeIntervalSince1970)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            let headerRowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]

            "Ruta \(semana.numero)".draw(at: CGPoint(x: 40, y: 36), withAttributes: titleAttrs)

            let fecha = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            fecha.draw(at: CGPoint(x: 40, y: 64), withAttributes: subtitleAttrs)
            "\(items.count) paradas".draw(at: CGPoint(x: 40, y: 80), withAttributes: subtitleAttrs)

            // Draw header line
            let headerY: CGFloat = 108
            UIColor.lightGray.setFill()
            UIRectFill(CGRect(x: 40, y: headerY - 2, width: page.width - 80, height: 0.5))

            "#    Num       Parque                          Colonia".draw(
                at: CGPoint(x: 40, y: headerY + 4), withAttributes: headerRowAttrs
            )

            var y: CGFloat = headerY + 22
            let leftMargin: CGFloat = 40
            let lineHeight: CGFloat = 19
            let bottomMargin: CGFloat = 60

            for (i, item) in items.enumerated() {
                if y + lineHeight > page.height - bottomMargin {
                    ctx.beginPage()
                    y = 40
                }

                let num = String(format: "%02d", i + 1)
                let sn = item.estructura.numero.padding(toLength: 9, withPad: " ", startingAt: 0)
                let parque = (item.estructura.parques?.nombre ?? "—").truncated(to: 31)
                    .padding(toLength: 31, withPad: " ", startingAt: 0)
                let colonia = item.estructura.parques?.colonias?.nombre ?? "—"

                let row = "\(num)   \(sn)  \(parque)  \(colonia)"
                row.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: rowAttrs)

                if i % 2 == 1 {
                    UIColor.black.withAlphaComponent(0.04).setFill()
                    UIRectFill(CGRect(x: leftMargin - 4, y: y - 3, width: page.width - leftMargin * 2 + 8, height: lineHeight))
                    row.draw(at: CGPoint(x: leftMargin, y: y), withAttributes: rowAttrs)
                }

                y += lineHeight
            }

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.lightGray
            ]
            "Municipio San Nicolás · Generado \(fecha)"
                .draw(at: CGPoint(x: 40, y: page.height - 36), withAttributes: footerAttrs)
        }
        return url
    }
}

private extension String {
    func truncated(to length: Int) -> String {
        count > length ? String(prefix(length - 1)) + "…" : self
    }
}
