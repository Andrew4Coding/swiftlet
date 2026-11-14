//
//  SplitBillViewModelTests.swift
//  SwiftletTests
//

import Foundation
import SwiftData
import Testing

@testable import Swiftlet

struct SplitBillViewModelTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self,
            SplitBill.self, SplitItem.self, SplitShare.self, SplitPerson.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func readyViewModel(in context: ModelContext) -> SplitBillViewModel {
        let wallet = Wallet(name: "BCA", initialBalance: 1_000_000)
        let category = TransactionCategory(name: "Food", iconType: .emoji, iconValue: "🍜", colorHex: "FF3B30")
        context.insert(wallet)
        context.insert(category)

        let viewModel = SplitBillViewModel()
        viewModel.title = "Dinner"
        viewModel.wallet = wallet
        viewModel.category = category
        return viewModel
    }

    @Test func equalSplitOfManualTotal() {
        let viewModel = SplitBillViewModel()
        viewModel.manualTotalText = "100000"
        viewModel.addParticipant(name: "Budi")
        viewModel.addParticipant(name: "Sari")

        #expect(viewModel.split.shares == [33_334, 33_333, 33_333])
    }

    @Test func duplicateAndBlankNamesAreRejected() {
        let viewModel = SplitBillViewModel()
        #expect(viewModel.addParticipant(name: "Budi"))
        #expect(!viewModel.addParticipant(name: " budi "))
        #expect(!viewModel.addParticipant(name: "   "))
        #expect(!viewModel.addParticipant(name: "you"))
        #expect(viewModel.participants.count == 2)
    }

    @Test func youCannotBeRemoved() {
        let viewModel = SplitBillViewModel()
        let me = viewModel.participants[0].id
        viewModel.removeParticipant(me)
        #expect(viewModel.participants.count == 1)
    }

    @Test func itemizedSplitUsesAssignments() {
        let viewModel = SplitBillViewModel()
        viewModel.addParticipant(name: "Budi")
        viewModel.addItem()
        viewModel.addItem()
        viewModel.items[0].priceText = "60000"
        viewModel.items[1].priceText = "40000"
        viewModel.mode = .byItems
        viewModel.toggle(viewModel.participants[0].id, on: viewModel.items[0].id)
        viewModel.toggle(viewModel.participants[1].id, on: viewModel.items[1].id)
        viewModel.discountText = "10000"

        #expect(viewModel.split.shares == [54_000, 36_000])
        #expect(viewModel.billTotal == 90_000)
        #expect(viewModel.split.unassigned == 0)
    }

    @Test func removingPersonClearsTheirAssignments() {
        let viewModel = SplitBillViewModel()
        viewModel.addParticipant(name: "Budi")
        viewModel.addItem()
        viewModel.items[0].priceText = "10000"
        let budi = viewModel.participants[1].id
        viewModel.toggle(budi, on: viewModel.items[0].id)
        viewModel.removeParticipant(budi)

        #expect(viewModel.items[0].assigneeIDs.isEmpty)
    }

    @Test func unassignedItemBlocksSaving() throws {
        let context = try makeContext()
        let viewModel = readyViewModel(in: context)
        viewModel.addParticipant(name: "Budi")
        viewModel.addItem()
        viewModel.items[0].priceText = "50000"
        viewModel.mode = .byItems

        #expect(viewModel.validationMessage == "Assign every item to someone")
        #expect(!viewModel.canSave)

        viewModel.assignEveryone(to: viewModel.items[0].id)
        #expect(viewModel.canSave)
    }

    @Test func savingNeedsAnotherPersonWalletAndCategory() throws {
        let viewModel = SplitBillViewModel()
        viewModel.manualTotalText = "100000"
        #expect(viewModel.validationMessage == "Add at least one other person")
        viewModel.addParticipant(name: "Budi")
        #expect(viewModel.validationMessage == "Choose the wallet you paid from")
    }

    @Test func savedTransactionHoldsOnlyMyShare() throws {
        let context = try makeContext()
        let viewModel = readyViewModel(in: context)
        viewModel.manualTotalText = "400000"
        viewModel.addParticipant(name: "Budi")
        viewModel.addParticipant(name: "Sari")
        viewModel.addParticipant(name: "Dewi")

        let bill = try #require(viewModel.save(context: context))

        #expect(bill.transaction?.amount == 100_000)
        #expect(bill.total == 400_000)
        #expect(bill.owedByOthers == 300_000)
        #expect(bill.sortedShares.map(\.amount).reduce(0, +) == 400_000)
        #expect(viewModel.wallet?.balance == 600_000)
    }

    @Test func savingReusesExistingPeopleByName() throws {
        let context = try makeContext()
        context.insert(SplitPerson(name: "Budi"))
        let viewModel = readyViewModel(in: context)
        viewModel.manualTotalText = "100000"
        viewModel.addParticipant(name: "budi")

        viewModel.save(context: context)

        let people = try context.fetch(FetchDescriptor<SplitPerson>())
        #expect(people.count == 1)
        #expect(people[0].shares?.count == 1)
    }

    @Test func appliedScanFillsItemsAndFlagsMismatch() {
        let viewModel = SplitBillViewModel()
        let receipt = ParsedReceipt(
            items: [.init(name: "Soto", quantity: 1, price: 20_000), .init(name: "Teh", quantity: 1, price: 5_000)],
            subtotal: 30_000,
            service: nil,
            tax: nil,
            discount: nil,
            total: 30_000
        )
        viewModel.apply(ReceiptScanner.Outcome(receipt: receipt, lines: [], usedModel: false))

        #expect(viewModel.items.count == 2)
        #expect(viewModel.mode == .byItems)
        #expect(viewModel.mismatches == [.itemsDifferFromSubtotal(-5_000)])
    }

    @Test func editingItemsToMatchClearsMismatch() {
        let viewModel = SplitBillViewModel()
        let receipt = ParsedReceipt(
            items: [.init(name: "Soto", quantity: 1, price: 20_000)],
            subtotal: 25_000,
            total: 25_000
        )
        viewModel.apply(ReceiptScanner.Outcome(receipt: receipt, lines: [], usedModel: false))
        viewModel.items[0].priceText = "25000"

        #expect(viewModel.mismatches.isEmpty)
    }

    @Test func untouchedDraftIsNotDirty() {
        #expect(!SplitBillViewModel().isDirty)
    }

    @Test(arguments: ["total", "person", "title", "item", "receipt"])
    func anyEditMakesDraftDirty(edit: String) {
        let viewModel = SplitBillViewModel()
        switch edit {
        case "total": viewModel.manualTotalText = "1000"
        case "person": viewModel.addParticipant(name: "Budi")
        case "title": viewModel.title = "Dinner"
        case "item": viewModel.addItem()
        default: viewModel.receiptImageData = Data([1])
        }
        #expect(viewModel.isDirty)
    }

    @Test func cancellingScanClearsReceiptAndState() {
        let viewModel = SplitBillViewModel()
        viewModel.receiptImageData = Data([1])
        viewModel.scanState = .scanning
        viewModel.cancelScan()

        #expect(viewModel.scanState == .idle)
        #expect(viewModel.receiptImageData == nil)
        #expect(!viewModel.isDirty)
    }

    @Test func amountFieldGroupsDigitsLikeTheRestOfTheApp() {
        #expect(AmountField.grouped("35000") == "35.000")
        #expect(AmountField.grouped("1234567") == "1.234.567")
        #expect(AmountField.grouped("") == "")
    }

    @Test func savedBillKeepsTheReceiptPhoto() throws {
        let context = try makeContext()
        let viewModel = readyViewModel(in: context)
        viewModel.manualTotalText = "100000"
        viewModel.addParticipant(name: "Budi")
        viewModel.receiptImageData = Data([1, 2, 3])

        let bill = try #require(viewModel.save(context: context))
        #expect(bill.receiptImageData == Data([1, 2, 3]))
        #expect(bill.receiptData == Data([1, 2, 3]))
    }
}
