import SwiftData
import SwiftUI

struct SplitsView: View {
    @Query(sort: \SplitBill.date, order: .reverse) private var bills: [SplitBill]
    @State private var selection: PersistentIdentifier?
    @State private var showsSettled = true

    private var shown: [SplitBill] {
        bills.filter { showsSettled || !$0.isFullySettled }
    }

    var body: some View {
        HSplitView {
            List(selection: $selection) {
                ForEach(shown) { bill in
                    SplitRow(bill: bill)
                        .tag(bill.persistentModelID)
                }
            }
            .frame(minWidth: 260, idealWidth: 320)
            .overlay {
                if bills.isEmpty {
                    ContentUnavailableView(
                        "No split bills",
                        systemImage: "person.2",
                        description: Text("Split a bill from the Swiftlet app on iPhone. It shows up here to settle.")
                    )
                }
            }

            Group {
                if let bill = bills.first(where: { $0.persistentModelID == selection }) {
                    SplitDetail(bill: bill)
                } else {
                    ContentUnavailableView("Select a split bill", systemImage: "person.2")
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Splits")
        .onAppear {
            if selection == nil {
                selection = shown.first?.persistentModelID
            }
        }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showsSettled) {
                    Label("Show settled", systemImage: "checkmark.circle")
                }
                .help("Show bills everyone has paid")
            }
        }
    }
}

private struct SplitRow: View {
    let bill: SplitBill

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(bill.title)
                    .fontWeight(.medium)
                Spacer()
                Text(CurrencyFormatter.rupiah(Decimal(bill.total)))
                    .monospacedDigit()
            }
            HStack {
                Text(bill.date, format: .dateTime.day().month(.abbreviated).year())
                Spacer()
                Text(bill.isFullySettled ? "Settled" : "\(CurrencyFormatter.rupiah(Decimal(bill.outstanding))) owed")
                    .foregroundStyle(bill.isFullySettled ? Color.secondary : Color.ds(.warning))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct SplitDetail: View {
    @Environment(\.modelContext) private var modelContext
    let bill: SplitBill

    var body: some View {
        Form {
            Section {
                LabeledContent("Total", value: CurrencyFormatter.rupiah(Decimal(bill.total)))
                LabeledContent("Your share", value: CurrencyFormatter.rupiah(Decimal(bill.myShare)))
                LabeledContent("Still owed", value: CurrencyFormatter.rupiah(Decimal(bill.outstanding)))
                if let wallet = bill.transaction?.wallet {
                    LabeledContent("Paid from", value: wallet.name)
                }
            }
            .monospacedDigit()

            Section("People") {
                ForEach(bill.sortedShares) { share in
                    ShareRow(share: share, bill: bill)
                }
            }

            if !bill.sortedItems.isEmpty {
                Section("Items") {
                    ForEach(bill.sortedItems) { item in
                        LabeledContent(item.quantity > 1 ? "\(item.quantity)× \(item.name)" : item.name) {
                            Text(CurrencyFormatter.rupiah(Decimal(item.price)))
                                .monospacedDigit()
                        }
                    }
                }
            }

            if let data = bill.receiptData, let image = ReceiptImage.thumbnail(from: data, maxPixels: 900) {
                Section("Receipt") {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .accessibilityLabel("Receipt photo")
                }
            }
        }
        .formStyle(.grouped)
        .navigationSubtitle(bill.title)
    }
}

private struct ShareRow: View {
    @Environment(\.modelContext) private var modelContext
    let share: SplitShare
    let bill: SplitBill

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(share.isMine ? "\(share.name) (you)" : share.name)
                if !share.isMine {
                    Text(share.isSettled ? "Paid" : "Owes \(CurrencyFormatter.rupiah(Decimal(share.outstanding)))")
                        .font(.caption)
                        .foregroundStyle(share.isSettled ? Color.secondary : Color.ds(.warning))
                }
            }
            Spacer()
            Text(CurrencyFormatter.rupiah(Decimal(share.amount)))
                .monospacedDigit()
            if !share.isMine {
                if share.isSettled {
                    Button("Undo") { undo() }
                        .help("Mark \(share.name) as not paid and remove the reimbursement")
                } else {
                    ShareLink(item: share.reminderMessage(billTitle: bill.title)) {
                        Label("Remind", systemImage: "bell")
                    }
                    .help("Send \(share.name) a reminder")
                    Button("Mark Paid") { markPaid() }
                        .buttonStyle(.borderedProminent)
                        .help("Record \(share.name)'s payment as a Reimburse income")
                }
            }
        }
        .controlSize(.small)
    }

    private func markPaid() {
        modelContext.undoManager?.beginUndoGrouping()
        SplitReimbursement.record(share, bill: bill, context: modelContext)
        try? modelContext.save()
        modelContext.undoManager?.endUndoGrouping()
        modelContext.undoManager?.setActionName("Mark Paid")
    }

    private func undo() {
        modelContext.undoManager?.beginUndoGrouping()
        SplitReimbursement.undo(share, context: modelContext)
        try? modelContext.save()
        modelContext.undoManager?.endUndoGrouping()
        modelContext.undoManager?.setActionName("Undo Payment")
    }
}
