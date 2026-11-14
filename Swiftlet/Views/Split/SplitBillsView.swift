//
//  SplitBillsView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct SplitBillsView: View {
    @Query(sort: \SplitBill.date, order: .reverse) private var bills: [SplitBill]
    @Query(sort: \SplitPerson.name) private var people: [SplitPerson]

    @State private var isPresentingEditor = false

    private var owedTotal: Int {
        bills.reduce(0) { $0 + $1.outstanding }
    }

    private var debtors: [SplitPerson] {
        people.filter { $0.outstanding > 0 }.sorted { $0.outstanding > $1.outstanding }
    }

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        Group {
            if bills.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView(
                        systemImage: "person.2.fill",
                        title: "No splits yet",
                        message: "Split a bill you paid and keep track of who still owes you."
                    )
                    DSButton("Split a bill", fillsWidth: false) { isPresentingEditor = true }
                }
            } else {
                list
            }
        }
        .background(Color.ds(.canvas))
        .navigationTitle("Splits")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Split a bill", systemImage: "plus") { isPresentingEditor = true }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            SplitBillEditorView()
        }
    }

    private var list: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Owed to you")
                        .dsTextStyle(.subheadline, color: .textSecondary)
                    Text(owedTotal.rupiah)
                        .dsTextStyle(.amountLarge)
                        .contentTransition(.numericText())
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                .accessibilityElement(children: .combine)
            }

            if !debtors.isEmpty {
                Section("Who owes you") {
                    ForEach(debtors) { person in
                        NavigationLink {
                            SplitPersonView(person: person)
                        } label: {
                            AmountRow(title: person.name, value: person.outstanding.rupiah, isEmphasized: true)
                        }
                    }
                }
            }

            Section("Bills") {
                ForEach(bills) { bill in
                    NavigationLink {
                        SplitBillDetailView(bill: bill)
                    } label: {
                        BillRow(bill: bill)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct BillRow: View {
    let bill: SplitBill

    var body: some View {
        HStack(spacing: 12) {
            if let data = bill.receiptData {
                ReceiptThumbnail(imageData: data)
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    leading
                    Spacer(minLength: 12)
                    trailing(alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 6) {
                    leading
                    trailing(alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var leading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(bill.title).font(.body.weight(.medium))
            Text("\(bill.date.formatted(date: .abbreviated, time: .omitted)) · \((bill.shares ?? []).count) people")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func trailing(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(bill.total.rupiah)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            if bill.isFullySettled {
                Label("Settled", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.ds(.accent))
            } else {
                Text("\(bill.outstanding.rupiah) owed")
                    .font(.caption)
                    .foregroundStyle(Color.ds(.warning))
                    .monospacedDigit()
            }
        }
    }
}

struct SplitPersonView: View {
    let person: SplitPerson

    private var openShares: [SplitShare] {
        (person.shares ?? []).filter { $0.outstanding > 0 }.sorted { ($0.bill?.date ?? .distantPast) > ($1.bill?.date ?? .distantPast) }
    }

    var body: some View {
        List {
            Section {
                ForEach(openShares) { share in
                    if let bill = share.bill {
                        NavigationLink {
                            SplitBillDetailView(bill: bill)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bill.title).font(.body.weight(.medium))
                                    Text(bill.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(share.outstanding.rupiah).monospacedDigit().font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
            } header: {
                Text("Owes \(person.outstanding.rupiah)")
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
