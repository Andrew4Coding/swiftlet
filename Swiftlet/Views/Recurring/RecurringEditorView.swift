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

    @State private var calculator: AmountCalculatorViewModel
    @State private var title: String
    @State private var type: TransactionType
    @State private var frequency: RecurrenceFrequency?
    @State private var nextDate: Date
    @State private var category: TransactionCategory?
    @State private var wallet: Wallet?
    @State private var remindsBeforeDue: Bool
    @State private var isActive: Bool
    @State private var isConfirmingDelete = false
    @State private var isShowingDetails = false
    @State private var errorMessage: String?
    @State private var saveAttempts = 0

    init(rule: RecurringTransaction? = nil) {
        self.rule = rule
        _calculator = State(initialValue: AmountCalculatorViewModel(
            initialText: rule.map { CurrencyFormatter.plainAmount($0.amount) } ?? ""
        ))
        _title = State(initialValue: rule?.title ?? "")
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
        allWallets.filter { !$0.isArchived || $0.persistentModelID == wallet?.persistentModelID }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && frequency != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TransactionTypePicker(selection: $type, types: [.expense, .income])
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                Spacer(minLength: 12)
                amountDisplay
                Spacer(minLength: 12)

                VStack(spacing: 14) {
                    WalletMenuRow(
                        title: type == .income ? "To" : "From",
                        selection: $wallet,
                        wallets: wallets
                    )
                    AmountKeypad(calculator: calculator)
                    DSButton("Next", action: next)
                        .sensoryFeedback(.error, trigger: saveAttempts)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(rule == nil ? "" : "Edit Recurring")
            .navigationDestination(isPresented: $isShowingDetails) { detailsStep }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .onChange(of: type) { _, newType in
                if let category, !category.appliesTo.allows(newType) {
                    self.category = nil
                }
            }
            .onChange(of: calculator.finalValue) { _, _ in errorMessage = nil }
            .task {
                if wallet == nil { wallet = wallets.first }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var amountDisplay: some View {
        VStack(spacing: 10) {
            Text(calculator.expressionDisplay.isEmpty ? " " : calculator.expressionDisplay)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(calculator.formattedCurrentInput)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .animation(.snappy, value: calculator.formattedCurrentInput)
                .padding(.horizontal, 20)
                .accessibilityLabel("Amount \(calculator.formattedCurrentInput)")

            categoryChip

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.ds(.expense))
                    .transition(.opacity)
            }
        }
    }

    private var categoryChip: some View {
        Menu {
            Button("None") { category = nil }
            Divider()
            ForEach(eligibleCategories) { option in
                Button {
                    category = option
                } label: {
                    Text(option.name)
                    if option.persistentModelID == category?.persistentModelID {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            DSChip(
                title: category?.name ?? "Select category",
                isPlaceholder: category == nil
            ) {
                if category != nil {
                    CategoryBadgeView(category: category, size: 22)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FormField(title: "Name") {
                    TextField("e.g. Netflix, Rent, Salary", text: $title)
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
                    Button("Delete Recurring", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(title: "Save", isEnabled: canSave) {
                Task { await save() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
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

    private func next() {
        calculator.equals()
        guard calculator.finalValue > 0 else {
            withAnimation { errorMessage = "Enter an amount" }
            saveAttempts += 1
            return
        }
        errorMessage = nil
        isShowingDetails = true
    }

    private func save() async {
        let amount = calculator.finalValue
        guard amount > 0, let frequency else { return }
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
