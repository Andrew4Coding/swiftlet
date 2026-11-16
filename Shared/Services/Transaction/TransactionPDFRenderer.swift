//
//  TransactionPDFRenderer.swift
//  Swiftlet
//

import UIKit

/// Renders a filtered list of transactions into a printable A4 PDF report: a title, the export
/// timestamp, the covered time range, and a paginated table of every transaction (the bill
/// image is intentionally excluded), followed by income/expense totals.
enum TransactionPDFRenderer {
    private static let pageSize = CGSize(width: 595.2, height: 841.8) // A4 @ 72 dpi
    private static let margin: CGFloat = 36
    private static let rowHeight: CGFloat = 16

    private struct Column {
        let title: String
        let fraction: CGFloat
        let alignment: NSTextAlignment
    }

    private static let columns: [Column] = [
        Column(title: "Date", fraction: 0.14, alignment: .left),
        Column(title: "Title", fraction: 0.26, alignment: .left),
        Column(title: "Category", fraction: 0.18, alignment: .left),
        Column(title: "Wallet", fraction: 0.12, alignment: .left),
        Column(title: "Type", fraction: 0.12, alignment: .left),
        Column(title: "Amount", fraction: 0.18, alignment: .right),
    ]

    static func render(
        transactions: [Transaction],
        title: String,
        timeRange: String,
        exportedAt: Date = .now
    ) -> Data {
        let contentWidth = pageSize.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let rowDateFormatter = DateFormatter()
        rowDateFormatter.dateFormat = "d MMM yyyy"

        let exportedFormatter = DateFormatter()
        exportedFormatter.dateStyle = .long
        exportedFormatter.timeStyle = .short

        return renderer.pdfData { ctx in
            var y: CGFloat = 0

            func beginPage() {
                ctx.beginPage()
                y = margin
                draw(title, in: CGRect(x: margin, y: y, width: contentWidth, height: 24),
                     font: .boldSystemFont(ofSize: 18))
                y += 24
                draw("Exported \(exportedFormatter.string(from: exportedAt))",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                     font: .systemFont(ofSize: 10), color: .darkGray)
                y += 13
                draw("Time range: \(timeRange)",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                     font: .systemFont(ofSize: 10), color: .darkGray)
                y += 22
                drawRow(columns.map(\.title), font: .boldSystemFont(ofSize: 9),
                        contentWidth: contentWidth, y: &y)
                drawSeparator(width: contentWidth, y: &y)
            }

            beginPage()

            for transaction in transactions {
                if y > pageSize.height - margin - rowHeight {
                    beginPage()
                }
                let signedAmount = transaction.signedAmountText
                drawRow([
                    rowDateFormatter.string(from: transaction.date),
                    transaction.title,
                    transaction.category?.name ?? "Uncategorized",
                    transaction.walletDescription,
                    transaction.type.displayName,
                    signedAmount,
                ], font: .systemFont(ofSize: 9), contentWidth: contentWidth, y: &y)
            }

            if transactions.isEmpty {
                draw("No transactions in this range.",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: rowHeight),
                     font: .systemFont(ofSize: 9), color: .darkGray)
                y += rowHeight
            }

            if y > pageSize.height - margin - rowHeight * 3 {
                beginPage()
            }
            y += 8
            drawSeparator(width: contentWidth, y: &y)

            let income = transactions.filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let expense = transactions.filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }
            draw(
                "Total income: \(CurrencyFormatter.rupiah(income))    "
                    + "Total expense: \(CurrencyFormatter.rupiah(expense))    "
                    + "Net: \(CurrencyFormatter.rupiah(income - expense))",
                in: CGRect(x: margin, y: y, width: contentWidth, height: rowHeight),
                font: .boldSystemFont(ofSize: 10)
            )
        }
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor = .black) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    private static func drawRow(_ cells: [String], font: UIFont, contentWidth: CGFloat, y: inout CGFloat) {
        var x = margin
        for (index, cell) in cells.enumerated() where index < columns.count {
            let width = contentWidth * columns[index].fraction
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = columns[index].alignment
            paragraph.lineBreakMode = .byTruncatingTail
            (cell as NSString).draw(
                in: CGRect(x: x + 2, y: y, width: width - 4, height: rowHeight),
                withAttributes: [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph,
                ]
            )
            x += width
        }
        y += rowHeight
    }

    private static func drawSeparator(width: CGFloat, y: inout CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + width, y: y))
        path.lineWidth = 0.5
        UIColor.lightGray.setStroke()
        path.stroke()
        y += 6
    }
}
