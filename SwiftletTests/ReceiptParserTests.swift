//
//  ReceiptParserTests.swift
//  SwiftletTests
//

import Testing

@testable import Swiftlet

struct ReceiptParserTests {
    @Test(arguments: [
        ("45.000", 45_000),
        ("1.234.567", 1_234_567),
        ("45.000,00", 45_000),
        ("Rp45000", 45_000),
        ("Rp 45.000", 45_000),
        ("45,000", 45_000),
        ("45,000.00", 45_000),
        ("45000.00", 45_000),
        ("12500", 12_500),
        ("-10.000", -10_000),
        ("(10.000)", -10_000),
    ])
    func parsesIndonesianAndPlainAmounts(raw: String, expected: Int) {
        #expect(ReceiptParser.parseAmount(raw) == expected)
    }

    @Test func rejectsNonNumbers() {
        #expect(ReceiptParser.parseAmount("abc") == nil)
        #expect(ReceiptParser.parseAmount("") == nil)
    }

    @Test func parsesRestaurantReceiptWithServiceAndTax() {
        let receipt = ReceiptParser.parse(lines: [
            "WARUNG MAKAN SEDERHANA",
            "Jl. Sudirman No 12",
            "Telp 0812 3456 7890",
            "14/11/2026 19:57",
            "Meja 5",
            "Nasi Goreng Spesial   35.000",
            "Es Teh Manis   8.000",
            "2 x Ayam Bakar   90.000",
            "Subtotal   133.000",
            "Service 5%   6.650",
            "PB1 10%   13.965",
            "Total   153.615",
            "Tunai   200.000",
            "Kembali   46.385",
        ])

        #expect(receipt.items.map(\.name) == ["Nasi Goreng Spesial", "Es Teh Manis", "Ayam Bakar"])
        #expect(receipt.items.map(\.price) == [35_000, 8_000, 90_000])
        #expect(receipt.items.last?.quantity == 2)
        #expect(receipt.subtotal == 133_000)
        #expect(receipt.service == 6_650)
        #expect(receipt.tax == 13_965)
        #expect(receipt.total == 153_615)
        #expect(ReceiptMath.mismatches(in: receipt).isEmpty)
    }

    @Test func ignoresPaymentLinesAndItemsAfterTotal() {
        let parsed = ReceiptParser.parse(lines: [
            "Kopi Susu 25.000",
            "Total 25.000",
            "QRIS 25.000",
            "Terima kasih 12.345",
        ])
        #expect(parsed.items.count == 1)
        #expect(parsed.total == 25_000)
    }

    @Test func mergesNameAndPriceSplitAcrossLines() {
        let receipt = ReceiptParser.parse(lines: [
            "Nasi Campur Bali",
            "28.000",
            "Es Jeruk",
            "10.000",
            "Total",
            "38.000",
        ])
        #expect(receipt.items.map(\.name) == ["Nasi Campur Bali", "Es Jeruk"])
        #expect(receipt.items.map(\.price) == [28_000, 10_000])
        #expect(receipt.total == 38_000)
    }

    @Test func readsDiscountAsPositiveAmount() {
        let parsed = ReceiptParser.parse(lines: [
            "Burger 60.000",
            "Kentang 20.000",
            "Subtotal 80.000",
            "Diskon Promo -8.000",
            "Total 72.000",
        ])
        #expect(parsed.discount == 8_000)
        #expect(parsed.total == 72_000)
        #expect(ReceiptMath.mismatches(in: parsed).isEmpty)
    }

    @Test func foodNamesWithKeywordSubstringsStayItems() {
        let parsed = ReceiptParser.parse(lines: [
            "Jamur Crispy 22.000",
            "Private Room 50.000",
            "Total 72.000",
        ])
        #expect(parsed.items.map(\.name) == ["Jamur Crispy", "Private Room"])
        #expect(parsed.tax == nil)
    }

    @Test func ignoresPhoneNumbersAndDates() {
        let parsed = ReceiptParser.parse(lines: [
            "Telp 081234567890",
            "Tgl 14/11/2026",
            "Bakso 15.000",
        ])
        #expect(parsed.items.map(\.name) == ["Bakso"])
    }

    @Test func detectsItemsThatDoNotAddUp() {
        let parsed = ReceiptParser.parse(lines: [
            "Soto 20.000",
            "Teh 5.000",
            "Subtotal 30.000",
            "Total 30.000",
        ])
        #expect(ReceiptMath.mismatches(in: parsed) == [.itemsDifferFromSubtotal(-5_000)])
    }

    @Test func detectsTotalThatDoesNotMatchExtras() {
        let mismatches = ReceiptMath.mismatches(
            itemsTotal: 100_000, subtotal: 100_000, service: 5_000, tax: 10_500, discount: 0, total: 120_000
        )
        #expect(mismatches == [.totalDiffers(-4_500)])
    }

    @Test func emptyInputGivesEmptyReceipt() {
        #expect(ReceiptParser.parse(lines: []) == ParsedReceipt())
    }
}
