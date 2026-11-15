import Foundation
import SwiftData
import Testing

@testable import Swiftlet

@MainActor
struct BankEmailImporterTests {
    private let bcaEmail = """
    You just made a transaction through myBCA.
    Status\t:\tSuccessful
    Payment to\t:\tWARUNG MAKAN
    Total Payment\t:\tIDR 56,661.00
    Reference No.\t:\tREF001
    """

    private let ovoEmail = """
    Cotti Trade Indonesia
    Pembayaran Berhasil - Rp19.000
    Nama Toko\tCotti Trade Indonesia
    No. Referensi\tOVOREF1
    Nama Issuer\tOVO
    Metode Pembayaran\tOVO Cash
    Total\tRp19.000
    """

    private let topUpEmail = """
    Terima kasih udah memilih wondr by BNI untuk transaksi kamu! Kamu baru aja top-up e-Wallet.
    Penerima
    OVO-Andrew
    Total\tRp200.000
    Ref ID\tTOPUP01
    """

    private let gojekEmail = """
    Thanks for ordering GoRide
    Total paid\tRp17.500
    Paid with GoPay\t\tRp17.500
    """

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self,
            SplitBill.self, SplitItem.self, SplitShare.self, SplitPerson.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func transactions(_ context: ModelContext) throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    @Test func savesIntoTheMatchingWallet() async throws {
        let context = try makeContext()
        let bca = Wallet(name: "BCA")
        context.insert(bca)
        context.insert(Wallet(name: "Cash", sortIndex: 1))

        let received = Date(timeIntervalSince1970: 1_800_000_000)
        let result = await BankEmailImporter.importEmail(text: bcaEmail, receivedAt: received, context: context)

        guard case let .added(title, amount, wallet, usedDefault) = result else {
            Issue.record("expected added, got \(result)")
            return
        }
        #expect(title == "WARUNG MAKAN")
        #expect(amount == 56661)
        #expect(wallet == "BCA")
        #expect(!usedDefault)
        let saved = try #require(try transactions(context).first)
        #expect(saved.wallet?.name == "BCA")
        #expect(saved.externalReference == "bca:ref001")
        #expect(saved.date == received)
    }

    @Test func importingTheSameEmailTwiceAddsOneTransaction() async throws {
        let context = try makeContext()
        _ = await BankEmailImporter.importEmail(text: bcaEmail, receivedAt: nil, context: context)
        let second = await BankEmailImporter.importEmail(text: bcaEmail, receivedAt: nil, context: context)

        guard case .duplicate = second else {
            Issue.record("expected duplicate, got \(second)")
            return
        }
        #expect(try transactions(context).count == 1)
    }

    @Test func fallsBackToTheDefaultWalletWhenNoNameMatches() async throws {
        let context = try makeContext()
        context.insert(Wallet(name: "Cash"))

        let result = await BankEmailImporter.importEmail(text: bcaEmail, receivedAt: nil, context: context)

        guard case let .added(_, _, wallet, usedDefault) = result else {
            Issue.record("expected added, got \(result)")
            return
        }
        #expect(wallet == "Cash")
        #expect(usedDefault)
    }

    @Test func topUpBecomesATransferBetweenWallets() async throws {
        let context = try makeContext()
        context.insert(Wallet(name: "BNI"))
        context.insert(Wallet(name: "OVO", sortIndex: 1))

        _ = await BankEmailImporter.importEmail(text: topUpEmail, receivedAt: nil, context: context)

        let saved = try #require(try transactions(context).first)
        #expect(saved.type == .transfer)
        #expect(saved.wallet?.name == "BNI")
        #expect(saved.destinationWallet?.name == "OVO")
        #expect(saved.category == nil)
    }

    @Test func secondReportOfOnePaymentWithinTenMinutesIsSkipped() async throws {
        let context = try makeContext()
        context.insert(Wallet(name: "OVO"))
        let first = Date(timeIntervalSince1970: 1_800_000_000)

        _ = await BankEmailImporter.importEmail(text: ovoEmail, receivedAt: first, context: context)
        let other = ovoEmail.replacingOccurrences(of: "OVOREF1", with: "OTHERREF")
        let second = await BankEmailImporter.importEmail(
            text: other, receivedAt: first.addingTimeInterval(120), context: context
        )

        guard case .duplicate = second else {
            Issue.record("expected duplicate, got \(second)")
            return
        }
        #expect(try transactions(context).count == 1)
    }

    @Test func sameAmountOutsideTheWindowIsKept() async throws {
        let context = try makeContext()
        context.insert(Wallet(name: "OVO"))
        let first = Date(timeIntervalSince1970: 1_800_000_000)

        _ = await BankEmailImporter.importEmail(text: ovoEmail, receivedAt: first, context: context)
        let other = ovoEmail.replacingOccurrences(of: "OVOREF1", with: "OTHERREF")
        _ = await BankEmailImporter.importEmail(
            text: other, receivedAt: first.addingTimeInterval(3600), context: context
        )

        #expect(try transactions(context).count == 2)
    }

    @Test func referenceLessEmailsDedupeByAmountServiceAndMinute() async throws {
        let context = try makeContext()
        context.insert(Wallet(name: "GoPay"))
        let received = Date(timeIntervalSince1970: 1_800_000_000)

        _ = await BankEmailImporter.importEmail(text: gojekEmail, receivedAt: received, context: context)
        let second = await BankEmailImporter.importEmail(text: gojekEmail, receivedAt: received, context: context)

        guard case .duplicate = second else {
            Issue.record("expected duplicate, got \(second)")
            return
        }
        #expect(try transactions(context).count == 1)
    }

    @Test func unreadableTextSavesNothing() async throws {
        let context = try makeContext()
        let result = await BankEmailImporter.importEmail(text: "Hello", receivedAt: nil, context: context)

        guard case .unreadable = result else {
            Issue.record("expected unreadable, got \(result)")
            return
        }
        #expect(try transactions(context).isEmpty)
    }

    @Test func walletMatchingPrefersExactThenContains() {
        let names = ["Main Wallet", "BCA Savings", "BCA"]
        #expect(BankEmailDedupe.walletIndex(for: "bca", in: names) == 2)
        #expect(BankEmailDedupe.walletIndex(for: "Savings", in: names) == 1)
        #expect(BankEmailDedupe.walletIndex(for: "OVO", in: names) == nil)
        #expect(BankEmailDedupe.walletIndex(for: "", in: names) == nil)
    }
}
