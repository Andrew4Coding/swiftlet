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
                    .tint(.red)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            SplitBillEditorView(editing: bill)
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(share.name).font(.body.weight(.medium))
                        Spacer()
                        Text(share.amount.rupiah)
                            .monospacedDigit()
                            .foregroundStyle(share.isSettled ? Color.primary : Color.ds(.warning))
                    }
                    if share.isSettled {
                        Label("Paid in full", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ds(.accent))
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: !share.isSettled) {
                    if share.isSettled {
                        Button { undoPayment(share) } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .accessibilityLabel("Undo payment")
                        .tint(.gray)
                    } else {
                        Button { markPaid(share) } label: {
                            Image.swipeIcon("checkmark")
                        }
                        .accessibilityLabel("Mark paid")
                        .tint(Color.ds(.accentFill))
                        ShareLink(item: share.reminderMessage(billTitle: bill.title)) {
                            Image(systemName: "paperplane")
                        }
                        .accessibilityLabel("Send reminder")
                        .tint(.gray)
                    }
                }
                .contextMenu {
                    if share.isSettled {
                        Button("Undo payment", systemImage: "arrow.uturn.backward") { undoPayment(share) }
                    } else {
                        Button("Mark paid", systemImage: "checkmark") { markPaid(share) }
                        ShareLink(item: share.reminderMessage(billTitle: bill.title)) {
                            Label("Send reminder", systemImage: "paperplane")
                        }
                    }
                }
            }
        }
    }

    private func markPaid(_ share: SplitShare) {
        share.recordPayment(share.outstanding)
        try? modelContext.save()
    }

    private func undoPayment(_ share: SplitShare) {
        share.undoSettlement()
        try? modelContext.save()
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
