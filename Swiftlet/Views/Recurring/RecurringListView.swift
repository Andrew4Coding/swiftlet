//
//  RecurringListView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct RecurringListView: View {
    @Query(sort: \RecurringTransaction.nextDueDate) private var rules: [RecurringTransaction]

    @State private var editorTarget: RecurringEditorTarget?

    private var active: [RecurringTransaction] {
        rules.filter(\.isActive)
    }

    private var paused: [RecurringTransaction] {
        rules.filter { !$0.isActive }
    }

    private var monthlyExpense: Decimal {
        active.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.monthlyEstimate }
    }

    var body: some View {
        List {
            if !active.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recurring spend per month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.rupiah(monthlyExpense))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                }

                Section("Upcoming") {
                    ForEach(active) { row(for: $0) }
                }
            }

            if !paused.isEmpty {
                Section("Paused") {
                    ForEach(paused) { row(for: $0) }
                }
            }

            if rules.isEmpty {
                ContentUnavailableView {
                    Label("No Recurring Transactions", systemImage: "repeat")
                } description: {
                    Text("Add subscriptions, rent or salary once and Swiftlet records them automatically.")
                } actions: {
                    Button("Add Recurring") { editorTarget = .new }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Recurring", systemImage: "plus") { editorTarget = .new }
            }
        }
        .sheet(item: $editorTarget) { target in
            RecurringEditorView(rule: target.rule)
        }
    }

    private func row(for rule: RecurringTransaction) -> some View {
        Button { editorTarget = .edit(rule) } label: {
            RecurringRow(rule: rule)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RecurringRow: View {
    let rule: RecurringTransaction

    private var dueText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(rule.nextDueDate) {
            return "Due today"
        }
        if calendar.isDateInTomorrow(rule.nextDueDate) {
            return "Due tomorrow"
        }
        return rule.nextDueDate.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadgeView(category: rule.category, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .font(.subheadline.weight(.medium))
                Text("\(rule.frequency.displayName) · \(dueText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text((rule.type == .income ? "+" : "-") + CurrencyFormatter.rupiah(rule.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(rule.type.amountColor)
        }
        .opacity(rule.isActive ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}

enum RecurringEditorTarget: Identifiable {
    case new
    case edit(RecurringTransaction)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(rule): "\(rule.persistentModelID.hashValue)"
        }
    }

    var rule: RecurringTransaction? {
        if case let .edit(rule) = self { rule } else { nil }
    }
}

#Preview {
    NavigationStack {
        RecurringListView()
    }
    .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self], inMemory: true)
}
