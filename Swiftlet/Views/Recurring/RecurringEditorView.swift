//
//  RecurringEditorView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct RecurringEditorView: View {
    let rule: RecurringTransaction?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]

    @State private var title: String
    @State private var amountText: String
    @State private var type: TransactionType
    @State private var frequency: RecurrenceFrequency?
    @State private var nextDate: Date
    @State private var category: TransactionCategory?
    @State private var wallet: Wallet?
    @State private var remindsBeforeDue: Bool
    @State private var isActive: Bool
    @State private var isConfirmingDelete = false

    init(rule: RecurringTransaction? = nil) {
        self.rule = rule
        _title = State(initialValue: rule?.title ?? "")
        _amountText = State(initialValue: CurrencyFormatter.plainAmount(rule?.amount ?? 0))
        _type = State(initialValue: rule?.type ?? .expense)
        _frequency = State(initialValue: rule?.frequency ?? .monthly)
        _nextDate = State(initialValue: rule?.nextDueDate ?? .now)
        _category = State(initialValue: rule?.category)
        _wallet = State(initialValue: rule?.wallet)
        _remindsBeforeDue = State(initialValue: rule?.remindsBeforeDue ?? true)
        _isActive = State(initialValue: rule?.isActive ?? true)
    }

    private var eligibleCategories: [TransactionCategory] {
        categories.filter { $0.appliesTo.allows(type) }
    }

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (CurrencyFormatter.parse(amountText) ?? 0) > 0 && frequency != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    FormField(title: "Name") {
                        TextField("e.g. Netflix, Rent, Salary", text: $title)
                            .fieldBox()
                    }

                    FormField(title: "Amount") {
                        HStack {
                            Text("Rp").foregroundStyle(.secondary)
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                        }
                        .fieldBox()
                    }

                    FormField(title: "Repeats") {
                        MenuField(placeholder: "Select frequency", selection: $frequency, options: RecurrenceFrequency.allCases, label: \.displayName)
                    }

                    FormField(title: rule == nil ? "First payment" : "Next payment") {
                        DatePicker("Date", selection: $nextDate, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fieldBox()
                    }

                    FormField(title: "Category") {
                        MenuField(placeholder: "Select category", selection: $category, options: eligibleCategories, label: \.name, allowsNone: true)
                    }

                    FormField(title: "Wallet") {
                        MenuField(placeholder: "Main Wallet", selection: $wallet, options: wallets, label: \.name)
                    }

                    VStack(spacing: 0) {
                        Toggle("Remind me the day before", isOn: $remindsBeforeDue)
                            .padding(.vertical, 12)
                        if rule != nil {
                            Divider()
                            Toggle("Active", isOn: $isActive)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if rule != nil {
                        Button("Delete Recurring", role: .destructive) { isConfirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: "Save", isEnabled: isValid) {
                    Task { await save() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .onChange(of: type) { _, newType in
                if let category, !category.appliesTo.allows(newType) {
                    self.category = nil
                }
            }
            .navigationTitle(rule == nil ? "New Recurring" : "Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .confirmationDialog("Delete this recurring transaction? Transactions already created stay.", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let rule {
                        modelContext.delete(rule)
                        try? modelContext.save()
                    }
                    Task { await RecurringReminderScheduler.reschedule(context: modelContext) }
                    dismiss()
                }
            }
        }
    }

    private func save() async {
        guard let amount = CurrencyFormatter.parse(amountText), let frequency else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let dueDate = Calendar.current.startOfDay(for: nextDate)

        let target: RecurringTransaction
        if let rule {
            target = rule
        } else {
            target = RecurringTransaction(title: trimmedTitle, amount: amount, type: type, frequency: frequency, startDate: dueDate, category: category, wallet: wallet)
            modelContext.insert(target)
        }

        if target.frequency != frequency || target.nextDueDate != dueDate {
            target.startDate = dueDate
        }
        target.title = trimmedTitle
        target.amount = amount
        target.type = type
        target.frequency = frequency
        target.nextDueDate = dueDate
        target.category = category
        target.wallet = wallet
        target.remindsBeforeDue = remindsBeforeDue
        target.isActive = isActive
        try? modelContext.save()

        if remindsBeforeDue {
            _ = await RecurringReminderScheduler.requestAuthorization()
        }
        RecurringScheduler.materializeDue(context: modelContext)
        await RecurringReminderScheduler.reschedule(context: modelContext)
        dismiss()
    }
}

#Preview {
    RecurringEditorView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self], inMemory: true)
}
