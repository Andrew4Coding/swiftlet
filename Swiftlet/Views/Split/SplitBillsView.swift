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
        Group {
            if bills.isEmpty {
                ContentUnavailableView {
                    Label("No splits yet", systemImage: "person.2.fill")
                } description: {
                    Text("Split a bill you paid and keep track of who still owes you.")
                } actions: {
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
                            HStack {
                                Text(person.name)
                                Spacer()
                                Text(person.outstanding.rupiah)
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                            }
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
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.title).font(.body.weight(.medium))
                Text("\(bill.date.formatted(date: .abbreviated, time: .omitted)) · \((bill.shares ?? []).count) people")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(bill.total.rupiah).font(.subheadline.weight(.semibold)).monospacedDigit()
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
        .accessibilityElement(children: .combine)
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
