//
//  BudgetsView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query private var transactions: [Transaction]

    @State private var editing: TransactionCategory?

    private var expenseCategories: [TransactionCategory] {
        categories.filter { $0.appliesTo.allows(.expense) }
    }

    private var progress: [BudgetProgress] {
        BudgetCalculator.progress(for: expenseCategories, transactions: transactions)
    }

    private var unbudgeted: [TransactionCategory] {
        expenseCategories.filter { !$0.hasBudget }
    }

    private var totalLimit: Decimal {
        progress.reduce(Decimal(0)) { $0 + $1.limit }
    }

    private var totalSpent: Decimal {
        progress.reduce(Decimal(0)) { $0 + $1.spent }
    }

    var body: some View {
        List {
            if !progress.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budgeted this month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(CurrencyFormatter.rupiah(totalSpent)) of \(CurrencyFormatter.rupiah(totalLimit))")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        ProgressView(value: totalLimit > 0 ? min((totalSpent / totalLimit as NSDecimalNumber).doubleValue, 1) : 0)
                    }
                    .padding(.vertical, 4)
                }

                Section("Budgets") {
                    ForEach(progress) { item in
                        Button { editing = item.category } label: {
                            BudgetProgressRow(progress: item)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                ForEach(unbudgeted, id: \.persistentModelID) { category in
                    Button { editing = category } label: {
                        HStack(spacing: 12) {
                            CategoryBadgeView(category: category, size: 32)
                            Text(category.name)
                            Spacer()
                            Text("Set budget")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(progress.isEmpty ? "Categories" : "No budget yet")
            } footer: {
                Text("Swiftlet warns you when a category reaches 80% of its monthly budget.")
            }
        }
        .navigationTitle("Budgets")
        .sheet(item: $editing) { category in
            CustomCategoryEditorView(editing: category)
        }
    }
}

#Preview {
    NavigationStack {
        BudgetsView()
    }
    .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
