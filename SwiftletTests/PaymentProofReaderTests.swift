//
//  PaymentProofReaderTests.swift
//  SwiftletTests
//

import Foundation
import SwiftData
import Testing
import UIKit

@testable import Swiftlet

struct PaymentProofReaderTests {
    private static let proofRows: [(String, String)] = [
        ("Pembayaran Berhasil", ""),
        ("Merchant", "Kopi Kenangan"),
        ("Biaya Admin", "Rp 2.500"),
        ("Saldo", "Rp 1.200.000"),
        ("Total Bayar", "Rp 52.500"),
        ("No. Ref", "202611140012345"),
    ]

    private func renderProof(rows: [(String, String)] = proofRows) throws -> Data {
        let size = CGSize(width: 900, height: 900)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let font = UIFont.systemFont(ofSize: 40)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            for (index, row) in rows.enumerated() {
                let y = 60 + CGFloat(index) * 100
                row.0.draw(at: CGPoint(x: 50, y: y), withAttributes: attributes)
                if !row.1.isEmpty {
                    let width = row.1.size(withAttributes: attributes).width
                    row.1.draw(at: CGPoint(x: size.width - 50 - width, y: y), withAttributes: attributes)
                }
            }
        }
        return try #require(image.pngData())
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self,
            SplitBill.self, SplitItem.self, SplitShare.self, SplitPerson.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @Test func keywordMerchantReadsSameLineAndNextLine() {
        #expect(PaymentProofReader.keywordMerchant(lines: ["Merchant  Kopi Kenangan"]) == "Kopi Kenangan")
        #expect(PaymentProofReader.keywordMerchant(lines: ["Nama Merchant:", "Gojek Indonesia"]) == "Gojek Indonesia")
        #expect(PaymentProofReader.keywordMerchant(lines: ["Penerima  1234567"]) == nil)
        #expect(PaymentProofReader.keywordMerchant(lines: ["Total  50.000"]) == nil)
    }

    @Test func foldsCyrillicLookalikesFromOCR() {
        #expect(PaymentProofReader.foldLookalikes("Merchant  Корі Kenangan") == "Merchant  Kopi Kenangan")
        #expect(PaymentProofReader.foldLookalikes("Total Rp 52.500") == "Total Rp 52.500")
    }

    @Test func modelMerchantMustAppearInText() {
        let lines = ["Pembayaran ke KOPI KENANGAN Senopati"]
        #expect(PaymentProofReader.acceptedMerchant("Kopi Kenangan", lines: lines) == "Kopi Kenangan")
        #expect(PaymentProofReader.acceptedMerchant("Starbucks", lines: lines) == nil)
    }

    @Test func noModelCallWhenAmountAndMerchantAreLabelled() async {
        var calls = 0
        let result = await PaymentProofReader.read(
            lines: ["Merchant  Kopi Kenangan", "Total Bayar  Rp 52.500"],
            model: { _ in
                calls += 1
                return nil
            }
        )
        #expect(calls == 0)
        #expect(result == .init(amount: 52500, merchant: "Kopi Kenangan"))
    }

    @Test func modelFillsOnlyWhatIsMissingAndRejectsInventions() async {
        let lines = ["Gojek Indonesia", "Bayar  Rp 31.000"]
        let honest = await PaymentProofReader.read(lines: lines) { _ in
            ModelPaymentProof(found: true, amount: 31000, merchant: "Gojek Indonesia")
        }
        #expect(honest == .init(amount: 31000, merchant: "Gojek Indonesia"))

        let invented = await PaymentProofReader.read(lines: lines) { _ in
            ModelPaymentProof(found: true, amount: 99000, merchant: "Starbucks")
        }
        #expect(invented == .init(amount: nil, merchant: nil))

        let notFound = await PaymentProofReader.read(lines: lines) { _ in
            ModelPaymentProof(found: false, amount: 31000, merchant: "")
        }
        #expect(notFound.amount == nil)
    }

    @Test func readsRenderedProofImage() async throws {
        let result = await PaymentProofReader.read(imageData: try renderProof())
        #expect(result.amount == 52500)
        #expect(result.merchant == "Kopi Kenangan")
    }

    @Test func fullPipelineFromImageToCategory() async throws {
        let context = try makeContext()
        CategorySeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())

        let viewModel = AddTransactionViewModel()
        let result = await PaymentProofReader.read(imageData: try renderProof())
        await viewModel.applyDetectedCategory(merchant: result.merchant, from: categories)

        #expect(result.amount == 52500)
        #expect(viewModel.selectedCategory?.name == "Food")
    }

    @Test func detectedCategoryDoesNotOverrideUserChoice() async throws {
        let context = try makeContext()
        CategorySeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let shopping = try #require(categories.first { $0.name == "Shopping" })

        let viewModel = AddTransactionViewModel()
        viewModel.selectedCategory = shopping
        await viewModel.applyDetectedCategory(merchant: "Kopi Kenangan", from: categories)
        #expect(viewModel.selectedCategory?.name == "Shopping")

        let income = AddTransactionViewModel()
        income.type = .income
        await income.applyDetectedCategory(merchant: "Kopi Kenangan", from: categories)
        #expect(income.selectedCategory == nil)
    }

    @Test func unknownMerchantLeavesCategoryEmptyAndNeverPicksOther() async throws {
        let context = try makeContext()
        CategorySeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())

        let viewModel = AddTransactionViewModel()
        await viewModel.applyDetectedCategory(merchant: "Xqzvw Ltd", from: categories)
        #expect(viewModel.selectedCategory?.name != "Other")
    }

    @Test func timeoutReturnsNilWhenWorkIsSlow() async {
        let clock = ContinuousClock()
        var value: Int?
        let elapsed = await clock.measure {
            value = await PaymentProofReader.withTimeout(.milliseconds(100)) {
                try? await Task.sleep(for: .seconds(5))
                return 7
            }
        }
        #expect(value == nil)
        #expect(elapsed < .seconds(2))
    }

    @Test func timeoutReturnsValueWhenWorkIsFast() async {
        let value = await PaymentProofReader.withTimeout(.seconds(2)) { 7 }
        #expect(value == 7)
    }
}
