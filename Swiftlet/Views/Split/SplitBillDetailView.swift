//
//  SplitBillDetailView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct SplitBillDetailView: View {
    let bill: SplitBill

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var paymentTarget: SplitShare?
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            summarySection
            peopleSection
            if !bill.sortedItems.isEmpty { itemsSection }
            if bill.service + bill.tax + bill.discount > 0 { extrasSection }

            Section {
                Button("Delete split", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(bill.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $paymentTarget) { share in
            RecordPaymentSheet(share: share)
                .presentationDetents([.height(300)])
        }
        .confirmationDialog("Delete this split?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete split", role: .destructive, action: delete)
        } message: {
            Text("This also removes your \(bill.myShare.rupiah) expense. Anything others already paid is forgotten.")
        }
    }

    private var summarySection: some View {
        Section {
            row("Bill total", bill.total.rupiah)
            row("Your share", bill.myShare.rupiah)
            row("Owed to you", bill.owedByOthers.rupiah)
            HStack {
                Text("Still to collect").font(.body.weight(.semibold))
                Spacer()
                Text(bill.outstanding.rupiah)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(bill.isFullySettled ? Color.ds(.accent) : Color.ds(.warning))
                    .monospacedDigit()
            }
        }
    }

    private var peopleSection: some View {
        Section("People") {
            ForEach(bill.othersShares) { share in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(share.name).font(.body.weight(.medium))
                        Spacer()
                        Text(share.amount.rupiah).monospacedDigit()
                    }
                    HStack {
                        if share.isSettled {
                            Label("Paid", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.ds(.accent))
                        } else {
                            Text(share.settledAmount > 0 ? "\(share.outstanding.rupiah) left" : "Owes \(share.outstanding.rupiah)")
                                .foregroundStyle(Color.ds(.warning))
                        }
                        Spacer()
                        actions(for: share)
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func actions(for share: SplitShare) -> some View {
        if share.isSettled {
            Button("Undo") {
                share.undoSettlement()
                try? modelContext.save()
            }
            .buttonStyle(.borderless)
        } else {
            HStack(spacing: 16) {
                ShareLink(item: share.reminderMessage(billTitle: bill.title)) {
                    Label("Remind", systemImage: "paperplane")
                }
                Button("Payment") { paymentTarget = share }
                Button("Paid", systemImage: "checkmark") {
                    share.recordPayment(share.outstanding)
                    try? modelContext.save()
                }
                .labelStyle(.titleOnly)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderless)
        }
    }

    private var itemsSection: some View {
        Section("Items") {
            ForEach(bill.sortedItems) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.quantity > 1 ? "\(item.name) ×\(item.quantity)" : item.name)
                        Spacer()
                        Text(item.price.rupiah).monospacedDigit()
                    }
                    let names = bill.sortedShares.filter { item.assigneeKeys.contains($0.key) }.map(\.name)
                    if !names.isEmpty {
                        Text(names.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var extrasSection: some View {
        Section("Extras") {
            if bill.service > 0 { row("Service charge", bill.service.rupiah) }
            if bill.tax > 0 { row("Tax", bill.tax.rupiah) }
            if bill.discount > 0 { row("Discount", "-" + bill.discount.rupiah) }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func delete() {
        if let transaction = bill.transaction {
            modelContext.delete(transaction)
        }
        modelContext.delete(bill)
        try? modelContext.save()
        dismiss()
    }
}

private struct RecordPaymentSheet: View {
    let share: SplitShare

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var amountText: String
    @FocusState private var isFocused: Bool

    init(share: SplitShare) {
        self.share = share
        _amountText = State(initialValue: String(share.outstanding))
    }

    private var amount: Int { SplitBillViewModel.wholeRupiah(amountText) }
    private var isValid: Bool { amount > 0 && amount <= share.outstanding }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(share.name) owes \(share.outstanding.rupiah)")
                    .dsTextStyle(.subheadline, color: .textSecondary)

                HStack {
                    Text("Rp").foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                        .monospacedDigit()
                }
                .font(.title2.weight(.semibold))
                .fieldBox()

                if amount > share.outstanding {
                    Text("That's more than they owe.").dsTextStyle(.footnote, color: .warning)
                }

                DSButton("Record payment") {
                    share.recordPayment(amount)
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(!isValid)
            }
            .padding(20)
            .navigationTitle("Payment from \(share.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { isFocused = true }
        }
    }
}
