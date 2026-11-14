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
    @State private var isEditing = false

    var body: some View {
        List {
            if let data = bill.receiptData {
                Section {
                    ReceiptPreviewButton(imageData: data)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            summarySection
            peopleSection
            if !bill.sortedItems.isEmpty { itemsSection }
            if bill.service + bill.tax + bill.discount > 0 { extrasSection }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(bill.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit items", systemImage: "pencil") { isEditing = true }
                    Button("Delete split", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            SplitBillEditorView(editing: bill)
        }
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
            AmountRow(
                title: "Still to collect",
                value: bill.outstanding.rupiah,
                isEmphasized: true,
                valueColor: bill.isFullySettled ? Color.ds(.accent) : Color.ds(.warning)
            )
        }
    }

    private var peopleSection: some View {
        Section("People") {
            ForEach(bill.othersShares) { share in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(share.name).font(.body.weight(.medium))
                        Spacer()
                        Text(share.amount.rupiah)
                            .monospacedDigit()
                            .foregroundStyle(share.isSettled ? Color.primary : Color.ds(.warning))
                    }

                    if share.isSettled {
                        HStack {
                            Label("Paid in full", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.ds(.accent))
                            Spacer()
                            moreMenu(for: share)
                        }
                    } else {
                        if share.settledAmount > 0 {
                            Text("\(share.outstanding.rupiah) left to pay")
                                .font(.subheadline)
                                .foregroundStyle(Color.ds(.warning))
                        }
                        HStack(spacing: 10) {
                            DSButton("Mark paid", systemImage: "checkmark", variant: .secondary, size: .medium, fillsWidth: false) {
                                share.recordPayment(share.outstanding)
                                try? modelContext.save()
                            }
                            moreMenu(for: share)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func moreMenu(for share: SplitShare) -> some View {
        Menu {
            if share.isSettled {
                Button("Undo payment", systemImage: "arrow.uturn.backward") {
                    share.undoSettlement()
                    try? modelContext.save()
                }
            } else {
                ShareLink(item: share.reminderMessage(billTitle: bill.title)) {
                    Label("Send reminder", systemImage: "paperplane")
                }
                Button("Record part payment", systemImage: "banknote") { paymentTarget = share }
                if share.settledAmount > 0 {
                    Button("Undo payments", systemImage: "arrow.uturn.backward") {
                        share.undoSettlement()
                        try? modelContext.save()
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.ds(.surfaceMuted), in: Circle())
                .foregroundStyle(Color.ds(.textPrimary))
        }
        .accessibilityLabel("More actions for \(share.name)")
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
        AmountRow(title: title, value: value)
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
                    AmountField(digits: $amountText)
                        .multilineTextAlignment(.leading)
                        .focused($isFocused)
                        .accessibilityLabel("Payment amount")
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
            .keyboardDoneButton()
        }
    }
}
