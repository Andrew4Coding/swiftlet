//
//  PaidAmountDetectorTests.swift
//  SwiftletTests
//

import Testing

@testable import Swiftlet

struct PaidAmountDetectorTests {
    @Test(arguments: [
        ("150.000", 150_000),
        ("150.000,00", 150_000),
        ("1.500", 1500),
        ("1,250,000", 1_250_000),
        ("150000", 150_000),
        ("150000.00", 150_000),
        ("25.000.", 25000),
    ])
    func parsesIndonesianFormats(token: String, expected: Int) {
        #expect(PaidAmountDetector.parse(token) == expected)
    }

    @Test func extractsAmountsFromPrefixedLine() {
        #expect(PaidAmountDetector.amounts(in: "Total Rp 150.000,00") == [150_000])
        #expect(PaidAmountDetector.amounts(in: "Rp150.000") == [150_000])
    }

    @Test func keywordPicksTotalPaidNotFeeOrBalance() {
        let lines = [
            "Transaksi Berhasil",
            "Biaya Admin  Rp 2.500",
            "Saldo  Rp 1.200.000",
            "Total Bayar  Rp 52.500",
            "No. Ref  202611140012345",
        ]
        #expect(PaidAmountDetector.keywordAmount(lines: lines) == 52500)
    }

    @Test func keywordReadsAmountOnNextLine() {
        let lines = ["Nominal", "Rp 75.000", "Merchant  Kopi Kenangan"]
        #expect(PaidAmountDetector.keywordAmount(lines: lines) == 75000)
    }

    @Test func keywordIgnoresSubtotal() {
        #expect(PaidAmountDetector.keywordAmount(lines: ["Subtotal  40.000"]) == nil)
    }

    @Test func keywordReturnsNilWithoutLabel() {
        #expect(PaidAmountDetector.keywordAmount(lines: ["Kopi Kenangan", "Rp 20.000"]) == nil)
    }

    @Test func rejectsOutOfRangeAmounts() {
        #expect(PaidAmountDetector.validated(0) == nil)
        #expect(PaidAmountDetector.validated(-5) == nil)
        #expect(PaidAmountDetector.validated(PaidAmountDetector.maxAmount + 1) == nil)
        #expect(PaidAmountDetector.validated(PaidAmountDetector.maxAmount) == PaidAmountDetector.maxAmount)
    }

    @Test func modelAnswerMustAppearInText() {
        let lines = ["Total  Rp 52.500"]
        #expect(PaidAmountDetector.appearsInText(52500, lines: lines))
        #expect(!PaidAmountDetector.appearsInText(99000, lines: lines))
    }
}
