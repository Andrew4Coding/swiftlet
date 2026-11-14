//
//  ReceiptScannerTests.swift
//  SwiftletTests
//

import Testing
import UIKit

@testable import Swiftlet

struct ReceiptScannerTests {
    private static let rows: [(String, String)] = [
        ("WARUNG MAKAN SEDERHANA", ""),
        ("Nasi Goreng Spesial", "35.000"),
        ("Es Teh Manis", "8.000"),
        ("Ayam Bakar", "45.000"),
        ("Subtotal", "88.000"),
        ("Service 5%", "4.400"),
        ("PB1 10%", "9.240"),
        ("Total", "101.640"),
    ]

    private func renderReceipt() throws -> Data {
        let size = CGSize(width: 900, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let font = UIFont.monospacedSystemFont(ofSize: 40, weight: .regular)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            for (index, row) in Self.rows.enumerated() {
                let y = 60 + CGFloat(index) * 90
                row.0.draw(at: CGPoint(x: 50, y: y), withAttributes: attributes)
                if !row.1.isEmpty {
                    let width = row.1.size(withAttributes: attributes).width
                    row.1.draw(at: CGPoint(x: size.width - 50 - width, y: y), withAttributes: attributes)
                }
            }
        }
        return try #require(image.pngData())
    }

    @Test func scansRenderedReceiptIntoItems() async throws {
        let outcome = try await ReceiptScanner.scan(imageData: renderReceipt())
        let receipt = outcome.receipt

        #expect(receipt.items.count == 3)
        #expect(receipt.items.map(\.price) == [35_000, 8_000, 45_000])
        #expect(receipt.subtotal == 88_000)
        #expect(receipt.service == 4_400)
        #expect(receipt.tax == 9_240)
        #expect(receipt.total == 101_640)
        #expect(ReceiptMath.mismatches(in: receipt).isEmpty)
    }

    @Test func groupsFragmentsOnTheSameBaselineIntoOneRow() {
        let fragments: [(text: String, box: CGRect)] = [
            ("8.000", CGRect(x: 0.7, y: 0.80, width: 0.2, height: 0.04)),
            ("Es Teh", CGRect(x: 0.1, y: 0.80, width: 0.3, height: 0.04)),
            ("Total", CGRect(x: 0.1, y: 0.50, width: 0.2, height: 0.04)),
        ]
        let rows = ReceiptScanner.groupIntoRows(fragments)
        #expect(rows.count == 2)
        #expect(rows[0].hasPrefix("Es Teh"))
        #expect(rows[0].hasSuffix("8.000"))
    }
}
