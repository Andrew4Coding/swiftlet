//
//  SplitBillViewModel.swift
//  Swiftlet
//

import Foundation
import Observation
import SwiftData

@Observable
final class SplitBillViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case equal
        case byItems

        var id: String { rawValue }

        var title: String {
            switch self {
            case .equal: "Equally"
            case .byItems: "By items"
            }
        }
    }

    enum ScanState: Equatable {
        case idle
        case scanning
        case finished(usedModel: Bool)
        case failed(String)
    }

    struct DraftItem: Identifiable, Equatable {
        let id = UUID()
        var name = ""
        var quantity = 1
        var priceText = ""
        var assigneeIDs: Set<UUID> = []

        var price: Int { SplitBillViewModel.wholeRupiah(priceText) }
    }

    struct Participant: Identifiable {
        let id: UUID
        var name: String
        var person: SplitPerson?
        var isMe = false
    }

    var title = ""
    var date = Date.now
    var receiptImageData: Data?
    var items: [DraftItem] = []
    var serviceText = ""
    var taxText = ""
    var discountText = ""
    var manualTotalText = ""
    var printedSubtotal: Int?
    var printedTotal: Int?
    var mode: Mode = .equal
    var participants: [Participant] = [Participant(id: UUID(), name: "You", isMe: true)]
    var wallet: Wallet?
    var category: TransactionCategory?
    var scanState: ScanState = .idle

    static func wholeRupiah(_ text: String) -> Int {
        guard let value = CurrencyFormatter.parse(text) else { return 0 }
        return NSDecimalNumber(decimal: value).intValue
    }

    var itemsTotal: Int { items.reduce(0) { $0 + $1.price } }

    var extras: SplitCalculator.Extras {
        SplitCalculator.Extras(
            service: Self.wholeRupiah(serviceText),
            tax: Self.wholeRupiah(taxText),
            discount: Self.wholeRupiah(discountText)
        )
    }

    var effectiveMode: Mode { items.isEmpty ? .equal : mode }

    var billTotal: Int {
        items.isEmpty ? Self.wholeRupiah(manualTotalText) : max(itemsTotal + extras.net, 0)
    }

    var split: SplitCalculator.Result {
        switch effectiveMode {
        case .equal:
            SplitCalculator.Result(
                shares: SplitCalculator.equalSplit(total: billTotal, count: participants.count),
                unassigned: 0
            )
        case .byItems:
            SplitCalculator.itemizedSplit(
                items: items.map { item in
                    SplitCalculator.Item(
                        price: item.price,
                        assignees: participants.indices.filter { item.assigneeIDs.contains(participants[$0].id) }
                    )
                },
                extras: extras,
                participantCount: participants.count
            )
        }
    }

    var mismatches: [ReceiptMismatch] {
        guard printedSubtotal != nil || printedTotal != nil, !items.isEmpty else { return [] }
        return ReceiptMath.mismatches(
            itemsTotal: itemsTotal,
            subtotal: printedSubtotal,
            service: extras.service,
            tax: extras.tax,
            discount: extras.discount,
            total: printedTotal
        )
    }

    var validationMessage: String? {
        if billTotal <= 0 { return "Enter the bill total" }
        if participants.count < 2 { return "Add at least one other person" }
        if effectiveMode == .byItems, split.unassigned > 0 { return "Assign every item to someone" }
        if wallet == nil { return "Choose the wallet you paid from" }
        if category == nil { return "Choose a category" }
        return nil
    }

    var canSave: Bool { validationMessage == nil }

    var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Split bill" : trimmed
    }

    var myShare: Int { split.shares.first ?? 0 }

    func addItem() {
        var item = DraftItem()
        item.assigneeIDs = []
        items.append(item)
    }

    func removeItems(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
    }

    @discardableResult
    func addParticipant(name: String, person: SplitPerson? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !participants.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return false
        }
        participants.append(Participant(id: UUID(), name: trimmed, person: person))
        return true
    }

    func removeParticipant(_ id: UUID) {
        guard participants.first(where: { $0.id == id })?.isMe == false else { return }
        participants.removeAll { $0.id == id }
        for index in items.indices {
            items[index].assigneeIDs.remove(id)
        }
    }

    func toggle(_ participantID: UUID, on itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if items[index].assigneeIDs.contains(participantID) {
            items[index].assigneeIDs.remove(participantID)
        } else {
            items[index].assigneeIDs.insert(participantID)
        }
    }

    func assignEveryone(to itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].assigneeIDs = Set(participants.map(\.id))
    }

    func apply(_ outcome: ReceiptScanner.Outcome) {
        let receipt = outcome.receipt
        items = receipt.items.map { parsed in
            var item = DraftItem()
            item.name = parsed.name
            item.quantity = parsed.quantity
            item.priceText = String(parsed.price)
            return item
        }
        serviceText = receipt.service.map(String.init) ?? ""
        taxText = receipt.tax.map(String.init) ?? ""
        discountText = receipt.discount.map(String.init) ?? ""
        printedSubtotal = receipt.subtotal
        printedTotal = receipt.total
        if !items.isEmpty { mode = .byItems }
        scanState = .finished(usedModel: outcome.usedModel)
    }

    func scan(imageData: Data) async {
        receiptImageData = imageData
        scanState = .scanning
        do {
            let outcome = try await ReceiptScanner.scan(imageData: imageData)
            if outcome.receipt.items.isEmpty, outcome.receipt.total == nil {
                scanState = .failed("Couldn't find any items on that photo. You can enter them yourself.")
            } else {
                apply(outcome)
            }
        } catch {
            scanState = .failed("Couldn't read that photo. You can enter the items yourself.")
        }
    }

    @discardableResult
    func save(context: ModelContext) -> SplitBill? {
        guard validationMessage == nil, let wallet, let category else { return nil }

        let result = split
        let existingPeople = (try? context.fetch(FetchDescriptor<SplitPerson>())) ?? []
        let extras = extras

        let bill = SplitBill(
            title: resolvedTitle,
            total: billTotal,
            service: extras.service,
            tax: extras.tax,
            discount: extras.discount,
            date: date
        )
        context.insert(bill)

        let transaction = Transaction(
            type: .expense,
            title: resolvedTitle,
            amount: Decimal(result.shares[0]),
            source: .bca,
            date: date,
            category: category,
            receiptImageData: receiptImageData
        )
        transaction.wallet = wallet
        context.insert(transaction)
        bill.transaction = transaction

        for (index, participant) in participants.enumerated() {
            let person: SplitPerson? = if participant.isMe {
                nil
            } else if let known = participant.person
                ?? existingPeople.first(where: { $0.name.caseInsensitiveCompare(participant.name) == .orderedSame })
            {
                known
            } else {
                SplitPerson(name: participant.name)
            }
            if let person, person.modelContext == nil { context.insert(person) }

            let share = SplitShare(
                key: participant.id.uuidString,
                name: participant.name,
                amount: result.shares[index],
                isMine: participant.isMe,
                sortIndex: index,
                person: person
            )
            context.insert(share)
            share.bill = bill
        }

        for (index, draft) in items.enumerated() {
            let item = SplitItem(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: draft.quantity,
                price: draft.price,
                sortIndex: index,
                assigneeKeys: effectiveMode == .byItems ? draft.assigneeIDs.map(\.uuidString) : []
            )
            context.insert(item)
            item.bill = bill
        }

        try? context.save()
        return bill
    }
}
